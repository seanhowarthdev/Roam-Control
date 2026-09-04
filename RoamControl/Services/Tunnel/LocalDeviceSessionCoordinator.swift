import BackgroundTasks
import Foundation
import Network
import Observation
import RoamPairingFFI
import UIKit

enum DeviceSessionPhase: Equatable {
    case idle
    case openingLocalDevVPN
    case discovering
    case connecting
    case active(LocationTarget)
    case stopping
    case failed(String)
}

enum MobileDataGuidance: Equatable {
    case connectionHelp
    case turnOff
    case turnBackOn
}

enum ActiveLocationUpdateResult: Equatable {
    case unavailable
    case updated
    case failed
}

@MainActor
@Observable
final class LocalDeviceSessionCoordinator: NSObject {
    private struct PendingSession {
        let pairingRecord: Data
        let target: LocationTarget
    }

    private struct RemotePairingService: Sendable {
        let port: UInt16
        let identifier: String
        let authTag: String
    }

    private static var taskIdentifierPrefix: String {
        BackgroundTaskIdentifier.prefix(for: "location")
    }

    private static let localDevVPNPeerAddress = "10.7.0.1"
    private static let enableURL = URL(string: "localdevvpn://enable?scheme=roamcontrol")!

    private(set) var phase: DeviceSessionPhase = .idle {
        didSet { onPhaseChange?(phase) }
    }
    private(set) var mobileDataGuidance: MobileDataGuidance?

    var onPhaseChange: ((DeviceSessionPhase) -> Void)?

    private let browser = NetServiceBrowser()
    private let wifiPathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let wifiPathMonitorQueue = DispatchQueue(
        label: "com.sean.roamcontrol.wifi-path",
        qos: .utility
    )
    private let serviceProbeQueue = DispatchQueue(
        label: "com.sean.roamcontrol.service-probe",
        qos: .userInitiated
    )
    private var discoveredServices: [NetService] = []
    private var discoveryTimeout: Task<Void, Never>?
    private var automaticDiscoveryTask: Task<Void, Never>?
    private var networkDecisionTask: Task<Void, Never>?
    private var mobileDataDiscoveryLoopTask: Task<Void, Never>?
    private var mobileDataGuidanceDelay: Task<Void, Never>?
    private var localDevVPNProbeTask: Task<Void, Never>?
    private var localDevVPNReturnTimeout: Task<Void, Never>?
    private var pendingSession: PendingSession?
    private var resolvedService: RemotePairingService?
    private var sawNonMatchingService = false
    private var isDiscoveringServices = false
    private var hasRequestedLocalDevVPNThisAttempt = false
    private var wifiPathStatusIsKnown = false
    private var isWiFiPathSatisfied = false
    private var isMobileDataStartupMode = false
    private var serviceProbeConnection: NWConnection?
    private var serviceProbeTimeout: Task<Void, Never>?
    private var serviceProbeRetryTask: Task<Void, Never>?
    private var serviceProbeAttemptCount = 0

    private var activeSession: OpaquePointer?
    private var activeRunIdentifier: UUID?
    private var submittedTaskIdentifier: String?
    private var backgroundTask: BGContinuedProcessingTask?
    private var backgroundProgressTask: Task<Void, Never>?
    private var backgroundTaskFinished = true
    private var workerIsRunning = false
    private var cancellationRequested = false
    private var pendingFailureMessage: String?

    override init() {
        super.init()
        browser.delegate = self
        browser.includesPeerToPeer = true
        wifiPathMonitor.pathUpdateHandler = { [weak self] path in
            let isSatisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.wifiPathStatusIsKnown = true
                self?.isWiFiPathSatisfied = isSatisfied
            }
        }
        wifiPathMonitor.start(queue: wifiPathMonitorQueue)
    }

    var isBusy: Bool {
        switch phase {
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            true
        case .idle, .active, .failed:
            false
        }
    }

    func start(pairingRecord: Data, target: LocationTarget) {
        guard !workerIsRunning, !isBusy else { return }

#if targetEnvironment(simulator)
        phase = .failed("A real iPhone is required to start a location session.")
#else
        cancellationRequested = false
        pendingFailureMessage = nil
        mobileDataGuidance = nil
        hasRequestedLocalDevVPNThisAttempt = false
        isMobileDataStartupMode = false
        pendingSession = PendingSession(pairingRecord: pairingRecord, target: target)
        resolvedService = nil
        phase = .discovering
        routeStartupForCurrentNetwork()
#endif
    }

    func handleOpenURL(_ url: URL) {
        guard url.scheme?.lowercased() == "roamcontrol" else { return }
        guard pendingSession != nil else { return }
        guard phase == .openingLocalDevVPN || phase == .discovering else { return }

        localDevVPNReturnTimeout?.cancel()
        localDevVPNReturnTimeout = nil
        guard mobileDataGuidance != .turnOff else { return }
        if isMobileDataStartupMode {
            enterMobileDataGuidance()
        } else {
            beginDiscovery(showConnectionHelpIfUnavailable: true)
        }
    }

    @discardableResult
    func updateLocation(_ target: LocationTarget) -> ActiveLocationUpdateResult {
        guard
            workerIsRunning,
            case .active = phase,
            let activeSession,
            let pendingSession
        else { return .unavailable }

        guard rc_location_session_update(activeSession, target.latitude, target.longitude) == 0 else {
            fail("Roam Control could not update the active location.")
            return .failed
        }

        self.pendingSession = PendingSession(
            pairingRecord: pendingSession.pairingRecord,
            target: target
        )
        phase = .active(target)
        backgroundTask?.updateTitle(
            "Roam Control",
            subtitle: "Location active at \(target.name)"
        )
        return .updated
    }

    func openLocalDevVPN() {
#if !targetEnvironment(simulator)
        if pendingSession != nil, !workerIsRunning {
            openLocalDevVPNForPendingSession()
            return
        }

        UIApplication.shared.open(Self.enableURL) { [weak self] opened in
            guard !opened else { return }
            Task { @MainActor in
                self?.fail("Install LocalDevVPN before starting a location session.")
            }
        }
#endif
    }

    func dismissMobileDataGuidance() {
        mobileDataGuidance = nil
    }

    func confirmMobileDataIsOff() {
        guard mobileDataGuidance == .turnOff, pendingSession != nil else { return }
        automaticDiscoveryTask?.cancel()
        mobileDataDiscoveryLoopTask?.cancel()
        mobileDataDiscoveryLoopTask = nil
        automaticDiscoveryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled, let self else { return }
            self.automaticDiscoveryTask = nil
            self.startMobileDataDiscoveryLoop()
        }
    }

    func useMobileDataGuidance() {
        guard mobileDataGuidance == .connectionHelp, pendingSession != nil else { return }
        isMobileDataStartupMode = true
        enterMobileDataGuidance()
    }

    func retryConnection() {
        guard mobileDataGuidance == .connectionHelp, pendingSession != nil else { return }
        mobileDataGuidance = nil
        resolvedService = nil
        beginDiscovery(showConnectionHelpIfUnavailable: true)
    }

    func appDidBecomeActive() {
        if
            phase == .openingLocalDevVPN,
            pendingSession != nil,
            !workerIsRunning
        {
            automaticDiscoveryTask?.cancel()
            automaticDiscoveryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                guard
                    !Task.isCancelled,
                    let self,
                    self.pendingSession != nil,
                    self.phase == .openingLocalDevVPN,
                    !self.workerIsRunning
                else { return }

                self.automaticDiscoveryTask = nil
                if self.isMobileDataStartupMode {
                    self.enterMobileDataGuidance()
                } else {
                    self.beginDiscovery(showConnectionHelpIfUnavailable: true)
                }
            }
            return
        }

        guard mobileDataGuidance == .turnOff else { return }
        startMobileDataDiscoveryLoop()
    }

    func stop() {
        mobileDataGuidance = nil
        switch phase {
        case .idle:
            return
        case .openingLocalDevVPN, .discovering:
            cancellationRequested = true
            cleanupDiscovery()
            clearPendingSession()
            phase = .idle
        case .connecting, .active:
            cancellationRequested = true
            phase = .stopping
            if let activeSession {
                rc_location_session_cancel(activeSession)
            } else if let submittedTaskIdentifier {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: submittedTaskIdentifier)
                clearPendingSession()
                phase = .idle
            }
        case .stopping:
            break
        case .failed:
            clearPendingSession()
            phase = .idle
        }
    }

    func reset() {
        stop()
        if !workerIsRunning {
            clearPendingSession()
            phase = .idle
        }
    }

    private func beginDiscovery(
        reportTimeout: Bool = true,
        openLocalDevVPNIfUnavailable: Bool = false,
        showConnectionHelpIfUnavailable: Bool = false
    ) {
        cleanupDiscovery()
        sawNonMatchingService = false
        isDiscoveringServices = true
        phase = .discovering
        browser.delegate = self
        browser.searchForServices(ofType: "_remotepairing._tcp.", inDomain: "local.")

        if showConnectionHelpIfUnavailable {
            mobileDataGuidanceDelay = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard
                    !Task.isCancelled,
                    let self,
                    self.pendingSession != nil,
                    self.phase == .discovering,
                    !self.workerIsRunning,
                    self.resolvedService == nil
                else { return }
                self.mobileDataGuidance = .connectionHelp
            }
        }

        if openLocalDevVPNIfUnavailable {
            localDevVPNProbeTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                guard
                    !Task.isCancelled,
                    let self,
                    self.pendingSession != nil,
                    self.phase == .discovering,
                    !self.workerIsRunning,
                    self.resolvedService == nil
                else { return }

                self.localDevVPNProbeTask = nil
                self.openLocalDevVPNForPendingSession()
            }
        }

        if reportTimeout {
            discoveryTimeout = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard let self, self.phase == .discovering else { return }
                if self.sawNonMatchingService {
                    self.fail(
                        "Roam Control found an outdated device announcement. Toggle LocalDevVPN off and on, then try again."
                    )
                } else {
                    self.fail(
                        "Roam Control could not find this iPhone through LocalDevVPN. Check that the tunnel is enabled and try again."
                    )
                }
            }
        }
    }

    private func resolve(_ service: NetService) {
        service.delegate = self
        service.includesPeerToPeer = true
        service.schedule(in: .main, forMode: .common)
        service.resolve(withTimeout: 8)
        discoveredServices.append(service)
    }

    private func useResolvedService(_ service: NetService) {
        guard phase == .discovering else { return }
        guard service.port > 0, service.port <= Int(UInt16.max) else { return }
        guard
            let txtData = service.txtRecordData(),
            let identifierData = NetService.dictionary(fromTXTRecord: txtData)["identifier"],
            let authTagData = NetService.dictionary(fromTXTRecord: txtData)["authTag"]
        else { return }

        let identifier = String(decoding: identifierData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let authTag = String(decoding: authTagData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, !authTag.isEmpty else { return }
        guard let pairingRecord = pendingSession?.pairingRecord else { return }

        let matchesPairedDevice = pairingRecord.withUnsafeBytes { recordBytes in
            guard let recordBaseAddress = recordBytes.bindMemory(to: UInt8.self).baseAddress else {
                return false
            }

            return identifier.withCString { serviceIdentifier in
                authTag.withCString { authTag in
                    rc_pairing_record_matches_service(
                        recordBaseAddress,
                        pairingRecord.count,
                        serviceIdentifier,
                        authTag
                    ) == 1
                }
            }
        }

        guard matchesPairedDevice else {
            sawNonMatchingService = true
            service.startMonitoring()
            return
        }

        guard serviceProbeConnection == nil, serviceProbeRetryTask == nil else { return }
        verifyServiceIsReachable(RemotePairingService(
            port: UInt16(service.port),
            identifier: identifier,
            authTag: authTag
        ))
    }

    private func submitLocationTask() {
        guard let pendingSession, resolvedService != nil else {
            fail("Roam Control could not prepare the selected location.")
            return
        }

        phase = .connecting
        let identifier = "\(Self.taskIdentifierPrefix).\(UUID().uuidString)"
        let wasRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: .main
        ) { [weak self] task in
            guard let task = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }

            MainActor.assumeIsolated {
                guard let self else {
                    task.setTaskCompleted(success: false)
                    return
                }
                self.beginLocationSession(with: task)
            }
        }

        guard wasRegistered else {
            fail("iOS could not prepare the location session. Close Roam Control, reopen it, and try again.")
            return
        }

        submittedTaskIdentifier = identifier
        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: "Roam Control",
            subtitle: "Connecting to \(pendingSession.target.name)…"
        )
        request.strategy = .fail

        Task {
            do {
                try await BGTaskScheduler.shared.submitTaskRequest(request)
            } catch {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
                self.submittedTaskIdentifier = nil
                self.resolvedService = nil
                if self.isMobileDataStartupMode {
                    self.enterMobileDataGuidance()
                } else if self.hasRequestedLocalDevVPNThisAttempt {
                    self.phase = .discovering
                    self.mobileDataGuidance = .connectionHelp
                } else {
                    self.openLocalDevVPNForPendingSession()
                }
            }
        }
    }

    private func beginLocationSession(with task: BGContinuedProcessingTask) {
        guard phase == .connecting, !workerIsRunning else {
            task.setTaskCompleted(success: false)
            return
        }

        backgroundTask = task
        backgroundTaskFinished = false
        task.progress.totalUnitCount = 5_760
        task.progress.completedUnitCount = 1
        task.expirationHandler = { [weak self] in
            Task { @MainActor in
                self?.locationTaskExpired()
            }
        }
        startBackgroundProgress(for: task)

        runNativeLocationSession()
    }

    private func startBackgroundProgress(for task: BGContinuedProcessingTask) {
        backgroundProgressTask?.cancel()
        backgroundProgressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard
                    !Task.isCancelled,
                    let self,
                    self.backgroundTask === task,
                    !self.backgroundTaskFinished
                else { return }

                task.progress.completedUnitCount = min(
                    task.progress.completedUnitCount + 1,
                    task.progress.totalUnitCount - 1
                )
            }
        }
    }

    private func runNativeLocationSession() {
        guard let pendingSession, let resolvedService else {
            fail("Roam Control lost the location session details.")
            return
        }
        guard let session = rc_location_session_create() else {
            fail("Roam Control could not start its location engine.")
            return
        }

        let runIdentifier = UUID()
        activeRunIdentifier = runIdentifier
        activeSession = session
        workerIsRunning = true

        let sessionBits = UInt(bitPattern: session)
        let contextBits = UInt(bitPattern: Unmanaged.passRetained(self).toOpaque())
        let pairingRecord = pendingSession.pairingRecord
        let target = pendingSession.target
        let peerAddressString = Self.localDevVPNPeerAddress

        DispatchQueue.global(qos: .userInitiated).async {
            guard
                let session = OpaquePointer(bitPattern: sessionBits),
                let context = UnsafeMutableRawPointer(bitPattern: contextBits)
            else { return }

            var result = RCLocationResult()
            let returnCode = pairingRecord.withUnsafeBytes { recordBytes in
                guard let recordBaseAddress = recordBytes.bindMemory(to: UInt8.self).baseAddress else {
                    return Int32(-1)
                }

                return peerAddressString.withCString { peerAddress in
                    resolvedService.identifier.withCString { serviceIdentifier in
                        resolvedService.authTag.withCString { authTag in
                            rc_location_session_run(
                                session,
                                recordBaseAddress,
                                pairingRecord.count,
                                peerAddress,
                                resolvedService.port,
                                serviceIdentifier,
                                authTag,
                                target.latitude,
                                target.longitude,
                                locationStartedCallback,
                                context,
                                &result
                            )
                        }
                    }
                }
            }

            let outcome = NativeLocationOutcome(result: result, returnCode: returnCode)
            rc_location_result_destroy(&result)

            DispatchQueue.main.async {
                if let session = OpaquePointer(bitPattern: sessionBits) {
                    rc_location_session_destroy(session)
                }
                let coordinator = Unmanaged<LocalDeviceSessionCoordinator>
                    .fromOpaque(context)
                    .takeRetainedValue()
                coordinator.nativeLocationFinished(outcome, runIdentifier: runIdentifier)
            }
        }
    }

    fileprivate func nativeLocationStarted() {
        guard workerIsRunning, !cancellationRequested, let target = pendingSession?.target else { return }
        mobileDataDiscoveryLoopTask?.cancel()
        mobileDataDiscoveryLoopTask = nil
        phase = .active(target)
        if mobileDataGuidance == .turnOff {
            mobileDataGuidance = .turnBackOn
        }
        backgroundTask?.updateTitle(
            "Roam Control",
            subtitle: "Location active at \(target.name)"
        )
    }

    private func nativeLocationFinished(
        _ outcome: NativeLocationOutcome,
        runIdentifier: UUID
    ) {
        guard activeRunIdentifier == runIdentifier else { return }

        activeRunIdentifier = nil
        activeSession = nil
        workerIsRunning = false

        if let pendingFailureMessage {
            self.pendingFailureMessage = nil
            mobileDataGuidance = nil
            clearPendingSession()
            phase = .failed(pendingFailureMessage)
            finishBackgroundTask(success: false)
            return
        }

        if cancellationRequested {
            cancellationRequested = false
            clearPendingSession()
            phase = .idle
            finishBackgroundTask(success: true)
            return
        }

        switch outcome {
        case .success:
            mobileDataGuidance = nil
            clearPendingSession()
            phase = .idle
            finishBackgroundTask(success: true)
        case .failure(let message):
            if isRecoverableTunnelConnectionFailure(message) {
                resolvedService = nil
                finishBackgroundTask(success: false)
                if isMobileDataStartupMode {
                    enterMobileDataGuidance()
                } else if hasRequestedLocalDevVPNThisAttempt {
                    phase = .discovering
                    mobileDataGuidance = .connectionHelp
                } else {
                    openLocalDevVPNForPendingSession()
                }
                return
            }

            mobileDataGuidance = nil
            clearPendingSession()
            phase = .failed(message)
            finishBackgroundTask(success: false)
        }
    }

    private func locationTaskExpired() {
        cancellationRequested = true
        pendingFailureMessage = nil
        mobileDataGuidance = nil
        phase = .stopping

        if let activeSession {
            rc_location_session_cancel(activeSession)
        } else {
            clearPendingSession()
            phase = .idle
        }

        finishBackgroundTask(success: true)
    }

    private func fail(_ message: String) {
        localDevVPNReturnTimeout?.cancel()
        localDevVPNReturnTimeout = nil
        mobileDataGuidance = nil
        cleanupDiscovery()

        if workerIsRunning, let activeSession {
            pendingFailureMessage = message
            rc_location_session_cancel(activeSession)
        } else {
            clearPendingSession()
        }

        phase = .failed(message)
        finishBackgroundTask(success: false)
    }

    private func cleanupDiscovery() {
        isDiscoveringServices = false
        cleanupServiceProbe()
        discoveryTimeout?.cancel()
        discoveryTimeout = nil
        mobileDataGuidanceDelay?.cancel()
        mobileDataGuidanceDelay = nil
        localDevVPNProbeTask?.cancel()
        localDevVPNProbeTask = nil
        browser.stop()

        for service in discoveredServices {
            service.stopMonitoring()
            service.stop()
            service.remove(from: .main, forMode: .common)
            service.delegate = nil
        }
        discoveredServices = []
    }

    private func verifyServiceIsReachable(_ service: RemotePairingService) {
        guard
            phase == .discovering,
            pendingSession != nil,
            serviceProbeConnection == nil
        else { return }
        guard let port = NWEndpoint.Port(rawValue: service.port) else {
            handleServiceProbeResult(false, service: service)
            return
        }

        serviceProbeAttemptCount += 1
        let connection = NWConnection(
            host: NWEndpoint.Host(Self.localDevVPNPeerAddress),
            port: port,
            using: .tcp
        )
        serviceProbeConnection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let connection else { return }
            switch state {
            case .ready:
                Task { @MainActor [weak self] in
                    self?.finishServiceProbe(connection, service: service, reachable: true)
                }
            case .failed, .cancelled:
                Task { @MainActor [weak self] in
                    self?.finishServiceProbe(connection, service: service, reachable: false)
                }
            case .setup, .waiting, .preparing:
                break
            @unknown default:
                break
            }
        }

        serviceProbeTimeout = Task { @MainActor [weak self, weak connection] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, let self, let connection else { return }
            self.finishServiceProbe(connection, service: service, reachable: false)
        }
        connection.start(queue: serviceProbeQueue)
    }

    private func finishServiceProbe(
        _ connection: NWConnection,
        service: RemotePairingService,
        reachable: Bool
    ) {
        guard serviceProbeConnection === connection else { return }
        serviceProbeConnection = nil
        serviceProbeTimeout?.cancel()
        serviceProbeTimeout = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
        handleServiceProbeResult(reachable, service: service)
    }

    private func handleServiceProbeResult(
        _ reachable: Bool,
        service: RemotePairingService
    ) {
        guard phase == .discovering, pendingSession != nil else { return }

        if reachable {
            serviceProbeAttemptCount = 0
            resolvedService = service
            mobileDataDiscoveryLoopTask?.cancel()
            mobileDataDiscoveryLoopTask = nil
            if mobileDataGuidance == .connectionHelp {
                mobileDataGuidance = nil
            }
            cleanupDiscovery()
            submitLocationTask()
            return
        }

        if isMobileDataStartupMode {
            serviceProbeAttemptCount = 0
            return
        }

        if !hasRequestedLocalDevVPNThisAttempt {
            serviceProbeAttemptCount = 0
            openLocalDevVPNForPendingSession()
            return
        }

        guard serviceProbeAttemptCount < 3 else {
            serviceProbeAttemptCount = 0
            mobileDataGuidance = .connectionHelp
            return
        }

        serviceProbeRetryTask?.cancel()
        serviceProbeRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, let self else { return }
            self.serviceProbeRetryTask = nil
            self.verifyServiceIsReachable(service)
        }
    }

    private func cleanupServiceProbe() {
        serviceProbeTimeout?.cancel()
        serviceProbeTimeout = nil
        serviceProbeRetryTask?.cancel()
        serviceProbeRetryTask = nil
        serviceProbeConnection?.stateUpdateHandler = nil
        serviceProbeConnection?.cancel()
        serviceProbeConnection = nil
        serviceProbeAttemptCount = 0
    }

    private func clearPendingSession() {
        automaticDiscoveryTask?.cancel()
        automaticDiscoveryTask = nil
        networkDecisionTask?.cancel()
        networkDecisionTask = nil
        mobileDataDiscoveryLoopTask?.cancel()
        mobileDataDiscoveryLoopTask = nil
        localDevVPNReturnTimeout?.cancel()
        localDevVPNReturnTimeout = nil
        cleanupDiscovery()
        pendingSession = nil
        resolvedService = nil
        submittedTaskIdentifier = nil
        hasRequestedLocalDevVPNThisAttempt = false
        isMobileDataStartupMode = false
    }

    private func finishBackgroundTask(success: Bool) {
        guard !backgroundTaskFinished else { return }
        backgroundTaskFinished = true
        backgroundProgressTask?.cancel()
        backgroundProgressTask = nil
        backgroundTask?.setTaskCompleted(success: success)
        backgroundTask = nil
        submittedTaskIdentifier = nil
    }

    private func isRecoverableTunnelConnectionFailure(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("through LocalDevVPN")
            || message.localizedCaseInsensitiveContains("make the iPhone connection available")
            || message.localizedCaseInsensitiveContains("open the secure device tunnel")
    }

    private func routeStartupForCurrentNetwork() {
        networkDecisionTask?.cancel()
        networkDecisionTask = nil
        mobileDataGuidance = nil

        if wifiPathStatusIsKnown {
            if isWiFiPathSatisfied {
                beginDiscovery(openLocalDevVPNIfUnavailable: true)
            } else {
                isMobileDataStartupMode = true
                openLocalDevVPNForPendingSession()
            }
            return
        }

        networkDecisionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard
                !Task.isCancelled,
                let self,
                self.pendingSession != nil,
                !self.workerIsRunning
            else { return }

            self.networkDecisionTask = nil
            if self.wifiPathStatusIsKnown, !self.isWiFiPathSatisfied {
                self.isMobileDataStartupMode = true
                self.openLocalDevVPNForPendingSession()
            } else {
                self.beginDiscovery(openLocalDevVPNIfUnavailable: true)
            }
        }
    }

    private func enterMobileDataGuidance() {
        guard pendingSession != nil, !workerIsRunning else { return }
        cleanupDiscovery()
        phase = .discovering
        mobileDataGuidance = .turnOff
        startMobileDataDiscoveryLoop()
    }

    private func startMobileDataDiscoveryLoop() {
        guard
            isMobileDataStartupMode,
            mobileDataGuidance == .turnOff,
            pendingSession != nil,
            !workerIsRunning
        else { return }

        mobileDataDiscoveryLoopTask?.cancel()
        mobileDataDiscoveryLoopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard
                    let self,
                    self.isMobileDataStartupMode,
                    self.mobileDataGuidance == .turnOff,
                    self.pendingSession != nil,
                    !self.workerIsRunning
                else { return }

                self.resolvedService = nil
                self.beginDiscovery(reportTimeout: false)
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private func openLocalDevVPNForPendingSession() {
#if !targetEnvironment(simulator)
        guard pendingSession != nil, !workerIsRunning else { return }
        cleanupDiscovery()
        mobileDataGuidance = nil
        hasRequestedLocalDevVPNThisAttempt = true
        phase = .openingLocalDevVPN

        UIApplication.shared.open(Self.enableURL) { [weak self] opened in
            guard !opened else { return }
            Task { @MainActor in
                self?.fail("Install LocalDevVPN before starting a location session.")
            }
        }
#endif
    }

}

extension LocalDeviceSessionCoordinator: NetServiceBrowserDelegate, NetServiceDelegate {
    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        MainActor.assumeIsolated {
            resolve(service)
        }
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        MainActor.assumeIsolated {
            fail("Local Network access is required to find this iPhone.")
        }
    }

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        MainActor.assumeIsolated {
            useResolvedService(sender)
        }
    }

    nonisolated func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        MainActor.assumeIsolated {
            useResolvedService(sender)
        }
    }
}

private enum NativeLocationOutcome: Sendable {
    case success
    case failure(String)

    init(result: RCLocationResult, returnCode: Int32) {
        guard returnCode != 0 else {
            self = .success
            return
        }

        let message: String
        if let errorMessage = result.error_message {
            message = String(cString: errorMessage)
        } else {
            message = ""
        }
        self = .failure(message.isEmpty ? "The iPhone could not start the location session." : message)
    }
}

private let locationStartedCallback: RCLocationStartedCallback = { context in
    guard let context else { return }
    let contextBits = UInt(bitPattern: context)

    DispatchQueue.main.async {
        guard let context = UnsafeMutableRawPointer(bitPattern: contextBits) else { return }
        let coordinator = Unmanaged<LocalDeviceSessionCoordinator>
            .fromOpaque(context)
            .takeUnretainedValue()
        coordinator.nativeLocationStarted()
    }
}

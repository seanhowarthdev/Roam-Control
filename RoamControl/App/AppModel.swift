import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private static let onboardingKey = "hasCompletedOnboarding"
    private static let favouritesKey = "favouriteLocations"
    private static let historyKey = "locationHistory"
    private static let dismissedResumeLocationKey = "dismissedResumeLocation"
    private static let appearanceKey = "appAppearance"
    private static let mapDisplayStyleKey = "mapDisplayStyle"
    private static let activeSessionRecoveryKey = "activeSessionRecovery"
    private static let anonymousUsageStatisticsKey = "sharesAnonymousUsageStatistics"

    private let preferences: UserDefaults

    private(set) var hasCompletedOnboarding: Bool
    private(set) var shouldPresentDeviceSetup = false
    private(set) var connectionState: ConnectionState = .notConfigured
    private(set) var pairingStatus: PairingStatus = .checking
    private(set) var selectedTarget: LocationTarget?
    private(set) var favouriteLocations: [LocationTarget]
    private(set) var locationHistory: [LocationTarget]
    private(set) var dismissedResumeLocationID: String?
    private(set) var appearance: AppAppearance
    private(set) var mapDisplayStyle: MapDisplayStyle
    private(set) var sharesAnonymousUsageStatistics: Bool
    private(set) var interruptedSession: SessionRecoveryRecord?
    private(set) var isRestoringInterruptedSession = false
    private(set) var interruptedSessionError: String?

    private var activeSessionRecovery: SessionRecoveryRecord?
    private var lastRecoverySaveDate: Date?
    private var restorationReachedActiveSession = false
    private var pendingSessionAnalyticsEvent: UsageAnalyticsEvent?

    let pairingService: any PairingService
    let onDevicePairing: OnDevicePairingCoordinator
    let deviceSession: LocalDeviceSessionCoordinator
    private let usageAnalytics: UsageAnalyticsService
    let localDevVPNInstallURL = URL(string: "https://apps.apple.com/app/localdevvpn/id6755608044")!

    init(
        pairingService: any PairingService = SecurePairingService(),
        preferences: UserDefaults = .standard
    ) {
        self.pairingService = pairingService
        self.onDevicePairing = .shared
        self.deviceSession = LocalDeviceSessionCoordinator()
        self.usageAnalytics = UsageAnalyticsService(preferences: preferences)
        self.preferences = preferences
        let hasCompletedOnboarding = preferences.bool(forKey: Self.onboardingKey)
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.favouriteLocations = Self.locations(forKey: Self.favouritesKey, in: preferences)
        self.locationHistory = Self.locations(forKey: Self.historyKey, in: preferences)
        self.dismissedResumeLocationID = preferences.string(forKey: Self.dismissedResumeLocationKey)
        self.appearance = AppAppearance(
            rawValue: preferences.string(forKey: Self.appearanceKey) ?? ""
        ) ?? .automatic
        self.mapDisplayStyle = MapDisplayStyle(
            rawValue: preferences.string(forKey: Self.mapDisplayStyleKey) ?? ""
        ) ?? .standard
        self.sharesAnonymousUsageStatistics = Self.initialUsageStatisticsPreference(
            in: preferences
        )
        self.interruptedSession = Self.recoveryRecord(in: preferences)

        deviceSession.onPhaseChange = { [weak self] phase in
            self?.applyDeviceSessionPhase(phase)
        }

        if hasCompletedOnboarding {
            usageAnalytics.recordActivation(enabled: sharesAnonymousUsageStatistics)
        }
    }

    func chooseTarget(_ target: LocationTarget) {
        selectedTarget = target
        addToHistory(target)
    }

    var resumeLocation: LocationTarget? {
        guard let lastLocation = locationHistory.first else { return nil }
        return lastLocation.id == dismissedResumeLocationID ? nil : lastLocation
    }

    func dismissResumeLocation() {
        guard let lastLocation = locationHistory.first else { return }
        dismissedResumeLocationID = lastLocation.id
        preferences.set(lastLocation.id, forKey: Self.dismissedResumeLocationKey)
    }

    func isFavourite(_ target: LocationTarget) -> Bool {
        favouriteLocations.contains { $0.id == target.id }
    }

    func toggleFavourite(_ target: LocationTarget) {
        if let index = favouriteLocations.firstIndex(where: { $0.id == target.id }) {
            favouriteLocations.remove(at: index)
        } else {
            favouriteLocations.insert(target, at: 0)
        }
        save(favouriteLocations, forKey: Self.favouritesKey)
    }

    func removeFavourite(_ target: LocationTarget) {
        favouriteLocations.removeAll { $0.id == target.id }
        save(favouriteLocations, forKey: Self.favouritesKey)
    }

    func renameFavourite(_ target: LocationTarget, to proposedName: String) {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !name.isEmpty,
            let index = favouriteLocations.firstIndex(where: { $0.id == target.id })
        else { return }

        let renamed = LocationTarget(
            name: name,
            subtitle: target.subtitle,
            latitude: target.latitude,
            longitude: target.longitude
        )
        favouriteLocations[index] = renamed
        if selectedTarget?.id == target.id {
            selectedTarget = renamed
        }
        save(favouriteLocations, forKey: Self.favouritesKey)
    }

    func removeFromHistory(_ target: LocationTarget) {
        locationHistory.removeAll { $0.id == target.id }
        save(locationHistory, forKey: Self.historyKey)
    }

    func clearLocationHistory() {
        locationHistory = []
        dismissedResumeLocationID = nil
        preferences.removeObject(forKey: Self.historyKey)
    }

    func clearFavouriteLocations() {
        favouriteLocations = []
        preferences.removeObject(forKey: Self.favouritesKey)
    }

    func setAppearance(_ appearance: AppAppearance) {
        self.appearance = appearance
        preferences.set(appearance.rawValue, forKey: Self.appearanceKey)
    }

    func setMapDisplayStyle(_ style: MapDisplayStyle) {
        mapDisplayStyle = style
        preferences.set(style.rawValue, forKey: Self.mapDisplayStyleKey)
    }

    func setSharesAnonymousUsageStatistics(_ enabled: Bool) {
        sharesAnonymousUsageStatistics = enabled
        preferences.set(enabled, forKey: Self.anonymousUsageStatisticsKey)

        if enabled, hasCompletedOnboarding {
            usageAnalytics.recordActivation(enabled: true)
        } else if !enabled {
            usageAnalytics.revokeLocalIdentity()
        }
    }

    func completeOnboarding() {
        preferences.set(
            sharesAnonymousUsageStatistics,
            forKey: Self.anonymousUsageStatisticsKey
        )
        preferences.set(true, forKey: Self.onboardingKey)
        shouldPresentDeviceSetup = true
        hasCompletedOnboarding = true
        usageAnalytics.record(
            .onboardingCompleted,
            enabled: sharesAnonymousUsageStatistics
        )
        usageAnalytics.recordActivation(enabled: sharesAnonymousUsageStatistics)
    }

    func deviceSetupWasPresented() {
        shouldPresentDeviceSetup = false
    }

    func resetApp() async throws {
        onDevicePairing.reset()
        deviceSession.reset()
        try await pairingService.removeRecord()

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            preferences.removePersistentDomain(forName: bundleIdentifier)
        } else {
            preferences.removeObject(forKey: Self.onboardingKey)
        }

        selectedTarget = nil
        favouriteLocations = []
        locationHistory = []
        appearance = .automatic
        mapDisplayStyle = .standard
        sharesAnonymousUsageStatistics = false
        interruptedSession = nil
        activeSessionRecovery = nil
        isRestoringInterruptedSession = false
        interruptedSessionError = nil
        pairingStatus = .notPaired
        connectionState = .notConfigured
        shouldPresentDeviceSetup = false
        hasCompletedOnboarding = false
        usageAnalytics.revokeLocalIdentity()
    }

    func restorePairingStatus() async {
        pairingStatus = .checking

        do {
            if let summary = try await pairingService.storedRecord() {
                pairingStatus = .paired(summary)
                if deviceSession.phase == .idle {
                    connectionState = .ready
                }
            } else {
                pairingStatus = .notPaired
                connectionState = .notConfigured
            }
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func importPairingRecord(from url: URL) async {
        pairingStatus = .importing

        do {
            let summary = try await pairingService.importRecord(from: url)
            pairingStatus = .paired(summary)
            connectionState = .ready
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func startOnDevicePairing() {
        onDevicePairing.start { [weak self] record, hostAltIRK in
            guard let self else {
                throw PairingServiceError.corruptStoredRecord
            }

            let summary = try await self.pairingService.storeGeneratedRecord(
                record,
                hostAltIRK: hostAltIRK
            )
            self.pairingStatus = .paired(summary)
            self.connectionState = .ready
            self.usageAnalytics.record(
                .pairingCompleted,
                enabled: self.sharesAnonymousUsageStatistics
            )
            return summary
        }
    }

    func cancelOnDevicePairing() {
        onDevicePairing.cancel()
    }

    func startLocationSession(at target: LocationTarget) async {
        await startLocationSession(
            at: target,
            selectedTarget: target,
            historyTarget: target,
            recovery: .fixed(at: target)
        )
    }

    func startWalkingLocationSession(
        at initialTarget: LocationTarget,
        destination: LocationTarget,
        paceMetresPerSecond: Double
    ) async {
        await startLocationSession(
            at: initialTarget,
            selectedTarget: destination,
            historyTarget: destination,
            recovery: .walking(
                from: initialTarget,
                to: destination,
                paceMetresPerSecond: paceMetresPerSecond
            )
        )
    }

    private func startLocationSession(
        at deviceTarget: LocationTarget,
        selectedTarget: LocationTarget,
        historyTarget: LocationTarget,
        recovery: SessionRecoveryRecord
    ) async {
        guard case .paired = pairingStatus else {
            connectionState = .notConfigured
            return
        }

        self.selectedTarget = selectedTarget
        dismissInterruptedSessionRecovery()
        activeSessionRecovery = recovery
        lastRecoverySaveDate = nil
        dismissedResumeLocationID = nil
        preferences.removeObject(forKey: Self.dismissedResumeLocationKey)
        addToHistory(historyTarget)
        switch deviceSession.updateLocation(deviceTarget) {
        case .updated:
            usageAnalytics.record(
                .activeLocationUpdated,
                enabled: sharesAnonymousUsageStatistics
            )
            return
        case .failed:
            return
        case .unavailable:
            break
        }

        do {
            guard let pairingRecord = try await pairingService.pairingRecordData() else {
                activeSessionRecovery = nil
                pendingSessionAnalyticsEvent = nil
                pairingStatus = .notPaired
                connectionState = .notConfigured
                return
            }
            pendingSessionAnalyticsEvent = recovery.kind == .walkingRoute
                ? .walkingStarted
                : .fixedLocationStarted
            deviceSession.start(pairingRecord: pairingRecord, target: deviceTarget)
        } catch {
            activeSessionRecovery = nil
            pendingSessionAnalyticsEvent = nil
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func restoreRealLocationFromInterruptedSession() async {
        guard let recovery = interruptedSession else { return }
        guard case .paired = pairingStatus else {
            interruptedSessionError = "Pair this iPhone before restoring its real location."
            return
        }

        interruptedSessionError = nil
        isRestoringInterruptedSession = true
        restorationReachedActiveSession = false

        do {
            guard let pairingRecord = try await pairingService.pairingRecordData() else {
                isRestoringInterruptedSession = false
                interruptedSessionError = "The saved pairing record is unavailable. Pair this iPhone again."
                return
            }
            deviceSession.start(
                pairingRecord: pairingRecord,
                target: recovery.lastReportedLocation
            )
        } catch {
            isRestoringInterruptedSession = false
            interruptedSessionError = error.localizedDescription
        }
    }

    func cancelInterruptedSessionRestoration() {
        guard isRestoringInterruptedSession else { return }
        deviceSession.stop()
    }

    func completeInterruptedSessionRestorationAfterMobileData() {
        guard isRestoringInterruptedSession, restorationReachedActiveSession else { return }
        deviceSession.dismissMobileDataGuidance()
        deviceSession.stop()
    }

    func dismissInterruptedSessionRecovery() {
        interruptedSession = nil
        interruptedSessionError = nil
        preferences.removeObject(forKey: Self.activeSessionRecoveryKey)
    }

    func stopLocationSession() {
        deviceSession.stop()
    }

    func handleOpenURL(_ url: URL) {
        deviceSession.handleOpenURL(url)
    }

    func appBecameActive() {
        guard hasCompletedOnboarding else { return }
        usageAnalytics.recordActivation(enabled: sharesAnonymousUsageStatistics)
    }

    func removePairingRecord() async {
        onDevicePairing.reset()
        deviceSession.reset()
        do {
            try await pairingService.removeRecord()
            pairingStatus = .notPaired
            connectionState = .notConfigured
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    private func addToHistory(_ target: LocationTarget) {
        locationHistory.removeAll { $0.id == target.id }
        locationHistory.insert(target, at: 0)
        locationHistory = Array(locationHistory.prefix(30))
        save(locationHistory, forKey: Self.historyKey)
    }

    private func applyDeviceSessionPhase(_ phase: DeviceSessionPhase) {
        switch phase {
        case .idle:
            pendingSessionAnalyticsEvent = nil
            if isRestoringInterruptedSession {
                let didRestore = restorationReachedActiveSession
                isRestoringInterruptedSession = false
                restorationReachedActiveSession = false
                if didRestore {
                    dismissInterruptedSessionRecovery()
                }
            }
            clearActiveSessionRecovery()
            if case .paired = pairingStatus {
                connectionState = .ready
            } else {
                connectionState = .notConfigured
            }
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            connectionState = .connecting
        case .active(let target):
            connectionState = .active
            if let event = pendingSessionAnalyticsEvent {
                usageAnalytics.record(event, enabled: sharesAnonymousUsageStatistics)
                pendingSessionAnalyticsEvent = nil
            }
            if isRestoringInterruptedSession {
                restorationReachedActiveSession = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(400))
                    guard let self, self.isRestoringInterruptedSession else { return }
                    if self.deviceSession.mobileDataGuidance != .turnBackOn {
                        self.deviceSession.stop()
                    }
                }
            } else {
                persistActiveSessionRecovery(at: target)
            }
        case .failed(let message):
            pendingSessionAnalyticsEvent = nil
            connectionState = .failed(message: message)
            if isRestoringInterruptedSession {
                isRestoringInterruptedSession = false
                restorationReachedActiveSession = false
                interruptedSessionError = message
            } else {
                clearActiveSessionRecovery()
            }
        }
    }

    private func persistActiveSessionRecovery(at target: LocationTarget) {
        guard var recovery = activeSessionRecovery else { return }
        let now = Date.now

        if
            recovery.kind == .walkingRoute,
            let destination = recovery.destination,
            destination.id == target.id
        {
            recovery = .fixed(at: destination)
        } else {
            recovery.lastReportedLocation = target
            recovery.updatedAt = now
        }
        activeSessionRecovery = recovery

        let shouldSave = lastRecoverySaveDate == nil
            || now.timeIntervalSince(lastRecoverySaveDate ?? .distantPast) >= 5
            || recovery.kind == .fixedLocation
        guard shouldSave, let data = try? JSONEncoder().encode(recovery) else { return }
        preferences.set(data, forKey: Self.activeSessionRecoveryKey)
        lastRecoverySaveDate = now
    }

    private func clearActiveSessionRecovery() {
        guard activeSessionRecovery != nil else { return }
        activeSessionRecovery = nil
        lastRecoverySaveDate = nil
        preferences.removeObject(forKey: Self.activeSessionRecoveryKey)
    }

    private func save(_ locations: [LocationTarget], forKey key: String) {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        preferences.set(data, forKey: key)
    }

    private static func locations(forKey key: String, in preferences: UserDefaults) -> [LocationTarget] {
        guard
            let data = preferences.data(forKey: key),
            let locations = try? JSONDecoder().decode([LocationTarget].self, from: data)
        else {
            return []
        }
        return locations
    }

    private static func recoveryRecord(in preferences: UserDefaults) -> SessionRecoveryRecord? {
        guard
            let data = preferences.data(forKey: Self.activeSessionRecoveryKey),
            let recovery = try? JSONDecoder().decode(SessionRecoveryRecord.self, from: data)
        else { return nil }
        return recovery
    }

    private static func initialUsageStatisticsPreference(
        in preferences: UserDefaults
    ) -> Bool {
        if preferences.object(forKey: Self.anonymousUsageStatisticsKey) != nil {
            return preferences.bool(forKey: Self.anonymousUsageStatisticsKey)
        }

        // A missing preference is never treated as consent. Existing saved
        // choices continue unchanged when the app is upgraded.
        return false
    }
}

enum PairingStatus: Equatable {
    case checking
    case importing
    case notPaired
    case paired(PairingRecordSummary)
    case failed(message: String)
}

enum ConnectionState: Equatable {
    case notConfigured
    case ready
    case connecting
    case active
    case failed(message: String)
}

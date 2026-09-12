import CryptoKit
import Foundation

enum UsageAnalyticsEvent: String {
    case connectionHelpShown = "RoamControl.Connection.HelpShown"
    case connectionRetrySelected = "RoamControl.Connection.RetrySelected"
    case connectionRetrySucceeded = "RoamControl.Connection.RetrySucceeded"
    case connectionRecoveryNeeded = "RoamControl.Connection.RecoveryNeeded"
    case failureObserved = "RoamControl.Failure.Observed"
    case participationStarted = "RoamControl.Analytics.participationStarted"
    case appActivated = "RoamControl.App.activated"
    case onboardingCompleted = "RoamControl.Onboarding.completed"
    case pairingCompleted = "RoamControl.Pairing.completed"
    case pairingFailed = "RoamControl.Pairing.Failed"
    case fixedLocationStarted = "RoamControl.Location.fixedStarted"
    case walkingStarted = "RoamControl.Location.walkingStarted"
    case activeLocationUpdated = "RoamControl.Location.activeUpdated"
    case locationPreparationFailed = "RoamControl.Location.PreparationFailed"
    case locationRestoreFailed = "RoamControl.Location.RestoreFailed"
    case localDevVPNUnreachable = "RoamControl.LocalDevVPN.Unreachable"
    case locationStartFailed = "RoamControl.Location.StartFailed"
}

/// Sends a deliberately small, fixed set of anonymous usage signals.
///
/// This client does not use a third-party SDK so disabling statistics takes
/// effect immediately and no automatic device metadata can be added. It never
/// accepts locations, search text, pairing data, device names or free-form
/// parameters.
@MainActor
final class UsageAnalyticsService {
    private static let anonymousIdentifierKey = "anonymousUsageIdentifier"
    private static let hasReportedParticipationKey = "hasReportedAnalyticsParticipation"

    private let preferences: UserDefaults
    private let urlSession: URLSession
    private var reportingEnabled = false
    private var consentRevision = 0
    private var participationAttemptID: UUID?
    private var lastActivationDate: Date?

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        self.urlSession = URLSession(configuration: configuration)
    }

    func recordActivation(enabled: Bool) {
        reportingEnabled = enabled
        guard enabled, let configuration = Self.configuration else { return }

        let now = Date.now
        if let lastActivationDate, now.timeIntervalSince(lastActivationDate) < 3 {
            return
        }
        lastActivationDate = now

        reportParticipationIfNeeded(configuration: configuration)
        send(.appActivated, configuration: configuration)
    }

    func record(_ event: UsageAnalyticsEvent, enabled: Bool) {
        guard enabled, let configuration = Self.configuration else { return }
        send(event, configuration: configuration)
    }

    func revokeLocalIdentity() {
        reportingEnabled = false
        consentRevision += 1
        participationAttemptID = nil
        lastActivationDate = nil
        preferences.removeObject(forKey: Self.anonymousIdentifierKey)
        preferences.removeObject(forKey: Self.hasReportedParticipationKey)
    }

    func recordFailure(_ stage: FailureStage, context: FailureContext, disposition: FailureDisposition = .terminal, schedulerReason: SchedulerFailureReason? = nil, enabled: Bool) {
        guard enabled, let configuration = Self.configuration else { return }
        send(disposition.event, configuration: configuration, failure: (stage, context, disposition, schedulerReason))
    }

    private func reportParticipationIfNeeded(
        configuration: AnalyticsConfiguration
    ) {
        guard
            !preferences.bool(forKey: Self.hasReportedParticipationKey),
            participationAttemptID == nil
        else { return }

        let attemptID = UUID()
        let revision = consentRevision
        participationAttemptID = attemptID

        send(.participationStarted, configuration: configuration) { [weak self] succeeded in
            guard let self, self.participationAttemptID == attemptID else { return }
            self.participationAttemptID = nil
            guard
                succeeded,
                self.reportingEnabled,
                self.consentRevision == revision
            else { return }
            self.preferences.set(true, forKey: Self.hasReportedParticipationKey)
        }
    }

    private func send(
        _ event: UsageAnalyticsEvent,
        configuration: AnalyticsConfiguration,
        failure: (FailureStage, FailureContext, FailureDisposition, SchedulerFailureReason?)? = nil,
        completion: (@MainActor (Bool) -> Void)? = nil
    ) {
        var payload = Self.safePayload
        if let (stage, context, disposition, schedulerReason) = failure {
            if let schedulerReason {
                payload["RoamControl.schedulerReason"] = schedulerReason.rawValue
            }
            payload["RoamControl.failureDisposition"] = disposition.rawValue
            payload["RoamControl.failureStage"] = stage.rawValue
            payload["RoamControl.failureContext"] = context.rawValue
        }
        let body = AnalyticsSignal(
            appID: configuration.appID,
            clientUser: anonymousClientIdentifier,
            type: event.rawValue,
            isTestMode: Self.isDebugBuild,
            payload: payload
        )

        guard let data = try? JSONEncoder().encode([body]) else {
            completion?(false)
            return
        }

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "application/json; charset=utf-8",
            forHTTPHeaderField: "Content-Type"
        )

        let session = urlSession
        Task {
            do {
                let (_, response) = try await session.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                completion?(statusCode.map { (200..<300).contains($0) } ?? false)
            } catch {
                completion?(false)
            }
        }
    }

    private var anonymousClientIdentifier: String {
        if let existing = preferences.string(forKey: Self.anonymousIdentifierKey) {
            return Self.hash(existing)
        }

        let identifier = UUID().uuidString
        preferences.set(identifier, forKey: Self.anonymousIdentifierKey)
        return Self.hash(identifier)
    }

    private static var configuration: AnalyticsConfiguration? {
        guard
            let appID = configuredValue(for: "RoamControlTelemetryAppID"),
            let namespace = configuredValue(for: "RoamControlTelemetryNamespace"),
            let encodedNamespace = namespace.addingPercentEncoding(
                withAllowedCharacters: .alphanumerics
            ),
            let endpoint = URL(
                string: "https://nom.telemetrydeck.com/v2/namespace/\(encodedNamespace)/"
            )
        else { return nil }

        return AnalyticsConfiguration(appID: appID, endpoint: endpoint)
    }

    private static func configuredValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    private static var safePayload: [String: String] {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Unknown"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "Unknown"

        return [
            "RoamControl.appVersion": version,
            "RoamControl.buildNumber": build
        ]
    }

    private static var isDebugBuild: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    private static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private struct AnalyticsConfiguration {
    let appID: String
    let endpoint: URL
}

private struct AnalyticsSignal: Encodable {
    let appID: String
    let clientUser: String
    let type: String
    let isTestMode: Bool
    let payload: [String: String]
}

// Values are fixed categories. Error text is compared locally and is never transmitted.
enum FailureContext: String {
    case pairing, location, restoration
}

enum FailureStage: String, CaseIterable {
    case pairingRecord
    case discovery
    case vpnConnection
    case pairVerification
    case tunnelCreation
    case tunnelConnection
    case tunnelSecurity
    case serviceDirectory
    case serviceHandshake
    case locationService
    case locationInitialWrite
    case locationActiveWrite
    case locationEngine
    case schedulerRegistration
    case schedulerSubmission
    case pairingAdvertisement
    case pairingConnection
    case pairingAuthentication
    case pairingExpired
    case pairingEngine
    case pairingStorage
    case pairingImport
    case pairingRead
    case locationPreparation
    case locationRestore
    case pairingUnknown
    case locationUnknown

    static func classify(_ message: String, fallback: FailureStage) -> FailureStage {
        switch message {
        case "The iPhone did not confirm stopping location simulation in time.",
             "Roam Control could not confirm stopping location simulation.": return .locationRestore
        case "Roam Control could not securely store the new pairing.": return .pairingStorage
        case "The saved pairing record could not be read.",
             "The saved pairing record is missing its device identity.",
             "The discovered device did not match the paired iPhone.": return .pairingRecord
        case "Roam Control could not identify this iPhone's pairing service.",
             "Roam Control found an outdated device announcement. Toggle LocalDevVPN off and on, then try again.",
             "Roam Control could not find this iPhone through LocalDevVPN. Check that the tunnel is enabled and try again.",
             "Local Network access is required to find this iPhone.": return .discovery
        case "LocalDevVPN returned an invalid device address.",
             "LocalDevVPN did not make the iPhone connection available in time.",
             "Roam Control could not reach the iPhone through LocalDevVPN.",
             "Install LocalDevVPN before starting a location session.": return .vpnConnection
        case "The paired iPhone did not respond in time.",
             "The iPhone rejected the saved pairing session.",
             "Pairing verification took too long.",
             "The saved pairing is no longer valid. Reset Device Setup and pair again.": return .pairVerification
        case "The iPhone did not create its secure tunnel in time.",
             "The iPhone could not create its secure tunnel.": return .tunnelCreation
        case "LocalDevVPN did not open the secure tunnel in time.",
             "Roam Control could not open the secure device tunnel.": return .tunnelConnection
        case "The encrypted device tunnel took too long to start.",
             "Roam Control could not secure the device tunnel.",
             "The iPhone returned an invalid tunnel address.",
             "The iPhone returned an invalid service address.": return .tunnelSecurity
        case "The iPhone's service directory took too long to respond.",
             "Roam Control could not open the iPhone's service directory.": return .serviceDirectory
        case "The iPhone's service handshake took too long.",
             "Roam Control could not complete the iPhone service handshake.": return .serviceHandshake
        case "The location service took too long to open.",
             "The iPhone did not make its location service available.",
             "The location service did not become ready in time.",
             "The iPhone's location service did not become ready.",
             "The location controls took too long to open.",
             "Roam Control could not open the iPhone's location controls.": return .locationService
        case "The iPhone did not accept the selected location.": return .locationInitialWrite
        case "The iPhone ended the active location session.",
             "Roam Control could not update the active location.": return .locationActiveWrite
        case "Roam Control could not start its device session.",
             "The location session stopped unexpectedly.",
             "Roam Control could not start its location engine.": return .locationEngine
        case "iOS could not prepare the location session. Close Roam Control, reopen it, and try again.",
             "iOS could not register the secure pairing task. Close Roam Control, reopen it, and try again.": return .schedulerRegistration
        case "iOS could not keep pairing active in the background. Keep Roam Control open and try again.": return .schedulerSubmission
        case "Local Network access is required. Enable it in Settings › Apps › Roam Control, then try again.": return .pairingAdvertisement
        case "Roam Control could not open a local pairing connection.",
             "Roam Control could not determine its pairing port.",
             "The iPhone could not connect to Roam Control.",
             "The iPhone ended the pairing connection. Start pairing again when you are ready.": return .pairingConnection
        case "The code was not accepted. Start pairing again and enter the new code.": return .pairingAuthentication
        case "Pairing took too long. Return to Roam Control and try again.": return .pairingExpired
        case "Roam Control could not start its pairing engine.",
             "The pairing engine returned an empty record.": return .pairingEngine
        default: return fallback
        }
    }
}

// Tracks only local retry state, never an identifier or location.
struct ConnectionRetryTelemetry {
    private var retryPending = false

    mutating func reset() { retryPending = false }

    mutating func selected() -> UsageAnalyticsEvent {
        retryPending = true
        return .connectionRetrySelected
    }

    mutating func becameActive() -> UsageAnalyticsEvent? {
        guard retryPending else { return nil }
        retryPending = false
        return .connectionRetrySucceeded
    }
}

// Terminal means the current operation ended unsuccessfully; a later user retry may succeed.
enum FailureDisposition: String {
    case terminal, recoverable

    var event: UsageAnalyticsEvent {
        switch self {
        case .terminal: .failureObserved
        case .recoverable: .connectionRecoveryNeeded
        }
    }
}

// Never serialize NSError's description, userInfo, domain or numeric code.
enum SchedulerFailureReason: String {
    case unavailable, tooManyPendingRequests, notPermitted, immediateRunIneligible, unknown

    static func classify(_ error: Error) -> Self {
        let error = error as NSError
        guard error.domain == "BGTaskSchedulerErrorDomain" else { return .unknown }
        switch error.code {
        case 1: return .unavailable
        case 2: return .tooManyPendingRequests
        case 3: return .notPermitted
        case 4: return .immediateRunIneligible
        default: return .unknown
        }
    }

    var pairingGuidance: String {
        switch self {
        case .unavailable:
            "iOS background processing is unavailable. Check Background App Refresh for Roam Control in Settings, then try again."
        case .tooManyPendingRequests:
            "iOS has too many pending background tasks. Let other tasks finish, then return to Roam Control and try pairing again."
        case .notPermitted:
            "iOS did not permit the pairing background task. Copy Diagnostics from Connection Health so this installation can be checked."
        case .immediateRunIneligible:
            "iOS could not start pairing immediately under current system conditions. Keep Roam Control open and try again shortly."
        case .unknown:
            "iOS could not schedule pairing. Try again, and copy Diagnostics from Connection Health if it continues."
        }
    }
}

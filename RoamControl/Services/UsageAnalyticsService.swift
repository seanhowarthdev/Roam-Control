import CryptoKit
import Foundation

enum UsageAnalyticsEvent: String {
    case participationStarted = "RoamControl.Analytics.participationStarted"
    case appActivated = "RoamControl.App.activated"
    case onboardingCompleted = "RoamControl.Onboarding.completed"
    case pairingCompleted = "RoamControl.Pairing.completed"
    case fixedLocationStarted = "RoamControl.Location.fixedStarted"
    case walkingStarted = "RoamControl.Location.walkingStarted"
    case activeLocationUpdated = "RoamControl.Location.activeUpdated"
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
        completion: (@MainActor (Bool) -> Void)? = nil
    ) {
        let body = AnalyticsSignal(
            appID: configuration.appID,
            clientUser: anonymousClientIdentifier,
            type: event.rawValue,
            isTestMode: Self.isDebugBuild,
            payload: Self.safePayload
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

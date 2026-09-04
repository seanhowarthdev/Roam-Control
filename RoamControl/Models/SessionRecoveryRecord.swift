import Foundation

struct SessionRecoveryRecord: Codable, Equatable {
    enum Kind: String, Codable {
        case fixedLocation
        case walkingRoute
    }

    var kind: Kind
    var lastReportedLocation: LocationTarget
    var destination: LocationTarget?
    var walkingPaceMetresPerSecond: Double?
    let startedAt: Date
    var updatedAt: Date

    var isWalkingRoute: Bool {
        kind == .walkingRoute && destination != nil
    }

    static func fixed(at target: LocationTarget) -> SessionRecoveryRecord {
        SessionRecoveryRecord(
            kind: .fixedLocation,
            lastReportedLocation: target,
            destination: nil,
            walkingPaceMetresPerSecond: nil,
            startedAt: .now,
            updatedAt: .now
        )
    }

    static func walking(
        from start: LocationTarget,
        to destination: LocationTarget,
        paceMetresPerSecond: Double
    ) -> SessionRecoveryRecord {
        SessionRecoveryRecord(
            kind: .walkingRoute,
            lastReportedLocation: start,
            destination: destination,
            walkingPaceMetresPerSecond: paceMetresPerSecond,
            startedAt: .now,
            updatedAt: .now
        )
    }
}

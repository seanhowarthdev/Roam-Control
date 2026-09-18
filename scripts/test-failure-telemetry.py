#!/usr/bin/env python3
"""Run production preflight observers and disabled statistics hooks offline.

Extract bounded production bodies; replace platform/network boundaries with a
recording sender and a deliberately mismatched runtime bundle/plist fixture.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
analytics = (root / 'RoamControl/Services/UsageAnalyticsService.swift').read_text()
helper = (root / 'RoamControl/Services/BackgroundTaskIdentifier.swift').read_text()

def block(source, marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 0
    for i in range(opening, len(source)):
        if source[i] == '{': depth += 1
        elif source[i] == '}':
            depth -= 1
            if depth == 0: return source[start:i+1]
    raise AssertionError(marker)

fixture = '''
enum RuntimeFixture {
    static let bundleIdentifier: String? = "com.sean.roamcontrol.TESTSUFFIX"
    static func object(forInfoDictionaryKey: String) -> Any? {
        ["com.sean.roamcontrol.pairing.*", "com.sean.roamcontrol.location.*"]
    }
}
struct UIDevice { static let current = UIDevice(); let systemVersion = "27.0" }
'''
source = 'import Foundation\n' + fixture + helper
keep_alive = (root / 'RoamControl/Services/BackgroundLocationKeepAlive.swift').read_text()
source += keep_alive[keep_alive.index('struct BackgroundSessionTelemetry'):keep_alive.index('/// Receives')]
source += analytics[analytics.index('enum UsageAnalyticsEvent:'):analytics.index('/// Compatibility')]
source += analytics[analytics.index('struct FailureDiagnosticSnapshot'):]
source += """
final class Recorder {
    var rows: [[String: Any]] = []
    func recordFailure(_ snapshot: FailureDiagnosticSnapshot, context: FailureContext, enabled: Bool) {
        rows.append(["event_name": snapshot.disposition.event.rawValue])
        if snapshot.disposition == .recoverable && snapshot.isSchedulerFailure {
            rows.append(["event_name": UsageAnalyticsEvent.failureObserved.rawValue])
        }
    }
}
"""
for component, file in [('pairing','Pairing/OnDevicePairingCoordinator.swift'), ('location','Tunnel/LocalDeviceSessionCoordinator.swift')]:
    code = (root / 'RoamControl/Services' / file).read_text()
    phase = 'OnDevicePairingPhase' if component == 'pairing' else 'DeviceSessionPhase'
    source += f'enum {phase}: Equatable {{ case idle, preparing, connecting, failed(String) }}\n'
    source += f'final class {component.title()}Harness {{\n'
    source += block(code, '    private(set) var phase:') + '\n'
    source += '''
    var schedulerRegistrationAccepted = false
    var terminalFailureReported = false
    var lastFailureStage: FailureStage?
    var lastFailureDisposition: FailureDisposition?
    var schedulerFailureReason: SchedulerFailureReason?
    var taskConfigurationStatus: BackgroundTaskConfigurationStatus = .notChecked
    var taskRegistrationStatus: BackgroundTaskRegistrationStatus = .notAttempted
    var recordStore: Int? = 1
    var onRecoveryNeeded: ((FailureDiagnosticSnapshot) -> Void)?
    var onFailure: ((FailureDiagnosticSnapshot) -> Void)?
    var backgroundTelemetry = BackgroundSessionTelemetry(status: .idle, started: false, schedulerAvailable: false)
    var onBackgroundEvent: ((UsageAnalyticsEvent, BackgroundSessionTelemetry) -> Void)?
''' + f'    var onPhaseChange: (({phase}) -> Void)?\n'
    source += block(code, '    private func failureSnapshot(') + '\n'
    if component == 'location':
        source += block(code, '    private func reportSchedulerObservationFailure()') + '\n'
    start = code.index(f'        taskConfigurationStatus = BackgroundTaskIdentifier.configurationStatus(for: "{component}")')
    end = code.index('        let identifier =', start) if component == 'location' else code.index('        // Pairing must not depend', start)
    source += '    func preflight() {\n        phase = .preparing\n        terminalFailureReported = false\n' + code[start:end] + ('\n        _ = prefix\n' if component == 'location' else '\n') + '    }\n'
    source += '    func fail(_ message: String) { phase = .failed(message) }\n}\n'
    expected_count = 2 if component == 'location' else 0
    expected_event = 'RoamControl.Failure.Observed' if component == 'pairing' else 'RoamControl.Connection.RecoveryNeeded'
    expected_disposition = 'terminal' if component == 'pairing' else 'recoverable'
    callback = 'onFailure' if component == 'pairing' else 'onRecoveryNeeded'
    source += (f'''
do {{
    let coordinator = {component.title()}Harness()
    let recorder = Recorder()
    var captured: FailureDiagnosticSnapshot?
    coordinator.{callback} = {{ snapshot in
        captured = snapshot
        recorder.recordFailure(snapshot, context: .{component}, enabled: true)
    }}
    coordinator.preflight()
    precondition(recorder.rows.count == {expected_count})
    let row = recorder.rows[0]
    precondition(row["event_name"] as? String == "{expected_event}")
    precondition(captured?.stage == .schedulerRegistration)
    precondition(captured?.disposition == .{expected_disposition})
    precondition(captured?.taskConfigurationStatus == .runtimeIdentifierNotPermitted)
    precondition(captured?.taskRegistrationStatus == .notAttempted)
    precondition(captured?.runtimeBundleIdentifier == RuntimeFixture.bundleIdentifier)
    precondition(captured?.permittedBackgroundTasks == RuntimeFixture.object(forInfoDictionaryKey: "") as? [String])
    coordinator.taskConfigurationStatus = .permitted
    coordinator.taskRegistrationStatus = .accepted
    precondition(captured?.taskConfigurationStatus == .runtimeIdentifierNotPermitted)
    precondition(captured?.taskRegistrationStatus == .notAttempted)
}}
''' if component == 'location' else '')
source += analytics[analytics.index('/// Compatibility'):analytics.index('// Captured before callbacks')]
source += """
@MainActor func checkDisabledStatistics() {
        let name = "RoamControl.DisabledStatistics.Test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("old-id", forKey: "anonymousUsageIdentifier")
        defaults.set(true, forKey: "sharesAnonymousUsageStatistics")
        defaults.set(true, forKey: "hasReportedAnalyticsParticipation")
        defaults.set("keep", forKey: "unrelatedPreference")
        let service = UsageAnalyticsService(preferences: defaults)
        for enabled in [false, true] {
            service.recordActivation(enabled: enabled)
            service.record(.pairingCompleted, enabled: enabled)
            service.recordFailure(.pairingEngine, context: .pairing, enabled: enabled)
            service.recordFailure(FailureDiagnosticSnapshot(stage: .schedulerRegistration), context: .location, enabled: enabled)
        }
        precondition(defaults.object(forKey: "anonymousUsageIdentifier") == nil)
        precondition(defaults.object(forKey: "sharesAnonymousUsageStatistics") == nil)
        precondition(defaults.object(forKey: "hasReportedAnalyticsParticipation") == nil)
        precondition(defaults.string(forKey: "unrelatedPreference") == "keep")
        print("Disabled statistics and identity cleanup checks passed")
}
MainActor.assumeIsolated { checkDisabledStatistics() }
"""
source = source.replace('Bundle.main', 'RuntimeFixture')
with tempfile.TemporaryDirectory() as temp:
    path = Path(temp) / 'main.swift'
    path.write_text(source)
    binary = Path(temp) / 'check'
    subprocess.run(['xcrun','swiftc','-module-cache-path',str(Path(temp)/'cache'),str(path),'-o',str(binary)], check=True)
    subprocess.run([str(binary)], check=True)

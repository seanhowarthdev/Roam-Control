#!/usr/bin/env python3
"""Execute production keep-alive and scheduler methods with offline platform fakes."""
from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[1]
keep = (root/'RoamControl/Services/BackgroundLocationKeepAlive.swift').read_text()
keep = keep.replace('import CoreLocation', '').replace('import Observation', '').replace('@Observable', '').replace('@preconcurrency ', '')
coordinator = (root/'RoamControl/Services/Tunnel/LocalDeviceSessionCoordinator.swift').read_text()
helper = (root/'RoamControl/Services/BackgroundTaskIdentifier.swift').read_text()
def block(source, marker):
    start = source.index(marker); opening = source.index('{', start); depth = 0
    for i in range(opening, len(source)):
        depth += (source[i] == '{') - (source[i] == '}')
        if depth == 0: return source[start:i+1]
    raise AssertionError(marker)
fakes = '''
import Foundation
let kCLLocationAccuracyKilometer = 1000.0
let kCLDistanceFilterNone = -1.0
enum CLAuthorizationStatus { case notDetermined, denied, restricted, authorizedAlways, authorizedWhenInUse }
struct CLLocation {}
struct CLError: Error { enum Code { case locationUnknown, denied, other }; let code: Code }
protocol CLLocationManagerDelegate: AnyObject {}
final class CLLocationManager {
    weak var delegate: (any CLLocationManagerDelegate)?
    var desiredAccuracy = 0.0, distanceFilter = 0.0
    var pausesLocationUpdatesAutomatically = true, showsBackgroundLocationIndicator = false
    var allowsBackgroundLocationUpdates = false
    var authorizationStatus = CLAuthorizationStatus.notDetermined
    static var enabled = true
    static func locationServicesEnabled() -> Bool { enabled }
    var starts = 0, stops = 0, requests = 0
    func startUpdatingLocation() { starts += 1 }
    func stopUpdatingLocation() { stops += 1 }
    func requestWhenInUseAuthorization() { requests += 1 }
}
enum RuntimeFixture {
    static var bundleIdentifier: String? = "com.catgo.app.9THCBUH63A"
    static var permitted = ["com.catgo.app.location.*"]
    static func object(forInfoDictionaryKey: String) -> Any? { permitted }
}
final class FakeTask { func setTaskCompleted(success: Bool) {} }
final class BGTaskScheduler {
    static let shared = BGTaskScheduler()
    var accepts = true, registrations = 0
    var callback: ((FakeTask) -> Void)?
    func register(forTaskWithIdentifier: String, using: DispatchQueue, launchHandler: @escaping (FakeTask) -> Void) -> Bool {
        registrations += 1; callback = launchHandler; return accepts
    }
}
enum UsageAnalyticsEvent { case backgroundSchedulerObserved }
enum Phase { case idle, connecting }
'''
harness = '''
final class SessionHarness {
    var pendingSession: Int? = 1, resolvedService: Int? = 1
    var phase = Phase.idle
    var taskConfigurationStatus = BackgroundTaskConfigurationStatus.notChecked
    var taskRegistrationStatus = BackgroundTaskRegistrationStatus.notAttempted
    var schedulerRegistrationAccepted = false
    var backgroundTelemetry = 0
    var onBackgroundEvent: ((UsageAnalyticsEvent, Int) -> Void)?
    var workers = 0, failures = 0, observedFailures = 0
    func runNativeLocationSession() { workers += 1 }
    func fail(_ message: String) { failures += 1 }
    func reportSchedulerObservationFailure() { observedFailures += 1 }
'''
for name in ['submitLocationTask', 'observeLocationScheduler']:
    harness += block(coordinator, '    private func '+name+'()').replace('private func', 'func')+'\n'
harness += '}\n'
checks = '''
@main struct Tests {
    @MainActor static func main() {
        let m = CLLocationManager()
        let k = BackgroundLocationKeepAlive(manager: m, hasBackgroundMode: true)
        var events = 0
        k.onChange = { events += 1 }
        k.start(); k.start()
        precondition(m.requests == 1 && m.starts == 0 && k.status == .awaitingAuthorization)
        k.stop()
        m.authorizationStatus = .authorizedWhenInUse
        k.locationManagerDidChangeAuthorization(m)
        k.locationManager(m, didUpdateLocations: [CLLocation()])
        precondition(m.starts == 0 && k.status == .stopped)
        k.start(); k.start()
        precondition(m.starts == 1 && k.started && k.status == .starting)
        precondition(m.allowsBackgroundLocationUpdates && !m.pausesLocationUpdatesAutomatically)
        k.locationManager(m, didUpdateLocations: [CLLocation()])
        precondition(k.status == .receivingUpdates)
        let before = events
        k.locationManager(m, didUpdateLocations: [CLLocation()])
        precondition(events == before)
        k.locationManager(m, didFailWithError: CLError(code: .locationUnknown))
        precondition(k.started && k.status == .locationUnavailable)
        k.locationManager(m, didUpdateLocations: [CLLocation()])
        precondition(k.status == .receivingUpdates)
        m.authorizationStatus = .denied
        k.locationManagerDidChangeAuthorization(m)
        precondition(!k.started && k.status == .denied && !m.allowsBackgroundLocationUpdates)
        m.authorizationStatus = .authorizedAlways
        k.locationManagerDidChangeAuthorization(m)
        precondition(k.started && m.starts == 2)
        k.locationManager(m, didFailWithError: CLError(code: .other))
        precondition(!k.started && k.status == .failed)
        k.stop(); let stopped = events; k.stop()
        k.locationManager(m, didFailWithError: CLError(code: .denied))
        k.locationManager(m, didUpdateLocations: [CLLocation()])
        precondition(events == stopped && k.status == .stopped)
        for auth: CLAuthorizationStatus in [.denied, .restricted] {
            let manager = CLLocationManager(); manager.authorizationStatus = auth
            let keep = BackgroundLocationKeepAlive(manager: manager, hasBackgroundMode: true)
            keep.start(); precondition(!keep.started && manager.starts == 0)
        }
        CLLocationManager.enabled = false; m.authorizationStatus = .denied
        k.start(); precondition(k.status == .servicesDisabled); k.stop()
        let missing = BackgroundLocationKeepAlive(manager: m, hasBackgroundMode: false)
        missing.start(); precondition(missing.status == .missingBackgroundMode && !missing.started)

        let session = SessionHarness()
        session.submitLocationTask()
        precondition(session.workers == 1 && session.failures == 0 && session.observedFailures == 1)
        precondition(session.taskConfigurationStatus == .runtimeIdentifierNotPermitted)
        precondition(session.taskRegistrationStatus == .notAttempted && BGTaskScheduler.shared.registrations == 0)
        RuntimeFixture.permitted = ["com.catgo.app.9THCBUH63A.location.*"]
        BGTaskScheduler.shared.accepts = false
        session.submitLocationTask()
        precondition(session.workers == 2 && session.failures == 0 && session.observedFailures == 2)
        precondition(session.taskRegistrationStatus == .rejected)
        BGTaskScheduler.shared.accepts = true
        session.submitLocationTask(); session.submitLocationTask()
        precondition(session.workers == 4 && session.taskRegistrationStatus == .accepted)
        precondition(BGTaskScheduler.shared.registrations == 2)
        BGTaskScheduler.shared.callback?(FakeTask())
        precondition(session.workers == 4 && session.failures == 0)
        session.resolvedService = nil; session.submitLocationTask()
        precondition(session.workers == 4 && session.failures == 1)
        print("Keep-alive permissions, delivery, errors, stop/restart, late callbacks and scheduler independence passed")
    }
}
'''
source = fakes + keep + helper.replace('Bundle.main', 'RuntimeFixture') + harness + checks
with tempfile.TemporaryDirectory() as temp:
    path = Path(temp)/'tests.swift'; path.write_text(source)
    binary = Path(temp)/'tests'
    subprocess.run(['xcrun','swiftc','-parse-as-library','-module-cache-path',str(Path(temp)/'cache'),str(path),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
# Lifecycle wiring; the native engine and walking implementation are not replaced by fakes here.
assert 'backgroundKeepAlive.start()' in block(coordinator,'    fileprivate func nativeLocationStarted()')
for marker in ['    func stop()', '    private func nativeLocationFinished(', '    private func fail(', '    private func clearPendingSession()']:
    assert 'backgroundKeepAlive.stop()' in block(coordinator,marker)
assert 'submitTaskRequest' not in coordinator
print('Native-session keep-alive lifecycle wiring passed')

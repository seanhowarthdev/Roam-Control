#!/usr/bin/env python3
"""Execute walking startup/state methods with a simulated device session."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'RoamControl/Features/Map/WalkingSimulationController.swift').read_text()
def method(signature):
    start = source.index(signature)
    opening = source.index('{', start)
    depth = 0
    for index in range(opening, len(source)):
        depth += (source[index] == '{') - (source[index] == '}')
        if depth == 0:
            return source[start:index + 1].replace('private func', 'func')
    raise AssertionError(signature)
swift = r'''
import Foundation
enum WalkingSimulationPhase: Equatable {
 case idle, preparing, walking, paused, arrived, stopping, failed(String)
}
enum DeviceSessionPhase { case idle, openingLocalDevVPN, discovering, connecting, active, stopping, failed(String) }
enum PairingStatus { case paired, notPaired }
struct Point { var coordinate = 1 }
struct Pace { var metresPerSecond = 1.4 }
@MainActor final class LocalDeviceSessionCoordinator {
 var phase: DeviceSessionPhase = .idle
 var stops = 0
 func stop() { stops += 1; phase = .idle }
}
@MainActor final class AppModel {
 var pairingStatus: PairingStatus = .paired
 let deviceSession = LocalDeviceSessionCoordinator()
 var completes = true
 var fail = false
 var suspended = false
 func startWalkingLocationSession(at: Int, destination: Int, paceMetresPerSecond: Double) async {
  while suspended && !Task.isCancelled { await Task.yield() }
  guard !Task.isCancelled else { return }
  if fail { deviceSession.phase = .failed("connection failed") }
  else if completes { deviceSession.phase = .active }
  else { deviceSession.phase = .discovering }
 }
}
@MainActor final class WalkingSimulationController {
 var phase: WalkingSimulationPhase = .idle
 var routePoints = [Point(), Point()]
 var destination: Int? = 2
 var movementTask: Task<Void, Never>?
 var startupTimeoutTask: Task<Void, Never>?
 var startupRequestTask: Task<Void, Never>?
 var currentCoordinate: Int?
 var distanceTravelled = 0
 var pace = Pace()
 var movements = 0
 var isFailed: Bool { if case .failed = phase { return true }; return false }
 var locksDestination: Bool { phase != .idle && !isFailed }
 func movementTarget(at coordinate: Int, destination: Int) -> Int { coordinate }
 func beginMovement(using: LocalDeviceSessionCoordinator) { movements += 1 }
'''
swift += method('func start(using: AppModel)') if 'func start(using: AppModel)' in source else method('func start(using appModel: AppModel)')
swift += '\n' + method('func handleDeviceSessionPhase(')
swift += '\n' + method('func stop(using deviceSession:')
# The deadline callback is executed separately; no minute-long test sleeps.
if 'private func failStartupIfStillPreparing(' in source:
    swift += '\n' + method('private func failStartupIfStillPreparing(')
swift += r'''
}
@main struct Checks {
 @MainActor static func main() async {
  let app = AppModel(), walk = WalkingSimulationController()
  app.deviceSession.phase = .active
  await walk.start(using: app)
  precondition(walk.phase == .walking && walk.movements == 1,
    "Existing active connection must start walking without a new phase notification")
  walk.handleDeviceSessionPhase(.active, deviceSession: app.deviceSession)
  precondition(walk.movements == 1, "Duplicate notifications must not restart movement")
  let cancelledApp = AppModel(), cancelledWalk = WalkingSimulationController()
  cancelledApp.suspended = true
  let starting = Task { await cancelledWalk.start(using: cancelledApp) }
  while cancelledWalk.startupRequestTask == nil { await Task.yield() }
  cancelledWalk.stop(using: cancelledApp.deviceSession)
  cancelledApp.suspended = false
  await starting.value
  precondition(cancelledWalk.phase == .idle && cancelledWalk.movements == 0,
    "Cancelled startup must not begin movement when its async request completes")
  let pending = WalkingSimulationController()
  pending.phase = .preparing
  pending.handleDeviceSessionPhase(.idle, deviceSession: app.deviceSession)
  precondition(pending.isFailed, "Aborted startup must end loading")
  let failedApp = AppModel(), failedWalk = WalkingSimulationController()
  failedApp.fail = true
  await failedWalk.start(using: failedApp)
  precondition(failedWalk.phase == .failed("connection failed"), "Startup failure must be synchronized")
'''
if 'private func failStartupIfStillPreparing(' in source:
    swift += r'''
  let waitingApp = AppModel(), waiting = WalkingSimulationController()
  waitingApp.completes = false
  await waiting.start(using: waitingApp)
  precondition(waiting.phase == .preparing)
  waiting.failStartupIfStillPreparing(using: waitingApp.deviceSession)
  precondition(waiting.isFailed && waitingApp.deviceSession.stops == 1, "Timeout must cancel pending connection")
  walk.failStartupIfStillPreparing(using: app.deviceSession)
  precondition(walk.phase == .walking && app.deviceSession.stops == 0, "Old timeout must never stop an active walk")
'''
swift += r'''
  print("Walking active-session reuse, duplicate events, failed and aborted startup passed")
 }
}
'''
with tempfile.TemporaryDirectory(prefix='catgo-walk-reuse-') as directory:
    path = Path(directory) / 'Checks.swift'
    path.write_text(swift)
    executable = Path(directory) / 'checks'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(path), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)

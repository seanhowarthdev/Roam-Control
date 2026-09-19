#!/usr/bin/env python3
"""Exercise the production VPN startup routing with simulated VPN and app services."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "RoamControl/Services/Tunnel/LocalDeviceSessionCoordinator.swift").read_text()


def body(signature):
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        depth += (source[index] == "{") - (source[index] == "}")
        if depth == 0:
            return source[start:index + 1].replace("private func", "func")
    raise AssertionError(signature)


# Before the fix, cellular startup always opens the external application.
assert "connectEmbeddedVPNForPendingSession" in source, "Built-in VPN is not routed into cellular startup"

swift = r'''
import Foundation
enum Phase: Equatable { case discovering, openingLocalDevVPN, idle, failed }
enum Status { case invalid, disconnected, connected, connecting, reasserting, disconnecting }
@MainActor final class EmbeddedVPNService {
    static var shared = EmbeddedVPNService()
    var status: Status = .invalid
    var isUpdating = false
    var isTransitioning: Bool { isUpdating || status == .connecting || status == .reasserting || status == .disconnecting }
    var errorMessage: String? = "VPN permission denied"
    var connects = 0
    var succeeds = true
    var suspended = false
    func refresh() async {}
    func connect() async {
        connects += 1
        while suspended && !Task.isCancelled { await Task.yield() }
        if succeeds && !Task.isCancelled { status = .connected; errorMessage = nil }
    }
}
@MainActor final class UIApplication {
    static let shared = UIApplication()
    var externalInstalled = false
    var opens = 0
    func open(_ url: URL, options: [String: String]) async -> Bool {
        opens += 1
        return externalInstalled
    }
    func open(_ url: URL, completionHandler: @escaping (Bool) -> Void) {
        opens += 1
        completionHandler(externalInstalled)
    }
}
@MainActor final class Coordinator {
    static let enableURL = URL(string: "localdevvpn://enable")!
    var pendingSession: Int? = 1
    var workerIsRunning = false
    var phase: Phase = .discovering
    var mobileDataGuidance: Int?
    var hasRequestedLocalDevVPNThisAttempt = false
    var isMobileDataStartupMode = true
    var embeddedVPNStartupTask: Task<Void, Never>?
    var sessionAttemptIdentifier = UUID()
    var guidanceCount = 0
    var discoveryCount = 0
    var failure: String?
    func cleanupDiscovery() {}
    func enterMobileDataGuidance() { guidanceCount += 1; phase = .discovering }
    func beginDiscovery(showConnectionHelpIfUnavailable: Bool) { discoveryCount += 1; phase = .discovering }
    func fail(_ message: String) { failure = message; phase = .failed }
'''
swift += body("private func openLocalDevVPNForPendingSession()") + "\n"
swift += body("private func connectEmbeddedVPNForPendingSession(")
swift += "\n" + body("func openLocalDevVPN()")
swift += r'''
}
@main struct Checks {
    @MainActor static func main() async {
        func reset() {
            EmbeddedVPNService.shared = EmbeddedVPNService()
            UIApplication.shared.externalInstalled = false
            UIApplication.shared.opens = 0
        }
        func settle(_ coordinator: Coordinator) async {
            await coordinator.embeddedVPNStartupTask?.value
        }
        reset()
        let standalone = Coordinator()
        standalone.pendingSession = nil
        standalone.openLocalDevVPN()
        for _ in 0..<1000 {
            if EmbeddedVPNService.shared.status == .connected || standalone.failure != nil { break }
            await Task.yield()
        }
        precondition(standalone.failure == nil && EmbeddedVPNService.shared.status == .connected,
                     "Standalone connect must use the built-in VPN without requiring LocalDevVPN")
        precondition(UIApplication.shared.opens == 0)
        reset()
        EmbeddedVPNService.shared.succeeds = false
        let standaloneDenied = Coordinator()
        standaloneDenied.pendingSession = nil
        standaloneDenied.openLocalDevVPN()
        for _ in 0..<1000 {
            if standaloneDenied.failure != nil { break }
            await Task.yield()
        }
        precondition(standaloneDenied.failure == "VPN permission denied" && UIApplication.shared.opens == 0)
        reset()
        let cellular = Coordinator()
        cellular.openLocalDevVPNForPendingSession()
        await settle(cellular)
        precondition(cellular.discoveryCount == 0 && cellular.guidanceCount == 1 && UIApplication.shared.opens == 0)
        precondition(EmbeddedVPNService.shared.connects == 1)
        reset()
        let missingSession = Coordinator()
        missingSession.pendingSession = nil
        missingSession.openLocalDevVPNForPendingSession()
        await settle(missingSession)
        precondition(EmbeddedVPNService.shared.connects == 0 && missingSession.guidanceCount == 0)
        reset()
        EmbeddedVPNService.shared.status = .connected
        UIApplication.shared.externalInstalled = true
        let connected = Coordinator()
        connected.openLocalDevVPNForPendingSession()
        await settle(connected)
        precondition(connected.discoveryCount == 0 && connected.guidanceCount == 1 && EmbeddedVPNService.shared.connects == 0)
        precondition(UIApplication.shared.opens == 0)
        reset()
        EmbeddedVPNService.shared.status = .connecting
        let transitioning = Coordinator()
        transitioning.openLocalDevVPNForPendingSession()
        Task { @MainActor in
            await Task.yield()
            EmbeddedVPNService.shared.status = .connected
        }
        await settle(transitioning)
        precondition(transitioning.discoveryCount == 0 && transitioning.guidanceCount == 1 && EmbeddedVPNService.shared.connects == 0)
        reset()
        UIApplication.shared.externalInstalled = true
        let external = Coordinator()
        external.openLocalDevVPNForPendingSession()
        await settle(external)
        precondition(UIApplication.shared.opens == 0 && EmbeddedVPNService.shared.connects == 1)
        precondition(external.discoveryCount == 0 && external.guidanceCount == 1)
        reset()
        EmbeddedVPNService.shared.status = .disconnected
        UIApplication.shared.externalInstalled = true
        let configured = Coordinator()
        configured.openLocalDevVPNForPendingSession()
        await settle(configured)
        precondition(configured.discoveryCount == 0 && configured.guidanceCount == 1 && UIApplication.shared.opens == 0)
        reset()
        let wifi = Coordinator()
        wifi.isMobileDataStartupMode = false
        wifi.openLocalDevVPNForPendingSession()
        await settle(wifi)
        precondition(wifi.discoveryCount == 1 && wifi.guidanceCount == 0)
        reset()
        EmbeddedVPNService.shared.succeeds = false
        EmbeddedVPNService.shared.status = .disconnected
        UIApplication.shared.externalInstalled = true
        let denied = Coordinator()
        denied.openLocalDevVPNForPendingSession()
        await settle(denied)
        precondition(denied.failure != nil && denied.guidanceCount == 0 && UIApplication.shared.opens == 0)
        reset()
        EmbeddedVPNService.shared.suspended = true
        let cancelled = Coordinator()
        cancelled.openLocalDevVPNForPendingSession()
        let oldTask = cancelled.embeddedVPNStartupTask
        while EmbeddedVPNService.shared.connects == 0 { await Task.yield() }
        cancelled.sessionAttemptIdentifier = UUID()
        cancelled.pendingSession = nil
        cancelled.phase = .idle
        oldTask?.cancel()
        await oldTask?.value
        precondition(cancelled.phase == .idle && cancelled.guidanceCount == 0 && cancelled.failure == nil)
        reset()
        EmbeddedVPNService.shared.suspended = true
        let restarted = Coordinator()
        restarted.openLocalDevVPNForPendingSession()
        let staleTask = restarted.embeddedVPNStartupTask
        while EmbeddedVPNService.shared.connects == 0 { await Task.yield() }
        staleTask?.cancel()
        restarted.sessionAttemptIdentifier = UUID()
        restarted.embeddedVPNStartupTask = nil
        restarted.openLocalDevVPNForPendingSession()
        let newTask = restarted.embeddedVPNStartupTask
        await staleTask?.value
        precondition(restarted.embeddedVPNStartupTask != nil)
        EmbeddedVPNService.shared.suspended = false
        await newTask?.value
        precondition(restarted.discoveryCount == 0 && restarted.guidanceCount == 1 && restarted.failure == nil)
        reset()
        EmbeddedVPNService.shared.suspended = true
        let duplicate = Coordinator()
        duplicate.openLocalDevVPNForPendingSession()
        duplicate.openLocalDevVPNForPendingSession()
        while EmbeddedVPNService.shared.connects == 0 { await Task.yield() }
        EmbeddedVPNService.shared.suspended = false
        await settle(duplicate)
        precondition(EmbeddedVPNService.shared.connects == 1 && duplicate.discoveryCount == 0 && duplicate.guidanceCount == 1)
        print("Embedded VPN standalone/cellular/Wi-Fi routing, no external dependency, denial, cancellation and duplicate startup passed")
    }
}
'''
assert "embeddedVPNStartupTask == nil" in body("func appDidBecomeActive()")
assert "embeddedVPNStartupTask?.cancel()" in body("private func clearPendingSession()")
assert "mobileDataGuidance = .turnBackOn" in body("fileprivate func nativeLocationStarted()")
with tempfile.TemporaryDirectory(prefix="roam-vpn-startup-") as directory:
    path = Path(directory) / "checks.swift"
    path.write_text(swift)
    executable = Path(directory) / "checks"
    subprocess.run(["swiftc", "-parse-as-library", str(path), "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)

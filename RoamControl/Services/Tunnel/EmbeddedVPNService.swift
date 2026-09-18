import Foundation
import NetworkExtension
import Observation

/// Manages only the extension bundled with Roam Control.
@MainActor
@Observable
final class EmbeddedVPNService {
    static let shared = EmbeddedVPNService()

    private(set) var status: NEVPNStatus = .invalid
    private(set) var isUpdating = false
    private(set) var errorMessage: String?
    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    private var providerIdentifier: String {
        (Bundle.main.bundleIdentifier ?? "com.sean.roamcontrol") + ".RoamTunnel"
    }

    var statusText: String {
        switch status {
        case .invalid: "Not configured"
        case .disconnected: "Disconnected"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .reasserting: "Reconnecting"
        case .disconnecting: "Disconnecting"
        @unknown default: "Unknown"
        }
    }

    var isTransitioning: Bool {
        isUpdating || status == .connecting || status == .disconnecting || status == .reasserting
    }

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { [weak self] notification in
            guard let connection = notification.object as? NEVPNConnection else { return }
            MainActor.assumeIsolated {
                guard let self, connection === self.manager?.connection else { return }
                self.status = connection.status
            }
        }
    }

    func refresh() async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            manager = try await loadManager()
            status = manager?.connection.status ?? .invalid
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connect() async {
        guard !isTransitioning else { return }
        errorMessage = nil
#if targetEnvironment(simulator)
        errorMessage = "A physical iPhone is required to start the built-in VPN."
#else
        isUpdating = true
        defer { isUpdating = false }
        var startedConnection: NEVPNConnection?
        do {
            let configuration = try await loadManager() ?? NETunnelProviderManager()
            try Task.checkCancellation()
            manager = configuration
            status = configuration.connection.status
            guard status != .connected, status != .connecting, status != .reasserting else { return }
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = providerIdentifier
            proto.serverAddress = "Cat Go Device Connection"
            proto.providerConfiguration = [
                TunnelConstants.ifaceIPConfigurationKey: TunnelConstants.defaultIfaceIP,
                TunnelConstants.peerIPConfigurationKey: TunnelConstants.defaultPeerIP,
            ]
            configuration.protocolConfiguration = proto
            configuration.localizedDescription = "Cat Go"
            configuration.isEnabled = true
            // Manual activation avoids starting a VPN unexpectedly on unrelated network changes.
            configuration.isOnDemandEnabled = false
            try await configuration.saveToPreferences()
            try await configuration.loadFromPreferences()
            try Task.checkCancellation()
            try configuration.connection.startVPNTunnel()
            startedConnection = configuration.connection
            status = configuration.connection.status
            // Bound startup without relying on an app-switch callback.
            for _ in 0..<150 {
                try await Task.sleep(for: .milliseconds(200))
                status = configuration.connection.status
                if status == .connected { return }
                if status == .disconnected || status == .invalid {
                    throw VPNError.startFailed
                }
            }
            configuration.connection.stopVPNTunnel()
            throw VPNError.startTimedOut
        } catch {
            if error is CancellationError {
                startedConnection?.stopVPNTunnel()
            }
            status = manager?.connection.status ?? .invalid
            errorMessage = error.localizedDescription
        }
#endif
    }

    func disconnect() {
        guard !isUpdating else { return }
        errorMessage = nil
        manager?.connection.stopVPNTunnel()
        status = manager?.connection.status ?? .invalid
    }

    private func loadManager() async throws -> NETunnelProviderManager? {
        let configurations = try await NETunnelProviderManager.loadAllFromPreferences()
        let own = configurations.filter {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerIdentifier
        }
        return own.first { $0.connection.status == .connected || $0.connection.status == .connecting }
            ?? own.first
    }

    private enum VPNError: LocalizedError {
        case startFailed, startTimedOut
        var errorDescription: String? {
            switch self {
            case .startFailed: "The built-in VPN could not connect. Check the app and extension signing capabilities, then try again."
            case .startTimedOut: "The built-in VPN did not connect within 30 seconds. Try again."
            }
        }
    }
}

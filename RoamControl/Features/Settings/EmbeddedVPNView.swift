import SwiftUI
import NetworkExtension

struct EmbeddedVPNView: View {
    @Environment(\.locale) private var locale
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var vpn = EmbeddedVPNService.shared
    @State private var diagnostics = ConnectionDiagnosticsCoordinator()
    @State private var isChecking = false
    @State private var checkError: String?
    @State private var isVisible = false

    private var canChangeTunnel: Bool {
        switch appModel.deviceSession.phase {
        case .idle, .failed: true
        default: false
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(AppLocalization.text("Status", locale: locale), value: AppLocalization.text(vpn.statusText, locale: locale))
                LabeledContent(AppLocalization.text("Interface", locale: locale), value: TunnelConstants.defaultIfaceIP)
                LabeledContent(AppLocalization.text("Peer", locale: locale), value: TunnelConstants.defaultPeerIP)
                Button(AppLocalization.text(vpn.status == .connected ? "Disconnect" : "Connect", locale: locale)) {
                    diagnostics.cancel()
                    if vpn.status == .connected {
                        vpn.disconnect()
                    } else {
                        Task { await vpn.connect() }
                    }
                }
                .disabled(vpn.isTransitioning || !canChangeTunnel)
                if let error = vpn.errorMessage {
                    Text(AppLocalization.text(error, locale: locale)).foregroundStyle(.red)
                }
            } footer: {
                Text(AppLocalization.text("Connect here, then return to the map to start a location session. Stop the location session before disconnecting. The first connection asks for permission to add a VPN configuration.", locale: locale))
            }

            Section {
                Button(AppLocalization.text("Check This iPhone Connection", locale: locale)) {
                    isChecking = true
                    checkError = nil
                    Task {
                        defer { isChecking = false }
                        do {
                            let record = try await appModel.pairingService.pairingRecordData()
                            guard isVisible, vpn.status == .connected, canChangeTunnel else { return }
                            diagnostics.run(pairingRecord: record, sessionPhase: appModel.deviceSession.phase)
                        } catch {
                            checkError = error.localizedDescription
                        }
                    }
                }
                .disabled(vpn.status != .connected || vpn.isTransitioning || isChecking || diagnostics.state == .running || !canChangeTunnel)
                if let checkError { Text(AppLocalization.text(checkError, locale: locale)).foregroundStyle(.red) }
                switch diagnostics.state {
                case .notRun: EmptyView()
                case .running: ProgressView(AppLocalization.text("Checking…", locale: locale))
                case .passed(let message): Label(AppLocalization.text(message, locale: locale), systemImage: "checkmark.circle").foregroundStyle(.green)
                case .failed(let message): Text(AppLocalization.text(message, locale: locale)).foregroundStyle(.red)
                }
            } footer: {
                Text(AppLocalization.text("Checks the paired iPhone's developer service through the local tunnel. A connected VPN alone does not confirm that the device service is reachable. On mobile data, the existing connection guidance may still be needed.", locale: locale))
            }


        }
        .navigationTitle(AppLocalization.text("Built-in Local VPN", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .task { await vpn.refresh() }
        .onAppear { isVisible = true }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vpn.refresh() } }
        }
        .onChange(of: vpn.status) { _, status in
            if status != .connected { diagnostics.cancel() }
        }
        .onDisappear {
            isVisible = false
            diagnostics.cancel()
        }
    }

}

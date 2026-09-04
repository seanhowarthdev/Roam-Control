import SwiftUI

struct ConnectionHealthView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var diagnostics = ConnectionDiagnosticsCoordinator()
    @State private var isShowingDeviceSetup = false

    var body: some View {
        List {
            Section("Connection Health") {
                healthRow(
                    title: "Pairing",
                    value: pairingValue,
                    symbol: pairingSymbol,
                    color: pairingColor
                )

                healthRow(
                    title: "LocalDevVPN",
                    value: localDevVPNValue,
                    symbol: localDevVPNSymbol,
                    color: localDevVPNColor
                )

                healthRow(
                    title: "Location Session",
                    value: sessionValue,
                    symbol: sessionSymbol,
                    color: sessionColor
                )
            }

            Section("Current Location") {
                LabeledContent("Place", value: activeTarget?.name ?? "None")
                LabeledContent("Coordinates", value: coordinatesValue)

                if let activeTarget, !activeTarget.subtitle.isEmpty {
                    LabeledContent("Area", value: activeTarget.subtitle)
                }
            }

            Section {
                Button {
                    Task { await runConnectionCheck() }
                } label: {
                    HStack {
                        Label("Run Connection Check", systemImage: "stethoscope")
                        Spacer()
                        if diagnostics.state == .running {
                            ProgressView()
                        }
                    }
                }
                .disabled(diagnostics.state == .running)

                if let resultMessage {
                    Label(resultMessage, systemImage: resultSymbol)
                        .font(.subheadline)
                        .foregroundStyle(resultColor)
                }

                if let lastChecked = diagnostics.lastChecked {
                    LabeledContent(
                        "Last checked",
                        value: lastChecked.formatted(date: .omitted, time: .shortened)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Connection Check")
            } footer: {
                Text("This checks the saved pairing record and whether the paired iPhone is visible through LocalDevVPN. It never starts, changes, or stops your location.")
            }

            Section {
                ShareLink(
                    item: diagnosticsText,
                    subject: Text("Roam Control Diagnostics")
                ) {
                    Label("Share Diagnostics", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Choose where to send or save the report using the iOS share sheet. It never includes pairing keys or PINs.")
            }

            Section("Help") {
                Button {
                    isShowingDeviceSetup = true
                } label: {
                    Label("Pairing & Connection", systemImage: "iphone.and.arrow.forward")
                }
                .foregroundStyle(.primary)

                Link(destination: appModel.localDevVPNInstallURL) {
                    Label("Open LocalDevVPN in App Store", systemImage: "arrow.up.right.square")
                }
            }
        }
        .navigationTitle("Connection Health")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            diagnostics.cancel()
        }
        .sheet(isPresented: $isShowingDeviceSetup) {
            PairingSetupView()
                .environment(appModel)
        }
    }

    private var activeTarget: LocationTarget? {
        if case .active(let target) = appModel.deviceSession.phase {
            return target
        }
        return nil
    }

    private var coordinatesValue: String {
        guard let activeTarget else { return "None" }
        return String(format: "%.5f, %.5f", activeTarget.latitude, activeTarget.longitude)
    }

    private var pairingValue: String {
        switch appModel.pairingStatus {
        case .checking: "Checking"
        case .importing: "Importing"
        case .notPaired: "Not paired"
        case .paired: "Ready"
        case .failed: "Problem"
        }
    }

    private var pairingSymbol: String {
        switch appModel.pairingStatus {
        case .checking, .importing: "arrow.triangle.2.circlepath"
        case .notPaired: "exclamationmark.circle"
        case .paired: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private var pairingColor: Color {
        switch appModel.pairingStatus {
        case .checking, .importing: .blue
        case .notPaired: .orange
        case .paired: .green
        case .failed: .red
        }
    }

    private var localDevVPNValue: String {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return "Connected" }
            return "Not checked"
        case .running: return "Checking"
        case .passed: return "Reachable"
        case .failed: return "Not reachable"
        }
    }

    private var localDevVPNSymbol: String {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return "checkmark.circle.fill" }
            return "questionmark.circle"
        case .running: return "arrow.triangle.2.circlepath"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var localDevVPNColor: Color {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return .green }
            return .secondary
        case .running: return .blue
        case .passed: return .green
        case .failed: return .red
        }
    }

    private var sessionValue: String {
        switch appModel.deviceSession.phase {
        case .idle: "Inactive"
        case .openingLocalDevVPN: "Opening LocalDevVPN"
        case .discovering: "Finding this iPhone"
        case .connecting: "Connecting"
        case .active: "Active"
        case .stopping: "Stopping"
        case .failed: "Failed"
        }
    }

    private var sessionSymbol: String {
        switch appModel.deviceSession.phase {
        case .idle: "pause.circle"
        case .openingLocalDevVPN, .discovering, .connecting: "arrow.triangle.2.circlepath"
        case .active: "location.circle.fill"
        case .stopping: "stop.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var sessionColor: Color {
        switch appModel.deviceSession.phase {
        case .idle: .secondary
        case .openingLocalDevVPN, .discovering, .connecting, .stopping: .blue
        case .active: .green
        case .failed: .red
        }
    }

    private var resultMessage: String? {
        switch diagnostics.state {
        case .notRun, .running: nil
        case .passed(let message), .failed(let message): message
        }
    }

    private var resultSymbol: String {
        switch diagnostics.state {
        case .passed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .notRun, .running: "circle"
        }
    }

    private var resultColor: Color {
        switch diagnostics.state {
        case .passed: .green
        case .failed: .red
        case .notRun, .running: .secondary
        }
    }

    private func healthRow(
        title: String,
        value: String,
        symbol: String,
        color: Color
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                        Text(value)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                        .frame(width: 22)
                    Text(title)
                    Spacer()
                    Text(value)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }

    @MainActor
    private func runConnectionCheck() async {
        do {
            let pairingRecord = try await appModel.pairingService.pairingRecordData()
            diagnostics.run(
                pairingRecord: pairingRecord,
                sessionPhase: appModel.deviceSession.phase
            )
        } catch {
            diagnostics.run(pairingRecord: nil, sessionPhase: appModel.deviceSession.phase)
        }
    }

    private var diagnosticsText: String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let checked = diagnostics.lastChecked?.formatted(date: .numeric, time: .standard) ?? "Not run"

        return """
        Roam Control Diagnostics
        Generated: \(Date().formatted(date: .numeric, time: .standard))
        App: \(appVersion) (\(build))
        iOS: \(UIDevice.current.systemVersion)
        Pairing: \(pairingValue)
        LocalDevVPN: \(localDevVPNValue)
        Session: \(sessionValue)
        Active place: \(activeTarget?.name ?? "None")
        Coordinates: \(coordinatesValue)
        Last connection check: \(checked)
        Connection check result: \(diagnosticResultText)
        Appearance: \(appModel.appearance.title)
        Map style: \(appModel.mapDisplayStyle.title)
        """
    }

    private var diagnosticResultText: String {
        switch diagnostics.state {
        case .notRun: "Not run"
        case .running: "Running"
        case .passed(let message): "Passed — \(message)"
        case .failed(let message): "Failed — \(message)"
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionHealthView()
            .environment(AppModel())
    }
}

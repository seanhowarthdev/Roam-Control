import SwiftUI

struct SettingsView: View {
    private static let bugReportURL = URL(
        string: "https://github.com/seanhowarthdev/Roam-Control/issues/new?template=bug_report.yml"
    )!
    private static let featureRequestURL = URL(
        string: "https://github.com/seanhowarthdev/Roam-Control/issues/new?template=feature_request.yml"
    )!

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isShowingDeviceSetup = false
    @State private var isReplayingOnboarding = false
    @State private var isConfirmingReset = false
    @State private var resetError: String?
    @State private var releaseUpdateStatus: ReleaseUpdateStatus = .idle

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Theme")
                            .font(.subheadline.weight(.medium))

                        themePicker
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Map Style")
                            .font(.subheadline.weight(.medium))

                        mapStylePicker
                    }
                    .padding(.vertical, 4)
                }

                Section("Device") {
                    NavigationLink {
                        ConnectionHealthView()
                            .environment(appModel)
                    } label: {
                        Label("Connection Health", systemImage: "stethoscope")
                    }

                    Button {
                        isShowingDeviceSetup = true
                    } label: {
                        Label {
                            pairingConnectionLabel
                        } icon: {
                            Image(systemName: "iphone.and.arrow.forward")
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    Toggle(
                        "Share Anonymous Usage Statistics",
                        isOn: anonymousUsageStatisticsBinding
                    )

                    NavigationLink {
                        UsageStatisticsPrivacyView()
                    } label: {
                        Label("What Is Shared", systemImage: "hand.raised.fill")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Optional and off by default. Helps estimate activity from participating installations. Locations, searches and pairing data are never included.")
                }

                Section("About") {
                    NavigationLink {
                        AboutRoamControlView()
                    } label: {
                        Label("About Roam Control", systemImage: "info.circle")
                    }

                    LabeledContent("Version", value: versionText)
                    LabeledContent("Build", value: buildNumberText)
                    LabeledContent("Built", value: buildDateText)

                    Button {
                        isReplayingOnboarding = true
                    } label: {
                        Label("Replay Introduction", systemImage: "sparkles")
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    Button {
                        Task { await checkForUpdates() }
                    } label: {
                        Label(updateCheckTitle, systemImage: updateCheckSymbol)
                    }
                    .disabled(releaseUpdateStatus == .checking)

                    updateStatusDetail
                } header: {
                    Text("Updates")
                } footer: {
                    Text("Checks the public GitHub release only when you tap it. Roam Control never sends location, pairing or diagnostic data with this request.")
                }

                Section {
                    Link(destination: Self.bugReportURL) {
                        Label("Report a Bug", systemImage: "ladybug")
                    }

                    Link(destination: Self.featureRequestURL) {
                        Label("Request a Feature", systemImage: "lightbulb")
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("GitHub may ask you to choose Bug Report or Feature Request first. For pairing or connection problems, open Connection Health and use Copy Diagnostics. Do not include pairing records, credentials or private locations.")
                }

                Section {
                    Button("Reset Roam Control", role: .destructive) {
                        isConfirmingReset = true
                    }
                } footer: {
                    Text("This clears the pairing record and local app settings, then shows onboarding again. It does not remove or change LocalDevVPN.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: $isShowingDeviceSetup) {
            PairingSetupView()
                .environment(appModel)
        }
        .fullScreenCover(isPresented: $isReplayingOnboarding) {
            OnboardingView(isReplay: true)
                .environment(appModel)
        }
        .confirmationDialog(
            "Reset Roam Control?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset App", role: .destructive) {
                Task { await resetApp() }
            }
        } message: {
            Text("Your pairing record and local choices will be removed. You will return to the welcome screen.")
        }
        .alert("Reset could not finish", isPresented: isShowingResetError) {
            Button("OK", role: .cancel) {
                resetError = nil
            }
        } message: {
            Text(resetError ?? "Please try again.")
        }
    }

    private var connectionLabel: String {
        switch appModel.connectionState {
        case .notConfigured: "Not paired"
        case .ready: "Ready"
        case .connecting: "Connecting"
        case .active: "Active"
        case .failed: "Problem"
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appModel.appearance {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { appModel.appearance },
            set: appModel.setAppearance
        )
    }

    @ViewBuilder
    private var themePicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("Theme", selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label(appearance.title, systemImage: appearance.systemImage)
                        .tag(appearance)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker("Theme", selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label(appearance.title, systemImage: appearance.systemImage)
                        .tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var mapStylePicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("Map Style", selection: mapStyleBinding) {
                ForEach(MapDisplayStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker("Map Style", selection: mapStyleBinding) {
                ForEach(MapDisplayStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var pairingConnectionLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 3) {
                Text("Pairing & Connection")
                Text(connectionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text("Pairing & Connection")
                Spacer()
                Text(connectionLabel)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var mapStyleBinding: Binding<MapDisplayStyle> {
        Binding(
            get: { appModel.mapDisplayStyle },
            set: appModel.setMapDisplayStyle
        )
    }

    private var anonymousUsageStatisticsBinding: Binding<Bool> {
        Binding(
            get: { appModel.sharesAnonymousUsageStatistics },
            set: appModel.setSharesAnonymousUsageStatistics
        )
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0"
    }

    private var buildNumberText: String {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build ?? "Unknown"
    }

    private var buildDateText: String {
        if
            let timestamp = Bundle.main.object(
                forInfoDictionaryKey: "RoamControlBuildTimestamp"
            ) as? String,
            let buildDate = ISO8601DateFormatter().date(from: timestamp)
        {
            return buildDate.formatted(date: .abbreviated, time: .shortened)
        }

        guard
            let executableURL = Bundle.main.executableURL,
            let values = try? executableURL.resourceValues(forKeys: [.contentModificationDateKey]),
            let buildDate = values.contentModificationDate
        else { return "Unknown" }

        return buildDate.formatted(date: .abbreviated, time: .shortened)
    }

    private var updateCheckTitle: String {
        switch releaseUpdateStatus {
        case .checking: "Checking for Updates…"
        default: "Check for Updates"
        }
    }

    private var updateCheckSymbol: String {
        releaseUpdateStatus == .checking ? "arrow.triangle.2.circlepath" : "arrow.down.circle"
    }

    @ViewBuilder
    private var updateStatusDetail: some View {
        switch releaseUpdateStatus {
        case .idle, .checking:
            EmptyView()
        case .updateAvailable(let release):
            Link(destination: release.releaseURL) {
                Label("Install \(release.version)", systemImage: "arrow.up.right.square")
            }
            Text("A newer public release is available: \(release.name).")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .current(let release):
            Label("You have the latest public release (\(release.version)).", systemImage: "checkmark.circle")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .newerLocalBuild(let release):
            Link(destination: release.releaseURL) {
                Label("View public release \(release.version)", systemImage: "arrow.up.right.square")
            }
            Text("You are using a newer local test build (\(versionText) Build \(buildNumberText)).")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .noPublishedRelease:
            Label("No public GitHub release has been published yet.", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .unavailable:
            Label("Couldn’t check GitHub right now. Try again later.", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func checkForUpdates() async {
        releaseUpdateStatus = .checking

        do {
            let release = try await ReleaseUpdateChecker().latestRelease()
            if VersionComparison.isRemoteVersionNewer(release.version, than: versionText) {
                releaseUpdateStatus = .updateAvailable(release)
            } else if VersionComparison.isRemoteVersionNewer(versionText, than: release.version) {
                releaseUpdateStatus = .newerLocalBuild(release)
            } else {
                releaseUpdateStatus = .current(release)
            }
        } catch ReleaseUpdateCheckError.noPublishedRelease {
            releaseUpdateStatus = .noPublishedRelease
        } catch {
            releaseUpdateStatus = .unavailable
        }
    }

    private var isShowingResetError: Binding<Bool> {
        Binding(
            get: { resetError != nil },
            set: { if !$0 { resetError = nil } }
        )
    }

    @MainActor
    private func resetApp() async {
        do {
            try await appModel.resetApp()
            dismiss()
        } catch {
            resetError = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
}

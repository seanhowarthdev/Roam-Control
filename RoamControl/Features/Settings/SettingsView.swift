import SwiftUI

struct SettingsView: View {
    @Environment(\.locale) private var locale
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isShowingDeviceSetup = false
    @State private var isReplayingOnboarding = false
    @State private var isConfirmingReset = false
    @State private var resetError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalization.text("Language", locale: locale)) {
                    LanguagePicker()
                }

                Section(AppLocalization.text("Appearance", locale: locale)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppLocalization.text("Theme", locale: locale))
                            .font(.subheadline.weight(.medium))

                        themePicker
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppLocalization.text("Map Style", locale: locale))
                            .font(.subheadline.weight(.medium))

                        mapStylePicker
                    }
                    .padding(.vertical, 4)
                }

                Section(AppLocalization.text("Device", locale: locale)) {
                    NavigationLink {
                        EmbeddedVPNView()
                            .environment(appModel)
                    } label: {
                        Label(AppLocalization.text("Built-in Local VPN", locale: locale), systemImage: "network")
                    }

                    NavigationLink {
                        ConnectionHealthView()
                            .environment(appModel)
                    } label: {
                        Label(AppLocalization.text("Connection Health", locale: locale), systemImage: "stethoscope")
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

                Section(AppLocalization.text("About", locale: locale)) {
                    NavigationLink {
                        AboutRoamControlView()
                    } label: {
                        Label(AppLocalization.text("About Roam Control", locale: locale), systemImage: "info.circle")
                    }

                    LabeledContent(AppLocalization.text("Version", locale: locale), value: AppLocalization.text(versionText, locale: locale))
                    LabeledContent(AppLocalization.text("Build", locale: locale), value: AppLocalization.text(buildNumberText, locale: locale))
                    LabeledContent(AppLocalization.text("Built", locale: locale), value: AppLocalization.text(buildDateText, locale: locale))

                    Button {
                        isReplayingOnboarding = true
                    } label: {
                        Label(AppLocalization.text("Replay Introduction", locale: locale), systemImage: "sparkles")
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    Button(AppLocalization.text("Reset Roam Control", locale: locale), role: .destructive) {
                        isConfirmingReset = true
                    }
                } footer: {
                    Text(AppLocalization.text("This clears the pairing record and local app settings, then shows onboarding again. It does not remove or change the built-in VPN configuration.", locale: locale))
                }
            }
            .navigationTitle(AppLocalization.text("Settings", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLocalization.text("Done", locale: locale)) { dismiss() }
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
            AppLocalization.text("Reset Roam Control?", locale: locale),
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("Reset App", locale: locale), role: .destructive) {
                Task { await resetApp() }
            }
        } message: {
            Text(AppLocalization.text("Your pairing record and local choices will be removed. You will return to the welcome screen.", locale: locale))
        }
        .alert(AppLocalization.text("Reset could not finish", locale: locale), isPresented: isShowingResetError) {
            Button(AppLocalization.text("OK", locale: locale), role: .cancel) {
                resetError = nil
            }
        } message: {
            Text(AppLocalization.text(resetError ?? "Please try again.", locale: locale))
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
            Picker(AppLocalization.text("Theme", locale: locale), selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label(AppLocalization.text(appearance.title, locale: locale), systemImage: appearance.systemImage)
                        .tag(appearance)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker(AppLocalization.text("Theme", locale: locale), selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label(AppLocalization.text(appearance.title, locale: locale), systemImage: appearance.systemImage)
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
            Picker(AppLocalization.text("Map Style", locale: locale), selection: mapStyleBinding) {
                ForEach(MapDisplayStyle.allCases) { style in
                    Text(AppLocalization.text(style.title, locale: locale)).tag(style)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker(AppLocalization.text("Map Style", locale: locale), selection: mapStyleBinding) {
                ForEach(MapDisplayStyle.allCases) { style in
                    Text(AppLocalization.text(style.title, locale: locale)).tag(style)
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
                Text(AppLocalization.text("Pairing & Connection", locale: locale))
                Text(AppLocalization.text(connectionLabel, locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text(AppLocalization.text("Pairing & Connection", locale: locale))
                Spacer()
                Text(AppLocalization.text(connectionLabel, locale: locale))
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
            return buildDate.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
        }

        guard
            let executableURL = Bundle.main.executableURL,
            let values = try? executableURL.resourceValues(forKeys: [.contentModificationDateKey]),
            let buildDate = values.contentModificationDate
        else { return "Unknown" }

        return buildDate.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
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

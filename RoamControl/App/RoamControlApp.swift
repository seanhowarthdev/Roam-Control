import SwiftUI

@main
struct RoamControlApp: App {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if appModel.hasCompletedOnboarding || shouldBypassOnboarding {
                    HomeView(
                        showDeviceSetupInitially: appModel.shouldPresentDeviceSetup
                            || shouldShowDeviceSetupInitially,
                        showSettingsInitially: shouldShowSettingsInitially
                    )
                    .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
                .environment(appModel)
                .preferredColorScheme(preferredColorScheme)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.25),
                    value: appModel.hasCompletedOnboarding
                )
                .onOpenURL { url in
                    appModel.handleOpenURL(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    appModel.appBecameActive()
                }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appModel.appearance {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var shouldBypassOnboarding: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
            || shouldShowDeviceSetupInitially
            || shouldShowSettingsInitially
#else
        false
#endif
    }

    private var shouldShowDeviceSetupInitially: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--show-device-setup")
#else
        false
#endif
    }

    private var shouldShowSettingsInitially: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--show-settings")
#else
        false
#endif
    }
}

import SwiftUI

struct MobileDataGuidanceView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let guidance: MobileDataGuidance
    let onOpenLocalDevVPN: () -> Void
    let onRetry: () -> Void
    let onUseMobileData: () -> Void
    let onMobileDataOff: () -> Void
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                }
                .frame(maxHeight: 540)
            } else {
                content
            }
        }
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 28)
        .padding(.top, 12)
        .padding(.bottom, 26)
        .frame(maxWidth: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 28, y: 12)
    }

    private var content: some View {
        VStack(spacing: 22) {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 38, height: 5)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: iconColours,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? 68 : 82,
                        height: dynamicTypeSize.isAccessibilitySize ? 68 : 82
                    )

                Image(systemName: iconSymbol)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                Text(AppLocalization.text(title, locale: locale))
                    .font(.title2.bold())

                Text(AppLocalization.text(message, locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if guidance == .connectionHelp {
                Label(
                    AppLocalization.text("Roam Control has not found this iPhone through the local VPN yet.", locale: locale),
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Button(AppLocalization.text("Try Again", locale: locale), action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button(AppLocalization.text("Connect Local VPN", locale: locale), action: onOpenLocalDevVPN)
                    .buttonStyle(.bordered)

                Button(AppLocalization.text("I'm Using Mobile Data", locale: locale), action: onUseMobileData)
                    .buttonStyle(.bordered)

                Button(AppLocalization.text("Cancel", locale: locale), role: .cancel, action: onCancel)
                    .foregroundStyle(.secondary)
            } else if guidance == .turnOff {
                HStack(spacing: 9) {
                    ProgressView()
                    Text(AppLocalization.text("Detecting this iPhone…", locale: locale))
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(.thinMaterial, in: Capsule())

                Label(
                    AppLocalization.text("Roam Control should continue automatically. If it doesn't, tap Continue.", locale: locale),
                    systemImage: "checkmark.seal.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Button(AppLocalization.text("Continue", locale: locale), action: onMobileDataOff)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button(AppLocalization.text("Connect Local VPN", locale: locale), action: onOpenLocalDevVPN)
                    .buttonStyle(.bordered)

                Button(AppLocalization.text("Cancel", locale: locale), role: .cancel, action: onCancel)
                    .foregroundStyle(.secondary)
            } else {
                Label(AppLocalization.text("Location is active", locale: locale), systemImage: "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)

                Button(AppLocalization.text("Done", locale: locale), action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var title: String {
        switch guidance {
        case .connectionHelp:
            "Still Connecting"
        case .turnOff:
            "Turn Mobile Data Off"
        case .turnBackOn:
            "Turn Mobile Data Back On"
        }
    }

    private var message: String {
        switch guidance {
        case .connectionHelp:
            "If you're on Wi‑Fi, make sure the local VPN is connected, then try again. Choose mobile data only when you're actually using 4G or 5G."
        case .turnOff:
            "Keep the local VPN connected, switch mobile data off briefly, then return to Roam Control."
        case .turnBackOn:
            "The secure location session is ready. You can restore mobile data now; spoofing will continue over 5G."
        }
    }

    private var iconColours: [Color] {
        switch guidance {
        case .connectionHelp: [.purple, .indigo]
        case .turnOff: [.indigo, .blue]
        case .turnBackOn: [.green, .teal]
        }
    }

    private var iconSymbol: String {
        switch guidance {
        case .connectionHelp: "lock.shield.fill"
        case .turnOff: "antenna.radiowaves.left.and.right"
        case .turnBackOn: "checkmark"
        }
    }
}

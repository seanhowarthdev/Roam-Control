import SwiftUI

struct SessionRecoveryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let recovery: SessionRecoveryRecord
    let isPaired: Bool
    let isResuming: Bool
    let isRestoring: Bool
    let errorMessage: String?
    let onResume: () -> Void
    let onRestore: () -> Void
    let onAlreadyRestored: () -> Void
    let onCancel: () -> Void

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
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 26)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 28, y: 12)
    }

    private var content: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 38, height: 5)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? 66 : 78,
                        height: dynamicTypeSize.isAccessibilitySize ? 66 : 78
                    )

                Image(systemName: recovery.isWalkingRoute ? "figure.walk.motion" : "location.fill")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 9) {
                Text("Previous Session Interrupted")
                    .font(.title2.bold())

                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                recoveryDetail(
                    title: recovery.isWalkingRoute ? "Last saved point" : "Last location",
                    value: recovery.lastReportedLocation.name,
                    symbol: "mappin.and.ellipse"
                )

                if let destination = recovery.destination, recovery.isWalkingRoute {
                    recoveryDetail(
                        title: "Destination",
                        value: destination.name,
                        symbol: "flag.checkered"
                    )
                }

                recoveryDetail(
                    title: "Last active",
                    value: recovery.updatedAt.formatted(date: .abbreviated, time: .shortened),
                    symbol: "clock"
                )
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if isResuming || isRestoring {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(isRestoring ? "Restoring real location…" : "Preparing the route…")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)

                Button("Cancel", role: .cancel, action: onCancel)
                    .foregroundStyle(.secondary)
            } else {
                Button(action: onResume) {
                    Label(resumeTitle, systemImage: recovery.isWalkingRoute ? "figure.walk" : "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isPaired)

                Button(role: .destructive, action: onRestore) {
                    Label("Restore Real Location", systemImage: "location.slash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!isPaired)

                Button("My Real Location Is Already Back", action: onAlreadyRestored)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !isPaired {
                Label("Pair this iPhone before resuming or restoring the session.", systemImage: "iphone.and.arrow.forward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Restoring reconnects only long enough to clear the simulated location. Nothing starts automatically.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summaryText: String {
        if let destination = recovery.destination, recovery.isWalkingRoute {
            return "Roam Control did not receive a normal end signal while walking to \(destination.name). You can continue from the last saved point or safely restore your real location."
        }

        return "Roam Control did not receive a normal end signal for the location at \(recovery.lastReportedLocation.name). Choose what this iPhone should do next."
    }

    private var resumeTitle: String {
        recovery.isWalkingRoute ? "Resume Walking" : "Resume Location"
    }

    private func recoveryDetail(title: String, value: String, symbol: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: symbol)
                        .foregroundStyle(.blue)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.caption.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 11) {
                    Image(systemName: symbol)
                        .foregroundStyle(.blue)
                        .frame(width: 22)

                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Text(value)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}

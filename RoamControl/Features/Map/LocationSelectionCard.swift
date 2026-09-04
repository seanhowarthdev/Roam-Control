import SwiftUI
import UIKit

struct LocationSelectionCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let location: LocationTarget?
    let lastLocation: LocationTarget?
    let isFavourite: Bool
    let isPaired: Bool
    let sessionPhase: DeviceSessionPhase
    let localDevVPNInstallURL: URL
    let isPreviewingWalkingRoute: Bool
    let walkingRouteError: String?
    let onToggleFavourite: () -> Void
    let onClearSelection: () -> Void
    let onDismissLast: () -> Void
    let onResumeLast: () -> Void
    let onPreviewWalkingRoute: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void

    @State private var didCopyCoordinates = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    cardContent
                }
                .frame(maxHeight: 460)
            } else {
                cardContent
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let location {
                locationHeader(for: location)

                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        if isWorking {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: primarySymbol)
                        }
                        Text(primaryTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(isShowingActiveTarget ? .red : .blue)
                .disabled(isPrimaryDisabled)

                if canPreviewWalkingRoute {
                    Button(action: onPreviewWalkingRoute) {
                        HStack(spacing: 8) {
                            if isPreviewingWalkingRoute {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "figure.walk")
                            }
                            Text(isPreviewingWalkingRoute ? "Planning Walking Route…" : "Preview Walking Route")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isPreviewingWalkingRoute)
                }

                if let walkingRouteError {
                    Text(walkingRouteError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isActive && !isShowingActiveTarget {
                    Button("Stop Location", role: .destructive, action: onStop)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .frame(maxWidth: .infinity)
                }

                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(isFailure ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)

                if shouldOfferLocalDevVPN {
                    Link(destination: localDevVPNInstallURL) {
                        Label("Get LocalDevVPN", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: "hand.tap")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Choose a location")
                            .font(.headline)
                        Text("Search above or tap anywhere on the map.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let lastLocation {
                    resumeLastControls(lastLocation)
                }
            }
        }
    }

    @ViewBuilder
    private func locationHeader(for location: LocationTarget) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                locationSummary(for: location)
                HStack(spacing: 4) {
                    Spacer()
                    locationActions
                }
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                locationSummary(for: location)
                Spacer(minLength: 0)
                locationActions
            }
        }
    }

    private func locationSummary(for location: LocationTarget) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

                HStack(spacing: 7) {
                    Text(locationDescription(for: location))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)

                    Button {
                        copyLocation(for: location)
                    } label: {
                        Image(systemName: didCopyCoordinates ? "checkmark" : "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(didCopyCoordinates ? .green : .blue)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(didCopyCoordinates ? "Location copied" : "Copy location")
                }
            }
        }
    }

    @ViewBuilder
    private var locationActions: some View {
        Button(action: onToggleFavourite) {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(isFavourite ? .pink : .secondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")

        if canClearSelection {
            Button(action: onClearSelection) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear selected location")
        }
    }

    @ViewBuilder
    private func resumeLastControls(_ lastLocation: LocationTarget) -> some View {
        let resumeButton = Button(action: onResumeLast) {
            Label("Resume \(lastLocation.name)", systemImage: "arrow.clockwise")
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isPaired || isWorking)

        let dismissButton = Button(action: onDismissLast) {
            if dynamicTypeSize.isAccessibilitySize {
                Label("Dismiss", systemImage: "xmark")
                    .frame(minWidth: 44, minHeight: 44)
            } else {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("Dismiss last location suggestion")

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                resumeButton
                dismissButton.frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: 8) {
                resumeButton
                dismissButton
            }
        }
    }

    private func locationDescription(for location: LocationTarget) -> String {
        let name = location.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = location.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subtitle.isEmpty else { return name }

        if subtitle.lowercased().hasPrefix(name.lowercased()) {
            let remainder = subtitle.dropFirst(name.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            if !remainder.isEmpty {
                return remainder
            }
        }

        return subtitle
    }

    private func copyLocation(for location: LocationTarget) {
        let name = location.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = location.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if subtitle.isEmpty || subtitle.caseInsensitiveCompare(name) == .orderedSame {
            UIPasteboard.general.string = name
        } else if subtitle.lowercased().hasPrefix(name.lowercased()) {
            UIPasteboard.general.string = subtitle
        } else {
            UIPasteboard.general.string = "\(name), \(subtitle)"
        }
        didCopyCoordinates = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            didCopyCoordinates = false
        }
    }

    private var isActive: Bool {
        if case .active = sessionPhase { return true }
        return false
    }

    private var isShowingActiveTarget: Bool {
        guard
            let location,
            case .active(let activeTarget) = sessionPhase
        else { return false }
        return location.id == activeTarget.id
    }

    private var isWorking: Bool {
        switch sessionPhase {
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            true
        case .idle, .active, .failed:
            false
        }
    }

    private var isFailure: Bool {
        if case .failed = sessionPhase { return true }
        return false
    }

    private var shouldOfferLocalDevVPN: Bool {
        guard case .failed(let message) = sessionPhase else { return false }
        return message.localizedCaseInsensitiveContains("Install LocalDevVPN")
    }

    private var primaryTitle: String {
        switch sessionPhase {
        case .openingLocalDevVPN:
            "Opening LocalDevVPN…"
        case .discovering:
            "Finding This iPhone…"
        case .connecting:
            "Starting Location…"
        case .active:
            isShowingActiveTarget ? "Stop Location" : "Update Location"
        case .stopping:
            "Stopping Location…"
        case .failed:
            "Try Again"
        case .idle:
            "Start Location"
        }
    }

    private var primarySymbol: String {
        switch sessionPhase {
        case .active: isShowingActiveTarget ? "stop.circle.fill" : "location.fill"
        case .failed: "arrow.clockwise"
        case .idle: "location.fill"
        case .openingLocalDevVPN, .discovering, .connecting, .stopping: "hourglass"
        }
    }

    private var isPrimaryDisabled: Bool {
        isWorking || (!isPaired && !isActive)
    }

    private var canClearSelection: Bool {
        switch sessionPhase {
        case .idle, .failed:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
            false
        }
    }

    private var canPreviewWalkingRoute: Bool {
        switch sessionPhase {
        case .idle, .active:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .stopping, .failed:
            false
        }
    }

    private var statusMessage: String {
        switch sessionPhase {
        case .idle:
            return isPaired
                ? "Start when ready. Stop restores this iPhone's real location."
                : "Pair this iPhone before starting location control."
        case .openingLocalDevVPN:
            return "Roam Control will return automatically after the tunnel starts."
        case .discovering:
            return "Finding the paired iPhone through the private local tunnel."
        case .connecting:
            return "Opening the secure location session."
        case .active(let target):
            if !isShowingActiveTarget, let location {
                return "Currently using \(target.name). Update to move to \(location.name)."
            }
            return "This iPhone is using \(target.name). Stop to restore its real location."
        case .stopping:
            return "Restoring this iPhone's real location."
        case .failed(let message):
            return message
        }
    }

    private func primaryAction() {
        if isShowingActiveTarget {
            onStop()
        } else {
            onStart()
        }
    }
}

import MapKit
import SwiftUI

struct WalkingRoutePreviewCard: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let route: MKRoute
    let destination: LocationTarget
    let simulation: WalkingSimulationController
    let isPaired: Bool
    let onStart: () -> Void
    let onTogglePause: () -> Void
    let onWalkBack: () -> Void
    let onChooseNewLocation: () -> Void
    let onStop: () -> Void
    let onDone: () -> Void

    @State private var isConfirmingStop = false

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
        .confirmationDialog(
            AppLocalization.text("Stop walking and restore this iPhone's real location?", locale: locale),
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("Stop & Restore", locale: locale), role: .destructive, action: onStop)
            Button(AppLocalization.text("Keep Simulated Location", locale: locale), role: .cancel) {}
        } message: {
            Text(AppLocalization.text("Roam Control will end the simulated walk and restore your real location. Your route progress will be reset.", locale: locale))
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: phaseSymbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(phaseColour)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(AppLocalization.text(phaseTitle, locale: locale))
                        .font(.headline)

                    Text(AppLocalization.text(phaseSubtitle, locale: locale))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                }

                Spacer(minLength: 0)

                if canClose {
                    Button(action: onDone) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppLocalization.text("Close walking route", locale: locale))
                }
            }

            if showsProgress {
                ProgressView(value: simulation.progress)
                    .tint(simulation.phase == .arrived ? .green : .blue)
            }

            routeMetrics

            if canChoosePace {
                pacePicker
            }

            controls
            footer
        }
    }

    @ViewBuilder
    private var pacePicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker(AppLocalization.text("Walking pace", locale: locale), selection: paceBinding) {
                ForEach(WalkingPace.allCases) { pace in
                    Text(AppLocalization.text(pace.title, locale: locale)).tag(pace)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker(AppLocalization.text("Walking pace", locale: locale), selection: paceBinding) {
                ForEach(WalkingPace.allCases) { pace in
                    Text(AppLocalization.text(pace.title, locale: locale)).tag(pace)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var routeMetrics: some View {
        let distance = RouteMetric(
            title: showsProgress ? "Remaining" : "Distance",
            value: distanceText,
            symbol: "point.topleft.down.to.point.bottomright.curvepath"
        )
        let duration = RouteMetric(
            title: simulation.phase == .arrived ? "Status" : "Walking",
            value: durationText,
            symbol: simulation.phase == .arrived ? "checkmark.circle" : "clock"
        )
        let arrival = RouteMetric(
            title: "Arrive",
            value: arrivalText,
            symbol: "flag.checkered"
        )

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                distance
                duration
                arrival
            }
        } else {
            HStack(spacing: 10) {
                distance
                duration
                arrival
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch simulation.phase {
        case .idle:
            Button(action: onStart) {
                Label(AppLocalization.text("Start Walking", locale: locale), systemImage: "figure.walk.motion")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isPaired)

        case .preparing:
            HStack(spacing: 10) {
                ProgressView()
                Text(AppLocalization.text("Starting walking session…", locale: locale))
                    .font(.subheadline.weight(.medium))
            }
            Button(action: onStop) {
                Text(AppLocalization.text("Cancel", locale: locale))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

        case .walking, .paused:
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        pauseButton
                        stopWalkingButton(showTitle: true)
                    }
                } else {
                    HStack(spacing: 10) {
                        pauseButton
                        stopWalkingButton(showTitle: false)
                    }
                }
            }

        case .arrived:
            Button(action: onWalkBack) {
                Label(AppLocalization.text("Walk Route Back", locale: locale), systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        newLocationButton
                        stopAtArrivalButton(showTitle: true)
                    }
                } else {
                    HStack(spacing: 10) {
                        newLocationButton
                        stopAtArrivalButton(showTitle: false)
                    }
                }
            }

        case .stopping:
            HStack(spacing: 10) {
                ProgressView()
                Text(AppLocalization.text("Restoring this iPhone's real location…", locale: locale))
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)

        case .failed:
            Button(action: onStart) {
                Label(AppLocalization.text("Try Again", locale: locale), systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isPaired)
        }
    }

    private var pauseButton: some View {
                Button(action: onTogglePause) {
                    Label(
                        AppLocalization.text(simulation.phase == .paused ? "Resume" : "Pause", locale: locale),
                        systemImage: simulation.phase == .paused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
    }

    @ViewBuilder
    private func stopWalkingButton(showTitle: Bool) -> some View {
                Button(role: .destructive) {
                    isConfirmingStop = true
                } label: {
            if showTitle {
                Label(AppLocalization.text("Stop & Restore", locale: locale), systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "stop.fill")
                    .frame(width: 28)
            }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel(AppLocalization.text("Stop walking and restore real location", locale: locale))
    }

    private var newLocationButton: some View {
        Button(action: onChooseNewLocation) {
            Label(AppLocalization.text("New Location", locale: locale), systemImage: "mappin.and.ellipse")
                    .frame(maxWidth: .infinity)
            }
        .buttonStyle(.bordered)
            .controlSize(.large)
    }

    @ViewBuilder
    private func stopAtArrivalButton(showTitle: Bool) -> some View {
                Button(role: .destructive) {
                    isConfirmingStop = true
                } label: {
            if showTitle {
                Label(AppLocalization.text("Stop & Restore", locale: locale), systemImage: "location.slash.fill")
                    .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "location.slash.fill")
                    .frame(width: 28)
            }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel(AppLocalization.text("Stop and restore real location", locale: locale))
    }

    @ViewBuilder
    private var footer: some View {
        switch simulation.phase {
        case .idle:
            Text(AppLocalization.text(isPaired
                 ? "Your location will move along this route at the selected pace."
                 : "Pair this iPhone before starting a walking session.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .preparing:
            Text(AppLocalization.text("Follow the mobile-data guidance if it appears.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .walking:
            Text(AppLocalization.text("Keep Roam Control running. You can use other apps while the walk continues.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .paused:
            Text(AppLocalization.text("Your spoofed location is being held here until you resume.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .arrived:
            Text(AppLocalization.text("The destination remains active until you stop and restore your real location.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .stopping:
            Text(AppLocalization.text("Keep Roam Control open until the real location has been restored.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .failed(let message):
            Text(AppLocalization.text(message, locale: locale))
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canClose: Bool {
        switch simulation.phase {
        case .idle, .failed:
            true
        case .preparing, .walking, .paused, .arrived, .stopping:
            false
        }
    }

    private var canChoosePace: Bool {
        switch simulation.phase {
        case .idle, .failed:
            true
        case .preparing, .walking, .paused, .arrived, .stopping:
            false
        }
    }

    private var showsProgress: Bool {
        switch simulation.phase {
        case .walking, .paused, .arrived:
            true
        case .idle, .preparing, .stopping, .failed:
            false
        }
    }

    private var phaseTitle: String {
        switch simulation.phase {
        case .idle: "Walking route"
        case .preparing: "Preparing walk"
        case .walking: "Walking"
        case .paused: "Walk paused"
        case .arrived: "Arrived"
        case .stopping: "Ending walk"
        case .failed: "Walking unavailable"
        }
    }

    private var phaseSubtitle: String {
        switch simulation.phase {
        case .idle, .preparing, .failed:
            "Current Location to \(destination.displayName(locale: locale))"
        case .walking, .paused:
            "Heading to \(destination.displayName(locale: locale)) · \(Int((simulation.progress * 100).rounded()))%"
        case .arrived:
            "Location active at \(destination.displayName(locale: locale))"
        case .stopping:
            "Restoring this iPhone's real location"
        }
    }

    private var phaseSymbol: String {
        switch simulation.phase {
        case .idle, .preparing, .walking: "figure.walk"
        case .paused: "pause.circle.fill"
        case .arrived: "checkmark.circle.fill"
        case .stopping: "location.slash.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var phaseColour: Color {
        switch simulation.phase {
        case .arrived: .green
        case .failed: .red
        case .idle, .preparing, .walking, .paused, .stopping: .blue
        }
    }

    private var paceBinding: Binding<WalkingPace> {
        Binding(
            get: { simulation.pace },
            set: { simulation.pace = $0 }
        )
    }

    private var distanceText: String {
        let distance = showsProgress ? simulation.remainingDistance : route.distance
        if Locale.current.region?.identifier == "GB" {
            return formatUKDistance(distance)
        }

        let formatter = MeasurementFormatter()
        formatter.locale = AppLocalization.measurementLocale(for: locale)
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: Measurement(value: distance, unit: UnitLength.meters))
    }

    private func formatUKDistance(_ distance: CLLocationDistance) -> String {
        let metresPerMile = 1_609.344
        guard distance >= metresPerMile else {
            let yards = max(0, distance / 0.9144)
            return "\(Int(yards.rounded())) yd"
        }

        let miles = distance / metresPerMile
        return miles.formatted(
            .number.precision(.fractionLength(miles < 10 ? 1 : 0))
        ) + " mi"
    }

    private var durationText: String {
        guard simulation.phase != .arrived else { return "Complete" }
        let duration = simulation.totalDistance > 0
            ? simulation.remainingDuration
            : route.expectedTravelTime
        return formatDuration(duration)
    }

    private var arrivalText: String {
        guard simulation.phase != .arrived else { return "Now" }
        let duration = simulation.totalDistance > 0
            ? simulation.remainingDuration
            : route.expectedTravelTime
        return Date.now
            .addingTimeInterval(duration)
            .formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        guard minutes >= 60 else { return "\(minutes) min" }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0
            ? "\(hours) hr"
            : "\(hours) hr \(remainingMinutes) min"
    }
}

private struct RouteMetric: View {
    @Environment(\.locale) private var locale
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(AppLocalization.text(title, locale: locale), systemImage: symbol)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(AppLocalization.text(value, locale: locale))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text("\(AppLocalization.text(title, locale: locale)), \(AppLocalization.text(value, locale: locale))", locale: locale))
    }
}

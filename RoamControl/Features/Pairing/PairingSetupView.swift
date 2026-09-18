import SwiftUI
import UniformTypeIdentifiers

struct PairingSetupView: View {
    @Environment(\.locale) private var locale
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isImporting = false
    @State private var isConfirmingRemoval = false


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    requirementsCard
                    privacyCard
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(AppLocalization.text("Device Setup", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLocalization.text("Done", locale: locale)) { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: allowedPairingTypes,
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await appModel.importPairingRecord(from: url) }
        }
        .confirmationDialog(
            AppLocalization.text("Remove this pairing record?", locale: locale),
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("Remove Pairing", locale: locale), role: .destructive) {
                Task { await appModel.removePairingRecord() }
            }
        } message: {
            Text(AppLocalization.text("Roam Control will need a new RPPairing file before it can connect again.", locale: locale))
        }
    }

    private var statusCard: some View {
        setupCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: statusSymbol)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(AppLocalization.text(statusTitle, locale: locale))
                        .font(.headline)
                    Text(AppLocalization.text(statusMessage, locale: locale))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AppLocalization.text("\(AppLocalization.text(statusTitle, locale: locale)). \(AppLocalization.text(statusMessage, locale: locale))", locale: locale))

            if case .paired(let summary) = appModel.pairingStatus {
                Divider()

                pairingDetail(title: "Fingerprint", value: summary.fingerprint, monospaced: true)

                pairingDetail(
                    title: "Added",
                    value: summary.importedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
                )

                Button(AppLocalization.text("Replace Pairing File", locale: locale)) {
                    isImporting = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button(AppLocalization.text("Remove Pairing", locale: locale), role: .destructive) {
                    isConfirmingRemoval = true
                }
                .frame(maxWidth: .infinity)
            } else {
                pairingProgress

                if appModel.onDevicePairing.isAvailableOnThisDevice {
                    if appModel.onDevicePairing.isRunning {
                        Button(AppLocalization.text("Cancel Pairing", locale: locale), role: .cancel) {
                            appModel.cancelOnDevicePairing()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    } else {
                        Button {
                            appModel.startOnDevicePairing()
                        } label: {
                            Label(AppLocalization.text("Pair This iPhone", locale: locale), systemImage: "iphone.and.arrow.forward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isBusy)
                    }
                } else {
                    Label(AppLocalization.text("On-device pairing needs your physical iPhone.", locale: locale), systemImage: "iphone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isImporting = true
                } label: {
                    Label(AppLocalization.text("Import Existing File", locale: locale), systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
        }
    }

    @ViewBuilder
    private var pairingProgress: some View {
        switch appModel.onDevicePairing.phase {
        case .idle, .success, .failed:
            EmptyView()

        case .preparing:
            Divider()
            Label {
                Text(AppLocalization.text("Preparing a secure pairing session…", locale: locale))
            } icon: {
                ProgressView()
            }
            .font(.subheadline)

        case .waitingForSettings:
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text(AppLocalization.text("Finish in Settings", locale: locale))
                    .font(.subheadline.weight(.semibold))
                instructionRow("Open Settings › Privacy & Security › Developer Mode.")
                instructionRow("Tap Pair with Roam Control.")
                instructionRow("Use the code shown here when iOS asks for it.")
            }

        case .showingPIN(let pin):
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalization.text("Enter this code in Settings", locale: locale))
                    .font(.subheadline.weight(.semibold))
                Text(pin.map(String.init).joined(separator: " "))
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.blue)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .accessibilityLabel(AppLocalization.text("Pairing code \(pin)", locale: locale))
                Text(AppLocalization.text("The code is generated on this iPhone and expires with this pairing attempt.", locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .storing:
            Divider()
            Label {
                Text(AppLocalization.text("Securing the pairing record in Keychain…", locale: locale))
            } icon: {
                ProgressView()
            }
            .font(.subheadline)

        case .cancelling:
            Divider()
            Label {
                Text(AppLocalization.text("Stopping pairing…", locale: locale))
            } icon: {
                ProgressView()
            }
            .font(.subheadline)
        }
    }

    private var requirementsCard: some View {
        setupCard {
            Text(AppLocalization.text("Before connecting", locale: locale))
                .font(.headline)

            requirementRow(number: "1", text: "Pair this iPhone here, or import its existing RPPairing file.")
            requirementRow(number: "2", text: "Connect the Built-in Local VPN in Settings. No separate app is needed.")
            requirementRow(number: "3", text: "Keep Developer Mode enabled on the iPhone.")

            Text(AppLocalization.text("New on-device pairing is available on iOS 27. The simulator can test the screen, but Apple only exposes the real handshake on a physical iPhone.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var privacyCard: some View {
        setupCard {
            Label(AppLocalization.text("Stored securely", locale: locale), systemImage: "lock.shield")
                .font(.headline)
                .foregroundStyle(.green)

            Text(AppLocalization.text("The pairing record is generated or checked on this iPhone, then stored only in its Keychain. Roam Control does not upload it.", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func setupCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func requirementRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(AppLocalization.text(number, locale: locale))
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.blue, in: Circle())

            Text(AppLocalization.text(text, locale: locale))
                .font(.subheadline)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text("Step \(number). \(AppLocalization.text(text, locale: locale))", locale: locale))
    }

    private func instructionRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.blue)
                .padding(.top, 3)
            Text(AppLocalization.text(text, locale: locale))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text(text, locale: locale))
    }

    private func pairingDetail(
        title: String,
        value: String,
        monospaced: Bool = false
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.text(title, locale: locale))
                        .foregroundStyle(.secondary)
                    Text(AppLocalization.text(value, locale: locale))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(monospaced ? .caption.monospaced() : .caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LabeledContent(AppLocalization.text(title, locale: locale), value: AppLocalization.text(value, locale: locale))
                    .font(monospaced ? .caption.monospaced() : .caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text("\(AppLocalization.text(title, locale: locale)), \(AppLocalization.text(value, locale: locale))", locale: locale))
    }

    private var allowedPairingTypes: [UTType] {
        var types: [UTType] = [.propertyList]
        if let mobileDevicePairing = UTType(filenameExtension: "mobiledevicepairing") {
            types.append(mobileDevicePairing)
        }
        return types
    }

    private var isBusy: Bool {
        appModel.pairingStatus == .checking
            || appModel.pairingStatus == .importing
            || appModel.onDevicePairing.isRunning
    }

    private var statusSymbol: String {
        switch appModel.onDevicePairing.phase {
        case .preparing, .waitingForSettings, .showingPIN, .storing, .cancelling:
            return "iphone.radiowaves.left.and.right"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .idle, .success:
            break
        }

        switch appModel.pairingStatus {
        case .checking, .importing: return "arrow.triangle.2.circlepath"
        case .notPaired: return "iphone.badge.exclamationmark"
        case .paired: return "checkmark.shield.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch appModel.onDevicePairing.phase {
        case .preparing, .waitingForSettings, .showingPIN, .storing, .cancelling:
            return .blue
        case .failed:
            return .red
        case .idle, .success:
            break
        }

        switch appModel.pairingStatus {
        case .checking, .importing: return .blue
        case .notPaired: return .orange
        case .paired: return .green
        case .failed: return .red
        }
    }

    private var statusTitle: String {
        switch appModel.onDevicePairing.phase {
        case .preparing: return "Preparing pairing"
        case .waitingForSettings: return "Ready in Settings"
        case .showingPIN: return "Pairing code ready"
        case .storing: return "Finishing pairing"
        case .cancelling: return "Stopping pairing"
        case .failed: return "Pairing problem"
        case .idle, .success: break
        }

        switch appModel.pairingStatus {
        case .checking: return "Checking this iPhone"
        case .importing: return "Checking pairing file"
        case .notPaired: return "Pairing required"
        case .paired: return "Pairing file ready"
        case .failed: return "Pairing problem"
        }
    }

    private var statusMessage: String {
        switch appModel.onDevicePairing.phase {
        case .preparing:
            return "Starting a private session on this iPhone."
        case .waitingForSettings:
            return "Roam Control is visible to the iOS pairing screen."
        case .showingPIN:
            return "Enter the six-digit code in Settings to confirm."
        case .storing:
            return "The handshake worked. Saving its keys securely."
        case .cancelling:
            return "Closing the local session and advertisement."
        case .failed(let message):
            return message
        case .idle, .success:
            break
        }

        switch appModel.pairingStatus {
        case .checking:
            return "Looking for a securely stored pairing record."
        case .importing:
            return "Validating the record and its keys."
        case .notPaired:
            return appModel.onDevicePairing.isAvailableOnThisDevice
                ? "Create the pairing securely on this iPhone, or import an existing file."
                : "Connect your physical iPhone to create the pairing, or import an existing file."
        case .paired:
            return "Roam Control can use this record when the built-in local VPN is connected."
        case .failed(let message):
            return message
        }
    }
}

#Preview {
    PairingSetupView()
        .environment(AppModel())
}

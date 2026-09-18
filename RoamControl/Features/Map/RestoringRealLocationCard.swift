import SwiftUI

struct RestoringRealLocationCard: View {
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(.blue)

            Text(AppLocalization.text("Location Simulation Stopped", locale: locale))
                .font(.headline)

            Text(AppLocalization.text("Waiting for a fresh location from this iPhone. Other apps may also take time to update…", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppLocalization.text("Location simulation stopped. Waiting for a fresh location from this iPhone.", locale: locale))
    }
}

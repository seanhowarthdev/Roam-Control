import SwiftUI

struct RestoringRealLocationCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(.blue)

            Text("Real Location Restored")
                .font(.headline)

            Text("Updating the map with this iPhone’s real position…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Real location restored. Updating the map with this iPhone’s real position.")
    }
}

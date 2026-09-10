import SwiftUI

struct SearchSuggestionsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let suggestions: [MapSearchSuggestion]
    let onSelect: (MapSearchSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                            Text(visibleSubtitle(for: suggestion))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 58)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: suggestion))
                .accessibilityHint("Selects this location")

                if index < suggestions.count - 1 {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }

    private func accessibilityLabel(for suggestion: MapSearchSuggestion) -> String {
        "\(suggestion.title), \(visibleSubtitle(for: suggestion))"
    }

    private func visibleSubtitle(for suggestion: MapSearchSuggestion) -> String {
        let invisibleCharacters = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
        )
        let detail = suggestion.subtitle.trimmingCharacters(in: invisibleCharacters)
        return detail.isEmpty ? "Location details unavailable" : detail
    }
}

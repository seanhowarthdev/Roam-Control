import SwiftUI

struct SavedPlacesView: View {
    private enum ClearTarget: String, Identifiable {
        case favourites
        case history

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var favouriteBeingRenamed: LocationTarget?
    @State private var favouriteName = ""
    @State private var clearTarget: ClearTarget?

    let favourites: [LocationTarget]
    let history: [LocationTarget]
    let isFavourite: (LocationTarget) -> Bool
    let onSelect: (LocationTarget) -> Void
    let onToggleFavourite: (LocationTarget) -> Void
    let onDeleteFavourite: (LocationTarget) -> Void
    let onRenameFavourite: (LocationTarget, String) -> Void
    let onDeleteHistory: (LocationTarget) -> Void
    let onClearFavourites: () -> Void
    let onClearHistory: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if favourites.isEmpty {
                        EmptySavedPlacesRow(
                            symbol: "heart",
                            message: "Tap the heart on any selected place to save it."
                        )
                    } else {
                        ForEach(favourites) { location in
                            SavedPlaceRow(
                                location: location,
                                symbol: "heart.fill",
                                isFavourite: true,
                                onSelect: { select(location) },
                                onToggleFavourite: { onToggleFavourite(location) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteFavourite(location)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    beginRenaming(location)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Favourites")
                        Spacer()
                        if !favourites.isEmpty {
                            Button("Clear") {
                                clearTarget = .favourites
                            }
                            .textCase(nil)
                        }
                    }
                }

                Section {
                    if history.isEmpty {
                        EmptySavedPlacesRow(
                            symbol: "clock",
                            message: "Places you use will appear here."
                        )
                    } else {
                        ForEach(history) { location in
                            SavedPlaceRow(
                                location: location,
                                symbol: "clock.fill",
                                isFavourite: isFavourite(location),
                                onSelect: { select(location) },
                                onToggleFavourite: { onToggleFavourite(location) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteHistory(location)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("History")
                        Spacer()
                        if !history.isEmpty {
                            Button("Clear") {
                                clearTarget = .history
                            }
                                .textCase(nil)
                        }
                    }
                }
            }
            .navigationTitle("Saved Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Rename Favourite",
                isPresented: Binding(
                    get: { favouriteBeingRenamed != nil },
                    set: { if !$0 { favouriteBeingRenamed = nil } }
                )
            ) {
                TextField("Favourite name", text: $favouriteName)
                Button("Cancel", role: .cancel) {
                    favouriteBeingRenamed = nil
                }
                Button("Save") {
                    guard let favouriteBeingRenamed else { return }
                    onRenameFavourite(favouriteBeingRenamed, favouriteName)
                    self.favouriteBeingRenamed = nil
                }
                .disabled(favouriteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Give this saved place a name that is easy to recognise.")
            }
            .confirmationDialog(
                clearConfirmationTitle,
                isPresented: Binding(
                    get: { clearTarget != nil },
                    set: { if !$0 { clearTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(clearConfirmationButton, role: .destructive) {
                    performClear()
                }
                Button("Cancel", role: .cancel) {
                    clearTarget = nil
                }
            } message: {
                Text(clearConfirmationMessage)
            }
        }
    }

    private func select(_ location: LocationTarget) {
        onSelect(location)
        dismiss()
    }

    private func beginRenaming(_ location: LocationTarget) {
        favouriteName = location.name
        favouriteBeingRenamed = location
    }

    private var clearConfirmationTitle: String {
        switch clearTarget {
        case .favourites: "Clear all favourites?"
        case .history: "Clear location history?"
        case nil: "Clear saved places?"
        }
    }

    private var clearConfirmationButton: String {
        switch clearTarget {
        case .favourites: "Clear Favourites"
        case .history: "Clear History"
        case nil: "Clear"
        }
    }

    private var clearConfirmationMessage: String {
        switch clearTarget {
        case .favourites: "Every favourite will be removed. Your history will be kept."
        case .history: "Every recently used location will be removed. Your favourites will be kept."
        case nil: "This cannot be undone."
        }
    }

    private func performClear() {
        switch clearTarget {
        case .favourites:
            onClearFavourites()
        case .history:
            onClearHistory()
        case nil:
            break
        }
        clearTarget = nil
    }
}

private struct SavedPlaceRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let location: LocationTarget
    let symbol: String
    let isFavourite: Bool
    let onSelect: () -> Void
    let onToggleFavourite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(symbol.hasPrefix("heart") ? .pink : .blue)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(location.name)
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        Text(location.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(locationAccessibilityLabel)
            .accessibilityHint("Selects this location")

            Button(action: onToggleFavourite) {
                Image(systemName: isFavourite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavourite ? .pink : .secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")
        }
    }

    private var locationAccessibilityLabel: String {
        guard !location.subtitle.isEmpty else { return location.name }
        return "\(location.name), \(location.subtitle)"
    }
}

private struct EmptySavedPlacesRow: View {
    let symbol: String
    let message: String

    var body: some View {
        Label(message, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }
}

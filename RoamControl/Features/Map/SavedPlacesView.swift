import SwiftUI

struct SavedPlacesView: View {
    @Environment(\.locale) private var locale
    private enum ClearTarget: String, Identifiable {
        case favourites
        case history

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var favouriteBeingRenamed: LocationTarget?
    @State private var favouriteName = ""
    @State private var clearTarget: ClearTarget?
    @State private var editMode: EditMode = .inactive

    let favourites: [LocationTarget]
    let history: [LocationTarget]
    let shouldShowFavouriteReorderHint: Bool
    let isFavourite: (LocationTarget) -> Bool
    let onSelect: (LocationTarget) -> Void
    let onToggleFavourite: (LocationTarget) -> Void
    let onDeleteFavourite: (LocationTarget) -> Void
    let onMoveFavourites: (IndexSet, Int) -> Void
    let onDismissFavouriteReorderHint: () -> Void
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
                                    Label(AppLocalization.text("Delete", locale: locale), systemImage: "trash")
                                }

                                Button {
                                    beginRenaming(location)
                                } label: {
                                    Label(AppLocalization.text("Rename", locale: locale), systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onMove(perform: onMoveFavourites)
                    }
                } header: {
                    HStack {
                        Text(AppLocalization.text("Favourites", locale: locale))
                        Spacer()
                        if !favourites.isEmpty {
                            Button(AppLocalization.text("Clear", locale: locale)) {
                                clearTarget = .favourites
                            }
                            .textCase(nil)
                        }
                    }
                } footer: {
                    if shouldShowFavouriteReorderHint && favourites.count >= 2 {
                        Text(AppLocalization.text("Tap Edit to rearrange favourites.", locale: locale))
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
                                    Label(AppLocalization.text("Delete", locale: locale), systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(AppLocalization.text("History", locale: locale))
                        Spacer()
                        if !history.isEmpty {
                            Button(AppLocalization.text("Clear", locale: locale)) {
                                clearTarget = .history
                            }
                                .textCase(nil)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle(AppLocalization.text("Saved Places", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !favourites.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(AppLocalization.text(editMode.isEditing ? "Done" : "Edit", locale: locale)) {
                            if !editMode.isEditing {
                                onDismissFavouriteReorderHint()
                            }
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                            .accessibilityLabel(AppLocalization.text("Reorder favourites", locale: locale))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLocalization.text("Done", locale: locale)) { dismiss() }
                }
            }
            .alert(
                AppLocalization.text("Rename Favourite", locale: locale),
                isPresented: Binding(
                    get: { favouriteBeingRenamed != nil },
                    set: { if !$0 { favouriteBeingRenamed = nil } }
                )
            ) {
                TextField(AppLocalization.text("Favourite name", locale: locale), text: $favouriteName)
                Button(AppLocalization.text("Cancel", locale: locale), role: .cancel) {
                    favouriteBeingRenamed = nil
                }
                Button(AppLocalization.text("Save", locale: locale)) {
                    guard let favouriteBeingRenamed else { return }
                    onRenameFavourite(favouriteBeingRenamed, favouriteName)
                    self.favouriteBeingRenamed = nil
                }
                .disabled(favouriteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text(AppLocalization.text("Give this saved place a name that is easy to recognise.", locale: locale))
            }
            .confirmationDialog(
                AppLocalization.text(clearConfirmationTitle, locale: locale),
                isPresented: Binding(
                    get: { clearTarget != nil },
                    set: { if !$0 { clearTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(AppLocalization.text(clearConfirmationButton, locale: locale), role: .destructive) {
                    performClear()
                }
                Button(AppLocalization.text("Cancel", locale: locale), role: .cancel) {
                    clearTarget = nil
                }
            } message: {
                Text(AppLocalization.text(clearConfirmationMessage, locale: locale))
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
    @Environment(\.locale) private var locale
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
                        Text(location.displayName(locale: locale))
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        Text(location.displaySubtitle(locale: locale))
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
            .accessibilityHint(AppLocalization.text("Selects this location", locale: locale))

            Button(action: onToggleFavourite) {
                Image(systemName: isFavourite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavourite ? .pink : .secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppLocalization.text(isFavourite ? "Remove from favourites" : "Add to favourites", locale: locale))
        }
    }

    private var locationAccessibilityLabel: String {
        guard !location.subtitle.isEmpty else { return location.displayName(locale: locale) }
        return "\(location.displayName(locale: locale)), \(location.displaySubtitle(locale: locale))"
    }
}

private struct EmptySavedPlacesRow: View {
    @Environment(\.locale) private var locale
    let symbol: String
    let message: String

    var body: some View {
        Label(AppLocalization.text(message, locale: locale), systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }
}

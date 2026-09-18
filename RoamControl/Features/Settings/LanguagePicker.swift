import SwiftUI

struct LanguagePicker: View {
    @Environment(\.locale) private var locale
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.automatic.rawValue

    var body: some View {
        Menu {
            Picker(AppLocalization.text("Language", locale: locale), selection: $language) {
                ForEach(AppLanguage.allCases) { option in
                    Text(AppLocalization.text(option.title, locale: locale))
                        .tag(option.rawValue)
                }
            }
        } label: {
            HStack {
                Label(AppLocalization.text("Language", locale: locale), systemImage: "globe")
                Spacer()
                Text(AppLocalization.text((AppLanguage(rawValue: language) ?? .automatic).title, locale: locale))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier("app-language-picker")
    }
}

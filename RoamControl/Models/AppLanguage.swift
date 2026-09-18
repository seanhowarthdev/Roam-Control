import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case automatic
    case chinese = "zh-Hans"
    case english = "en"

    static let preferenceKey = "appLanguage"
    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: "Follow System"
        case .chinese: "简体中文"
        case .english: "English"
        }
    }

    var locale: Locale {
        switch self {
        case .automatic: .current
        case .chinese: Locale(identifier: "zh-Hans")
        case .english: Locale(identifier: "en")
        }
    }

    static func load(from preferences: UserDefaults = .standard) -> Self {
        Self(rawValue: preferences.string(forKey: preferenceKey) ?? "") ?? .automatic
    }

    func save(in preferences: UserDefaults = .standard) {
        preferences.set(rawValue, forKey: Self.preferenceKey)
    }
}

/// Translates at the display boundary. Stored names, error messages and session
/// state retain their original values so connection/error classification is unchanged.
enum AppLocalization {
    private struct Template {
        let expression: NSRegularExpression
        let translation: String
    }

    private struct Catalog {
        let strings: [String: String]
        let templates: [Template]

        init(bundle: Bundle) {
            let url = bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "zh-Hans")
            let data = url.flatMap { try? Data(contentsOf: $0) }
            let entries: [String: String] = data.flatMap {
                (try? PropertyListSerialization.propertyList(from: $0, options: [], format: nil)) as? [String: String]
            } ?? [:]
            strings = entries
            templates = entries.keys.filter { $0.contains("%@") }
                .sorted { $0.count > $1.count }
                .compactMap { key in
                    let pattern = key.components(separatedBy: "%@")
                        .map(NSRegularExpression.escapedPattern(for:))
                        .joined(separator: "(.+?)")
                    guard let expression = try? NSRegularExpression(pattern: "\\A" + pattern + "\\z", options: [.dotMatchesLineSeparators]),
                          let translation = entries[key] else { return nil }
                    return Template(expression: expression, translation: translation)
                }
        }
    }

    private static let mainCatalog = Catalog(bundle: .main)

    /// Keep the existing region's distance units when changing their language.
    static func measurementLocale(
        for locale: Locale,
        region: String = Locale.current.region?.identifier ?? "US"
    ) -> Locale {
        if region == Locale.current.region?.identifier,
           locale.language.languageCode == Locale.current.language.languageCode {
            return .current
        }
        return Locale(identifier: "\(locale.language.languageCode?.identifier ?? "en")_\(region)")
    }

    /// Display wording only: protocol names and failure matching remain unchanged.
    static func brandedText(_ value: String) -> String {
        var result = value
        result = result.replacingOccurrences(of: "Roam Control", with: "Cat Go")
        result = result.replacingOccurrences(of: "ROAM CONTROL", with: "CAT GO")
        result = result.replacingOccurrences(of: "Built-in Local VPN", with: "Device Connection")
        result = result.replacingOccurrences(of: "Connecting Built-in VPN", with: "Connecting Device")
        result = result.replacingOccurrences(of: "Connect Local VPN", with: "Connect Device")
        result = result.replacingOccurrences(of: "built-in local tunnel", with: "device connection")
        result = result.replacingOccurrences(of: "private local tunnel", with: "device connection")
        result = result.replacingOccurrences(of: "built-in local VPN", with: "device connection")
        result = result.replacingOccurrences(of: "built-in VPN", with: "device connection")
        result = result.replacingOccurrences(of: "local VPN", with: "device connection")
        result = result.replacingOccurrences(of: "local tunnel", with: "device connection")
        result = result.replacingOccurrences(of: "secure device tunnel", with: "secure device connection")
        result = result.replacingOccurrences(of: "secure tunnel", with: "secure connection")
        result = result.replacingOccurrences(of: "encrypted device tunnel", with: "encrypted device connection")
        result = result.replacingOccurrences(of: "tunnel", with: "connection")
        result = result.replacingOccurrences(of: "LocalDevVPN", with: "Device Connection")
        result = result.replacingOccurrences(of: "内置本地隧道", with: "设备连接")
        result = result.replacingOccurrences(of: "私密本地隧道", with: "设备连接")
        result = result.replacingOccurrences(of: "内置本地 VPN", with: "设备连接")
        result = result.replacingOccurrences(of: "内置 VPN", with: "设备连接")
        result = result.replacingOccurrences(of: "本地 VPN", with: "设备连接")
        result = result.replacingOccurrences(of: "本地隧道", with: "设备连接")
        result = result.replacingOccurrences(of: "安全设备隧道", with: "安全设备连接")
        result = result.replacingOccurrences(of: "安全隧道", with: "安全连接")
        result = result.replacingOccurrences(of: "加密隧道", with: "加密连接")
        result = result.replacingOccurrences(of: "隧道", with: "连接")
        return result
    }

    static func text(_ value: String, locale: Locale, bundle: Bundle = .main) -> String {
        brandedText(localizedText(value, locale: locale, bundle: bundle))
    }

    private static func localizedText(_ value: String, locale: Locale, bundle: Bundle) -> String {
        guard locale.language.languageCode?.identifier == "zh" else { return value }
        let catalog = bundle.bundleURL == Bundle.main.bundleURL ? mainCatalog : Catalog(bundle: bundle)
        if let translated = catalog.strings[value] { return translated }
        for template in catalog.templates {
            guard let match = template.expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { continue }
            let parts = template.translation.components(separatedBy: "%@")
            guard parts.count == match.numberOfRanges else { continue }
            var result = parts[0]
            for index in 1..<match.numberOfRanges {
                guard let range = Range(match.range(at: index), in: value) else { return value }
                result += String(value[range]) + parts[index]
            }
            return result
        }
        return value
    }
}

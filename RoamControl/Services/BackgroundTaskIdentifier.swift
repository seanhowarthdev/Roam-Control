import Foundation

enum BackgroundTaskIdentifier {
    static func prefix(for component: String) -> String {
        let wildcardSuffix = ".\(component).*"
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.sean.roamcontrol"

        if let permittedIdentifiers = Bundle.main.object(
            forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers"
        ) as? [String] {
            let matchingIdentifier = permittedIdentifiers.first(where: {
                $0.hasPrefix("\(bundleIdentifier).") && $0.hasSuffix(wildcardSuffix)
            })
            let fallbackIdentifier = permittedIdentifiers.first(where: {
                $0.hasSuffix(wildcardSuffix)
            })

            if let wildcardIdentifier = matchingIdentifier ?? fallbackIdentifier {
                return String(wildcardIdentifier.dropLast(2))
            }
        }

        return "\(bundleIdentifier).\(component)"
    }
}

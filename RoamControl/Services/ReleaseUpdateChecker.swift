import Foundation

struct PublishedRelease: Sendable {
    let version: String
    let name: String
    let releaseURL: URL
}

enum ReleaseUpdateStatus: Equatable {
    case idle
    case checking
    case updateAvailable(PublishedRelease)
    case current(PublishedRelease)
    case newerLocalBuild(PublishedRelease)
    case noPublishedRelease
    case unavailable
}

extension ReleaseUpdateStatus {
    static func == (lhs: ReleaseUpdateStatus, rhs: ReleaseUpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.noPublishedRelease, .noPublishedRelease), (.unavailable, .unavailable):
            true
        case let (.updateAvailable(left), .updateAvailable(right)),
             let (.current(left), .current(right)),
             let (.newerLocalBuild(left), .newerLocalBuild(right)):
            left.version == right.version && left.releaseURL == right.releaseURL
        default:
            false
        }
    }
}

struct ReleaseUpdateChecker {
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/seanhowarthdev/Roam-Control/releases/latest"
    )!

    func latestRelease() async throws -> PublishedRelease {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ReleaseUpdateCheckError.unavailable
        }
        guard response.statusCode == 200 else {
            throw response.statusCode == 404
                ? ReleaseUpdateCheckError.noPublishedRelease
                : ReleaseUpdateCheckError.unavailable
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let releaseURL = URL(string: release.htmlURL) else {
            throw ReleaseUpdateCheckError.unavailable
        }

        return PublishedRelease(
            version: release.tagName,
            name: release.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? release.name!
                : release.tagName,
            releaseURL: releaseURL
        )
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let name: String?
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
        }
    }

}

enum ReleaseUpdateCheckError: Error {
    case noPublishedRelease
    case unavailable
}

enum VersionComparison {
    static func isRemoteVersionNewer(_ remoteVersion: String, than localVersion: String) -> Bool {
        let remote = components(from: remoteVersion)
        let local = components(from: localVersion)
        let length = max(remote.count, local.count)

        for index in 0..<length {
            let remoteValue = index < remote.count ? remote[index] : 0
            let localValue = index < local.count ? local[index] : 0
            if remoteValue != localValue { return remoteValue > localValue }
        }

        return remoteVersion.lowercased().contains("beta") == false
            && localVersion.lowercased().contains("beta")
    }

    private static func components(from value: String) -> [Int] {
        value
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }
}

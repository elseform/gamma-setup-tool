import Foundation

/// The subset of GitHub's release API this tool reads. Matches what
/// `gamma-wine-engine/scripts/publish-release.sh` actually publishes: a tag
/// `engine-<engineId>-<N>`, with the archive, its `.sha256` and its
/// `.manifest.json` as assets.
public struct GitHubReleaseAsset: Codable, Equatable {
    public var name: String
    public var browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }

    public init(name: String, browserDownloadURL: String) {
        self.name = name
        self.browserDownloadURL = browserDownloadURL
    }
}

public struct GitHubRelease: Codable, Equatable {
    public var tagName: String
    public var assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }

    public init(tagName: String, assets: [GitHubReleaseAsset]) {
        self.tagName = tagName
        self.assets = assets
    }
}

/// A resolved engine release: its version, and where to get the archive plus
/// the manifest that names its expected checksum.
public struct ResolvedEngineRelease: Equatable {
    public let version: EngineBuildVersion
    public let archiveName: String
    public let archiveURL: URL
    public let sha256URL: URL
    public let manifestURL: URL
}

public enum EngineReleaseResolverError: Error, CustomStringConvertible, LocalizedError {
    case network(String)
    case noEngineReleases
    case malformedRelease(String)

    public var description: String {
        switch self {
        case .network(let message): return "could not reach GitHub: \(message)"
        case .noEngineReleases: return "no engine-* release found in elseform/gamma-wine-engine"
        case .malformedRelease(let tag): return "release \(tag) is missing its archive, .sha256 or .manifest.json asset"
        }
    }

    public var errorDescription: String? { description }
}

/// Fetches and picks the newest published engine release.
///
/// Deliberately lists `/releases` and filters `tag_name` by the `engine-`
/// prefix rather than calling `/releases/latest`: `publish-release.sh` marks
/// releases neither `--latest` nor `--prerelease`, so GitHub's own "latest"
/// heuristic could hand back an unrelated tag, or a release marked prerelease
/// could otherwise lower the floor unexpectedly. Ordering by `max(by:)` with
/// `EngineBuildVersion`'s comparator (not array/tag-string order) also avoids
/// the trap where the string `"engine-...-7"` sorts after `"engine-...-10"`.
public enum EngineReleaseResolver {
    public typealias Transport = (URL) async throws -> Data

    public static let defaultReleasesURL = URL(string: "https://api.github.com/repos/elseform/gamma-wine-engine/releases?per_page=30")!

    /// `GAMMA_ENGINE_RELEASES_URL` replaces the GitHub listing URL. The CLI
    /// tests point it at an unreachable address so they never download a real
    /// engine; it is not a user-facing setting.
    public static var releasesURL: URL {
        if let override = ProcessInfo.processInfo.environment["GAMMA_ENGINE_RELEASES_URL"],
           let url = URL(string: override) {
            return url
        }
        return defaultReleasesURL
    }

    /// False while `GAMMA_ENGINE_RELEASES_URL` points somewhere else. A
    /// substitute listing is not the real release history, so it must not
    /// raise this machine's cached version floor.
    public static var isUsingDefaultReleasesURL: Bool {
        releasesURL == defaultReleasesURL
    }

    public static func urlSessionTransport(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw EngineReleaseResolverError.network("HTTP \(http.statusCode)")
        }
        return data
    }

    /// Parses a release listing (as returned by `releasesURL`) into the newest
    /// valid engine release. Separated from the network fetch so it is
    /// testable against a fixture with no transport at all.
    public static func newestEngineRelease(in releases: [GitHubRelease]) throws -> ResolvedEngineRelease {
        var best: (release: GitHubRelease, resolved: ResolvedEngineRelease)?
        for release in releases where release.tagName.hasPrefix("engine-") {
            guard let resolved = try? resolve(release) else { continue }
            if best == nil || resolved.version > best!.resolved.version {
                best = (release, resolved)
            }
        }
        guard let best else { throw EngineReleaseResolverError.noEngineReleases }
        return best.resolved
    }

    private static func resolve(_ release: GitHubRelease) throws -> ResolvedEngineRelease {
        guard let archive = release.assets.first(where: {
            $0.name.hasSuffix(".tar.zst") || $0.name.hasSuffix(".tar.xz")
        }) else {
            throw EngineReleaseResolverError.malformedRelease(release.tagName)
        }
        guard let sha256 = release.assets.first(where: { $0.name == archive.name + ".sha256" }),
              let manifest = release.assets.first(where: { $0.name == archive.name + ".manifest.json" }),
              let archiveURL = URL(string: archive.browserDownloadURL),
              let sha256URL = URL(string: sha256.browserDownloadURL),
              let manifestURL = URL(string: manifest.browserDownloadURL) else {
            throw EngineReleaseResolverError.malformedRelease(release.tagName)
        }
        // The build counter is parsed from the archive filename here; the
        // manifest (fetched and cross-checked separately, once the archive is
        // downloaded) is the source of truth once it is in hand.
        guard let counter = EngineVersionParser.parseBuildCounter(fromName: archive.name),
              let labelParts = EngineVersionParser.parseLabel(release.tagName.replacingOccurrences(of: "engine-", with: "")) else {
            throw EngineReleaseResolverError.malformedRelease(release.tagName)
        }
        let version = EngineBuildVersion(
            crossover: labelParts.crossover,
            wineMajor: labelParts.wineMajor,
            gamma: labelParts.gamma,
            build: counter,
            family: EngineVersionParser.parseFamily(fromName: archive.name)
        )
        return ResolvedEngineRelease(
            version: version,
            archiveName: archive.name,
            archiveURL: archiveURL,
            sha256URL: sha256URL,
            manifestURL: manifestURL
        )
    }

    /// Fetches the release listing and resolves the newest engine release.
    /// Anonymous GitHub API calls are rate-limited per IP (60/h); one resolve
    /// per setup run stays well inside that.
    public static func fetchNewest(transport: @escaping Transport = urlSessionTransport) async throws -> ResolvedEngineRelease {
        let data: Data
        do {
            data = try await transport(releasesURL)
        } catch let error as EngineReleaseResolverError {
            throw error
        } catch {
            throw EngineReleaseResolverError.network(error.localizedDescription)
        }
        let releases: [GitHubRelease]
        do {
            releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
        } catch {
            throw EngineReleaseResolverError.network("malformed release listing: \(error.localizedDescription)")
        }
        return try newestEngineRelease(in: releases)
    }
}

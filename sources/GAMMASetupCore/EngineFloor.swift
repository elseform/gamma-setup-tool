import Foundation

/// A cached record of the last release successfully resolved from GitHub,
/// so the floor it set keeps applying once a machine has been online, even
/// on a later offline run.
struct CachedEngineRelease: Codable {
    let crossover: [Int]
    let wineMajor: Int
    let gamma: Int
    let build: Int
    let resolvedAt: Date

    var version: EngineBuildVersion {
        EngineBuildVersion(crossover: crossover, wineMajor: wineMajor, gamma: gamma, build: build)
    }

    init(version: EngineBuildVersion, resolvedAt: Date = Date()) {
        crossover = version.crossover
        wineMajor = version.wineMajor
        gamma = version.gamma
        build = version.build
        self.resolvedAt = resolvedAt
    }
}

/// The version floor an engine archive is held to: the highest of whatever
/// GitHub reports right now, whatever was cached from the last time it did,
/// and the compiled-in minimum. Taking the max of all three, rather than just
/// the live value, is what makes the floor unfalsifiable by going offline —
/// once a machine has seen a newer release, it keeps enforcing that bar even
/// disconnected.
public struct EngineFloor {
    public let version: EngineBuildVersion
    public let source: Source

    public enum Source: Equatable {
        case liveRelease
        case cachedRelease
        case compiledMinimum
    }

    public static let cacheFileName = "latest-release.json"

    public static func cacheURL(cacheDirectory: URL) -> URL {
        cacheDirectory.appendingPathComponent(cacheFileName)
    }

    static func readCache(cacheDirectory: URL) -> CachedEngineRelease? {
        guard let data = try? Data(contentsOf: cacheURL(cacheDirectory: cacheDirectory)) else { return nil }
        return try? JSONDecoder().decode(CachedEngineRelease.self, from: data)
    }

    static func writeCache(_ release: CachedEngineRelease, cacheDirectory: URL) {
        guard let data = try? JSONEncoder().encode(release) else { return }
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: cacheURL(cacheDirectory: cacheDirectory), options: .atomic)
    }

    static var compiledMinimum: EngineBuildVersion {
        SetupDefaults.minimumSupportedEngine
    }

    /// The pure part: given what is live (if the network call succeeded),
    /// what is cached, and the compiled minimum, which one sets the floor.
    /// Taking `max` over all three — not just the live value — is what makes
    /// the floor unfalsifiable by going offline: once a machine has seen a
    /// newer release, a later disconnected run still enforces that bar.
    static func compute(live: EngineBuildVersion?, cached: EngineBuildVersion?, compiledMinimum: EngineBuildVersion) -> EngineFloor {
        if let live {
            let floor = max(live, cached ?? compiledMinimum, compiledMinimum)
            return EngineFloor(version: floor, source: floor == live ? .liveRelease : .cachedRelease)
        }
        if let cached {
            let floor = max(cached, compiledMinimum)
            return EngineFloor(version: floor, source: floor == cached ? .cachedRelease : .compiledMinimum)
        }
        return EngineFloor(version: compiledMinimum, source: .compiledMinimum)
    }

    /// Resolves against GitHub, caching a fresh result and falling back to
    /// whatever is cached (or the compiled minimum) when that fails.
    public static func resolve(
        cacheDirectory: URL,
        fetchNewest: @escaping EngineReleaseResolver.Transport = EngineReleaseResolver.urlSessionTransport
    ) async -> EngineFloor {
        let cached = readCache(cacheDirectory: cacheDirectory)
        let live = try? await EngineReleaseResolver.fetchNewest(transport: fetchNewest)
        if let live {
            writeCache(CachedEngineRelease(version: live.version), cacheDirectory: cacheDirectory)
        }
        return compute(live: live?.version, cached: cached?.version, compiledMinimum: compiledMinimum)
    }
}

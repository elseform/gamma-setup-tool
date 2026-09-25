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
    /// `source` names whichever input the floor actually came from; on a tie
    /// the live release wins, then the cache.
    static func compute(live: EngineBuildVersion?, cached: EngineBuildVersion?, compiledMinimum: EngineBuildVersion) -> EngineFloor {
        let candidates: [(version: EngineBuildVersion?, source: Source)] = [
            (live, .liveRelease),
            (cached, .cachedRelease),
            (compiledMinimum, .compiledMinimum),
        ]
        var floor = EngineFloor(version: compiledMinimum, source: .compiledMinimum)
        var found = false
        for candidate in candidates {
            guard let version = candidate.version else { continue }
            if !found || version > floor.version {
                floor = EngineFloor(version: version, source: candidate.source)
                found = true
            }
        }
        return floor
    }

    /// Resolves against GitHub, falling back to whatever is cached (or the
    /// compiled minimum) when that fails.
    public static func resolve(
        cacheDirectory: URL,
        fetchNewest: @escaping EngineReleaseResolver.Transport = EngineReleaseResolver.urlSessionTransport
    ) async -> EngineFloor {
        let live = try? await EngineReleaseResolver.fetchNewest(transport: fetchNewest)
        return resolve(cacheDirectory: cacheDirectory, live: live?.version)
    }

    /// Same, for a caller that already fetched the newest release — so a run
    /// that downloads it does not ask GitHub twice. The cache only ever moves
    /// up: a live answer older than what this machine already saw (a release
    /// taken down, say) never lowers the floor a later offline run enforces.
    /// A substitute release listing (see `EngineReleaseResolver.releasesURL`)
    /// still sets this run's floor but is never cached.
    public static func resolve(
        cacheDirectory: URL,
        live: EngineBuildVersion?,
        recordsLiveRelease: Bool = EngineReleaseResolver.isUsingDefaultReleasesURL
    ) -> EngineFloor {
        let cached = readCache(cacheDirectory: cacheDirectory)?.version
        if recordsLiveRelease, let live, cached.map({ live > $0 }) ?? true {
            writeCache(CachedEngineRelease(version: live), cacheDirectory: cacheDirectory)
        }
        return compute(live: live, cached: cached, compiledMinimum: compiledMinimum)
    }
}

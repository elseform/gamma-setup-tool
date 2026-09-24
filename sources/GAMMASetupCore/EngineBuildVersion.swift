import Foundation

/// An engine build, ordered so "is this archive older than the current one?"
/// has one answer.
///
/// Ordering is CrossOver version, then Wine major, then the GAMMA counter,
/// then the build counter. `family` (`GAMMA-DXMT` for DXMT-only builds, the
/// GPTK-named form otherwise) is metadata and is deliberately not ordered:
/// switching payload families does not make a build newer or older.
public struct EngineBuildVersion: Comparable, CustomStringConvertible {
    public let crossover: [Int]
    public let wineMajor: Int
    public let gamma: Int
    public let build: Int
    public let family: String?
    public let label: String?

    public init(crossover: [Int], wineMajor: Int, gamma: Int, build: Int, family: String? = nil, label: String? = nil) {
        self.crossover = crossover
        self.wineMajor = wineMajor
        self.gamma = gamma
        self.build = build
        self.family = family
        self.label = label
    }

    public var description: String {
        let cx = crossover.map(String.init).joined(separator: ".")
        return "CX\(cx)-W\(wineMajor)-Gamma\(gamma) build \(build)"
    }

    private var ordering: [Int] {
        // The engineId slug says "26.3" where the label says "26.3.0"; pad so
        // the two forms of the same version compare equal.
        var padded = crossover
        while padded.count < 3 { padded.append(0) }
        return Array(padded.prefix(3)) + [wineMajor, gamma, build]
    }

    /// Hand-written on purpose. A synthesised `Equatable` would also compare
    /// `family` and `label`, so two builds could be unequal while neither is
    /// less than the other — that breaks strict weak ordering and silently
    /// corrupts `sorted()` and `max()`.
    public static func == (lhs: EngineBuildVersion, rhs: EngineBuildVersion) -> Bool {
        lhs.ordering == rhs.ordering
    }

    public static func < (lhs: EngineBuildVersion, rhs: EngineBuildVersion) -> Bool {
        let left = lhs.ordering
        let right = rhs.ordering
        for (l, r) in zip(left, right) where l != r {
            return l < r
        }
        return false
    }
}

public enum EngineVersionParseError: Error, CustomStringConvertible, LocalizedError {
    case unreadableLabel(String)
    case unknownBuildNumber(String)

    public var description: String {
        switch self {
        case .unreadableLabel(let value):
            return "cannot read an engine version from \"\(value)\""
        case .unknownBuildNumber(let value):
            return "cannot tell which build \"\(value)\" is; refusing rather than assuming it is the oldest"
        }
    }

    public var errorDescription: String? { description }
}

public enum EngineVersionParser {
    /// `CX26.3.0-W11-Gamma087` or the `cx26.3-w11-gamma087` slug.
    public static func parseLabel(_ raw: String) -> (crossover: [Int], wineMajor: Int, gamma: Int)? {
        let parts = raw.lowercased().split(separator: "-")
        guard parts.count >= 3 else { return nil }
        guard parts[0].hasPrefix("cx"), parts[1].hasPrefix("w") else { return nil }
        let crossover = parts[0].dropFirst(2).split(separator: ".").compactMap { Int($0) }
        guard !crossover.isEmpty, let wineMajor = Int(parts[1].dropFirst(1)) else { return nil }
        guard let gammaPart = parts.first(where: { $0.hasPrefix("gamma") }),
              let gamma = Int(gammaPart.dropFirst("gamma".count)) else { return nil }
        return (crossover, wineMajor, gamma)
    }

    /// The trailing `-<N>` of an archive name or release tag, with or without
    /// a compression suffix: `CX26W11-GAMMA-DXMT-14.tar.zst`,
    /// `CX26W11Gamma086-4.tar.xz`, `engine-cx26.3-w11-gamma087-14`.
    public static func parseBuildCounter(fromName name: String) -> Int? {
        var stem = name
        for suffix in [".tar.zst", ".tar.xz"] where stem.hasSuffix(suffix) {
            stem = String(stem.dropLast(suffix.count))
        }
        guard let dash = stem.lastIndex(of: "-") else { return nil }
        return Int(stem[stem.index(after: dash)...])
    }

    /// The payload family an archive name encodes, e.g. `GAMMA-DXMT`. Metadata
    /// only; it takes no part in ordering.
    public static func parseFamily(fromName name: String) -> String? {
        name.contains("GAMMA-DXMT") ? "GAMMA-DXMT" : nil
    }

    /// Build a version from a manifest plus the name it was found under.
    /// `buildNumber` in the manifest wins; otherwise the counter comes from the
    /// archive name (or release tag). An unknown counter is a refusal, never 0.
    public static func version(
        manifest: EngineManifest,
        name: String?
    ) throws -> EngineBuildVersion {
        let labelSource = manifest.versionLabel ?? manifest.engineId ?? ""
        guard let parsed = parseLabel(labelSource) else {
            throw EngineVersionParseError.unreadableLabel(labelSource)
        }
        let build: Int
        if let recorded = manifest.buildNumber {
            build = recorded
        } else if let name, let counter = parseBuildCounter(fromName: name) {
            build = counter
        } else {
            throw EngineVersionParseError.unknownBuildNumber(name ?? labelSource)
        }
        return EngineBuildVersion(
            crossover: parsed.crossover,
            wineMajor: parsed.wineMajor,
            gamma: parsed.gamma,
            build: build,
            family: name.flatMap(parseFamily(fromName:)),
            label: manifest.versionLabel
        )
    }
}

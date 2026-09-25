import Foundation

/// A published engine build, ordered so "which release is newest?" has one
/// answer: CrossOver version, then Wine major, then the GAMMA counter, then
/// the build counter.
public struct EngineBuildVersion: Comparable, CustomStringConvertible {
    public let crossover: [Int]
    public let wineMajor: Int
    public let gamma: Int
    public let build: Int

    public init(crossover: [Int], wineMajor: Int, gamma: Int, build: Int) {
        self.crossover = crossover
        self.wineMajor = wineMajor
        self.gamma = gamma
        self.build = build
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

    /// Hand-written so the padded forms compare equal, consistent with `<`.
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
}

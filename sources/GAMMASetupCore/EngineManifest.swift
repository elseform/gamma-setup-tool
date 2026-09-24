import Foundation

/// `engine-manifest.json`, in both shapes gamma-wine-engine writes: the copy
/// inside the archive (which nulls `artifact`/`artifactSHA256`) and the
/// `<archive>.manifest.json` sidecar next to a release asset.
///
/// Everything except the schema version is optional: older archives predate
/// `buildNumber` and `minimumMacOS`, and the setup tool must be able to read
/// and judge them rather than fail to decode.
public struct EngineManifest: Codable, Equatable {
    public var schemaVersion: Int
    public var engineId: String?
    public var versionLabel: String?
    public var buildNumber: Int?
    public var minimumMacOS: String?
    public var minimumSetupToolVersion: String?
    public var artifact: String?
    public var artifactSHA256: String?
    public var ntdllSHA256: String?
    public var notes: String?

    public init(
        schemaVersion: Int = 1,
        engineId: String? = nil,
        versionLabel: String? = nil,
        buildNumber: Int? = nil,
        minimumMacOS: String? = nil,
        minimumSetupToolVersion: String? = nil,
        artifact: String? = nil,
        artifactSHA256: String? = nil,
        ntdllSHA256: String? = nil,
        notes: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.engineId = engineId
        self.versionLabel = versionLabel
        self.buildNumber = buildNumber
        self.minimumMacOS = minimumMacOS
        self.minimumSetupToolVersion = minimumSetupToolVersion
        self.artifact = artifact
        self.artifactSHA256 = artifactSHA256
        self.ntdllSHA256 = ntdllSHA256
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> EngineManifest {
        let manifest = try JSONDecoder().decode(EngineManifest.self, from: data)
        guard manifest.schemaVersion >= 1 else {
            throw WineEngineSetupError.message(
                "engine manifest schemaVersion \(manifest.schemaVersion) is not supported"
            )
        }
        return manifest
    }
}

/// A dotted version ("15.0", "0.90", "26.3.0") compared component by
/// component, with missing components treated as zero.
public struct DottedVersion: Comparable, CustomStringConvertible {
    public let components: [Int]
    public let raw: String

    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        var values: [Int] = []
        for part in parts {
            guard let value = Int(part) else { return nil }
            values.append(value)
        }
        components = values
        self.raw = trimmed
    }

    public init(components: [Int]) {
        self.components = components
        raw = components.map(String.init).joined(separator: ".")
    }

    public var description: String { raw }

    private static func padded(_ lhs: [Int], _ rhs: [Int]) -> ([Int], [Int]) {
        let count = max(lhs.count, rhs.count)
        return (lhs + Array(repeating: 0, count: count - lhs.count),
                rhs + Array(repeating: 0, count: count - rhs.count))
    }

    public static func == (lhs: DottedVersion, rhs: DottedVersion) -> Bool {
        let (l, r) = padded(lhs.components, rhs.components)
        return l == r
    }

    public static func < (lhs: DottedVersion, rhs: DottedVersion) -> Bool {
        let (l, r) = padded(lhs.components, rhs.components)
        for (a, b) in zip(l, r) where a != b {
            return a < b
        }
        return false
    }

    public static var currentOperatingSystem: DottedVersion {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return DottedVersion(components: [version.majorVersion, version.minorVersion, version.patchVersion])
    }
}

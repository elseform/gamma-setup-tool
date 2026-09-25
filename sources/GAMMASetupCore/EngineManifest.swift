import Foundation

/// The `<archive>.manifest.json` sidecar published next to a release asset.
/// Only the checksum is read: the download is verified against it before it
/// is trusted. Every other key the manifest carries is ignored.
public struct EngineManifest: Codable, Equatable {
    public var schemaVersion: Int
    public var artifact: String?
    public var artifactSHA256: String?

    public init(schemaVersion: Int = 1, artifact: String? = nil, artifactSHA256: String? = nil) {
        self.schemaVersion = schemaVersion
        self.artifact = artifact
        self.artifactSHA256 = artifactSHA256
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

import Foundation

/// The Microsoft installers the engine's redist manifest pins.
///
/// The manifest itself lives inside the engine archive
/// (`share/gamma/redist-manifest.json`) and is the only thing that decides
/// what is actually fetched — `interactive_setup.py` reads it and calls the
/// engine's own `gamma_redist.install(...)`. This list exists purely so the
/// GUI can say, before any archive has been extracted, which installers are
/// already on disk and which will have to be downloaded. Keep it in step with
/// `gamma-wine-engine/scripts/write-redist-manifest.py`; being wrong here
/// mislabels a row, it cannot install the wrong file.
public enum RedistInstallers {
    public struct Installer: Equatable {
        public let filename: String
        public let title: String
        public let sizeLabel: String

        public init(filename: String, title: String, sizeLabel: String) {
            self.filename = filename
            self.title = title
            self.sizeLabel = sizeLabel
        }
    }

    public struct Status: Equatable {
        public let installer: Installer
        /// Where it was found, or nil when it would have to be downloaded.
        public let location: URL?

        public var isPresent: Bool { location != nil }

        public init(installer: Installer, location: URL?) {
            self.installer = installer
            self.location = location
        }
    }

    public static let all: [Installer] = [
        Installer(
            filename: "VC_redist.x64.exe",
            title: "Visual C++ 2015-2022 Redistributable (x64)",
            sizeLabel: "24 MB"
        ),
        Installer(
            filename: "directx_Jun2010_redist.exe",
            title: "DirectX End-User Runtime (June 2010)",
            sizeLabel: "96 MB"
        ),
        Installer(
            filename: "d3dcompiler_47.dll",
            title: "Direct3D HLSL compiler (mozilla/fxc2 build)",
            sizeLabel: "4 MB"
        ),
    ]

    /// Where downloaded installers are kept, next to the engine-archive cache.
    public static var cacheDirectory: URL {
        URL(fileURLWithPath: NSString(string: "~/Library/Application Support/gamma-setup-tool/cache/redist-installers")
            .expandingTildeInPath)
    }

    /// Resolve each installer against the same precedence the fetcher uses:
    /// a directory the user supplied wins over the cache, and only what is in
    /// neither has to be downloaded.
    ///
    /// Pure apart from the existence checks, and synchronous, so it stays
    /// testable and cheap enough to call from a `.task`.
    public static func statuses(
        userDirectory: String,
        cacheDirectory: URL = RedistInstallers.cacheDirectory,
        fileManager: FileManager = .default
    ) -> [Status] {
        var searchPaths: [URL] = []
        let trimmed = userDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            searchPaths.append(URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath))
        }
        searchPaths.append(cacheDirectory)

        return all.map { installer in
            let found = searchPaths
                .map { $0.appendingPathComponent(installer.filename) }
                .first { fileManager.fileExists(atPath: $0.path) }
            return Status(installer: installer, location: found)
        }
    }
}

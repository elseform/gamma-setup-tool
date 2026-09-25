import Foundation

/// Reads `wswine.bundle/engine-manifest.json` out of a packed engine archive
/// without extracting it. `/usr/bin/tar -xOf` streams a single member straight
/// out of the archive in well under a second on a 130 MB archive — much
/// cheaper than unpacking to probe. `.tar.xz` is decoded by `tar` itself;
/// `.tar.zst` is not (see `ZstdLocator`), so the located `zstd` binary's
/// directory is put on `tar`'s `PATH` for that case.
public enum EngineArchiveProbe {
    public static func readManifest(
        archiveURL: URL,
        tarPath: String = "/usr/bin/tar",
        zstd: URL? = ZstdLocator.locate()
    ) throws -> EngineManifest {
        var environment = ProcessInfo.processInfo.environment
        if ZstdLocator.isRequired(forArchiveNamed: archiveURL.lastPathComponent) {
            guard let zstd else {
                throw WineEngineSetupError.message(
                    "cannot read \(archiveURL.lastPathComponent): \(ZstdLocator.installHint)"
                )
            }
            let zstdDirectory = zstd.deletingLastPathComponent().path
            environment["PATH"] = [zstdDirectory, environment["PATH"] ?? "/usr/bin:/bin"].joined(separator: ":")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tarPath)
        process.arguments = ["-xOf", archiveURL.path, "wswine.bundle/engine-manifest.json"]
        process.environment = environment
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else {
            let errorText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw WineEngineSetupError.message(
                "could not read engine-manifest.json from \(archiveURL.lastPathComponent)"
                    + (errorText.isEmpty ? "" : ": \(errorText.trimmingCharacters(in: .whitespacesAndNewlines))")
            )
        }
        return try EngineManifest.decode(from: data)
    }
}

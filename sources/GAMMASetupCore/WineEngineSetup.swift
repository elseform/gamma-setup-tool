import Foundation

public enum WineEngineSetupError: Error, CustomStringConvertible, LocalizedError {
    case message(String)

    public var description: String {
        switch self {
        case .message(let message):
            return message
        }
    }

    // Without this, `.localizedDescription` (used by the GUI's error
    // logging) bridges to a generic NSError and silently drops the actual
    // message — CustomStringConvertible alone isn't consulted for that.
    public var errorDescription: String? { description }
}

/// Drives `interactive_setup.py` (this repo's own, at
/// sources/GAMMASetupTool/Resources/wine-engine/ — it builds the
/// gamma-wine-engine archive it consumes, but the script itself lives here)
/// as a subprocess and forwards its own `--json` event stream through
/// `reporter` verbatim — no text-banner-parsing translation layer needed,
/// since the script speaks this schema natively.
public final class WineEngineSetup {
    private let fileManager = FileManager.default
    private let executablePath: String
    private let reporter: JSONEventReporter

    public init(executablePath: String, reporter: JSONEventReporter) {
        self.executablePath = executablePath
        self.reporter = reporter
    }

    private var scriptRoot: URL {
        URL(fileURLWithPath: executablePath).deletingLastPathComponent()
    }

    private var appSupportDirectory: URL {
        URL(fileURLWithPath: NSString(string: "~/Library/Application Support/gamma-setup-tool").expandingTildeInPath)
    }

    // Dev-mode fallback: walk up from the running executable looking for
    // the checkout root (marked by Package.swift), instead of guessing a
    // fixed number of `..` hops. The Swift toolchain's build layout isn't
    // stable across versions — the classic native build system places the
    // executable at .build/debug/ (2 hops to the repo root), but the newer
    // one (default on Swift 6.4/swiftlang-6.4.0.34.1, per `swift build`'s
    // "[Pre-planning ...]" output here) nests it under
    // .build/out/Products/Debug/ (4 hops) — a fixed hop count silently
    // breaks under one or the other.
    private var devRepoRoot: URL? {
        var dir = scriptRoot
        for _ in 0..<8 {
            if fileManager.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { return nil }
            dir = parent
        }
        return nil
    }

    public func create(request: WineEngineSetupRequest) throws {
        let scriptURL = try locateScript()
        let cacheDir = appSupportDirectory.appendingPathComponent("cache/gamma-wine-engine")
        let archiveURL = try resolveArchive(request: request, cacheDir: cacheDir)
        let exeRelPath = try resolveExeRelPath(request: request)
        let pythonBin = try resolvePython3()

        var arguments: [String] = [
            scriptURL.path,
            "--json",
            "--archive", archiveURL.path,
            "--app-name", request.appName,
            "--app-parent", (request.appParent as NSString).expandingTildeInPath,
            "--gamma-root", (request.gammaRoot as NSString).expandingTildeInPath,
            "--exe-rel-path", exeRelPath,
            "--backend", request.backend,
            "--runtime-mode", request.runtimeMode,
        ]
        // The engine archive carries both the manifest and the fetcher, so
        // the only thing this side decides is where installers are cached and
        // whether the user already has copies of their own.
        arguments += ["--redist-cache-dir", RedistInstallers.cacheDirectory.path]
        let installerDirectory = (request.redistInstallerDirectory ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !installerDirectory.isEmpty {
            arguments += ["--redist-installer-dir", (installerDirectory as NSString).expandingTildeInPath]
        }
        if request.yes { arguments.append("--yes") }
        if request.dxmtOnly { arguments.append("--dxmt-only") }
        if request.skipFinderAlias { arguments.append("--skip-finder-alias") }
        if request.forceExe { arguments.append("--force-exe") }

        try runPython(pythonBin: pythonBin, arguments: arguments)

        if request.updateUSVFS {
            try updateUSVFSIfNeeded(request: request)
        }
    }

    // MARK: - USVFS

    /// MO2's own bundled usvfs_*.dll/exe live in MO2's install folder, not
    /// the Wine prefix — unrelated to which engine build runs it. Always
    /// checked (no user-facing toggle). `mo2Path` is the selected launch
    /// executable, which may be a custom one outside MO2, so USVFSUpdater
    /// only writes when that folder holds ModOrganizer.exe, and backs up
    /// MO2's differing originals before replacing them.
    private func updateUSVFSIfNeeded(request: WineEngineSetupRequest) throws {
        guard !request.mo2Path.isEmpty else { return }
        let launchDir = URL(fileURLWithPath: (request.mo2Path as NSString).expandingTildeInPath)
            .deletingLastPathComponent()
        guard fileManager.fileExists(atPath: launchDir.path) else { return }

        let source = try locateUSVFSSource(override: request.usvfsSource)
        switch try USVFSUpdater(fileManager: fileManager).update(modOrganizerDirectory: launchDir, from: source) {
        case .notModOrganizer(let dir):
            reporter.log("Skipping USVFS update: no \(USVFSUpdater.modOrganizerExecutableName) in \(dir.path)")
        case .upToDate:
            reporter.log("USVFS binaries already up to date")
        case .updated(let dir, let replaced, let backup):
            reporter.log("Updated USVFS binaries in \(dir.path): \(replaced.joined(separator: ", "))")
            if let backup {
                reporter.log("Previous USVFS binaries backed up to \(backup.path)")
            }
        }
    }

    private func locateUSVFSSource(override: String) throws -> URL {
        if !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        var candidates = [
            scriptRoot.appendingPathComponent("usvfs"),
            scriptRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/usvfs"),
            scriptRoot.appendingPathComponent("../../sources/GAMMASetupTool/Resources/usvfs"),
        ]
        if let devRepoRoot {
            candidates.append(devRepoRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/usvfs"))
        }
        for candidate in candidates where fileManager.fileExists(atPath: candidate.appendingPathComponent("usvfs_x64.dll").path) {
            return candidate
        }
        throw WineEngineSetupError.message("bundled usvfs binaries not found (expected at Resources/usvfs)")
    }

    // MARK: - Resource/archive resolution

    private func locateScript() throws -> URL {
        var candidates = [
            scriptRoot.appendingPathComponent("wine-engine/interactive_setup.py"),
            scriptRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/wine-engine/interactive_setup.py"),
            scriptRoot.appendingPathComponent("../../sources/GAMMASetupTool/Resources/wine-engine/interactive_setup.py"),
        ]
        if let devRepoRoot {
            candidates.append(devRepoRoot.appendingPathComponent("sources/GAMMASetupTool/Resources/wine-engine/interactive_setup.py"))
        }
        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
        throw WineEngineSetupError.message(
            "interactive_setup.py not found (expected bundled at Contents/Resources/wine-engine)"
        )
    }

    private func resolveArchive(request: WineEngineSetupRequest, cacheDir: URL) throws -> URL {
        if let archivePath = request.archivePath, !archivePath.isEmpty {
            let url = URL(fileURLWithPath: (archivePath as NSString).expandingTildeInPath)
            guard fileManager.fileExists(atPath: url.path) else {
                throw WineEngineSetupError.message("engine archive not found: \(url.path)")
            }
            return url
        }
        guard let releaseURLString = request.releaseArchiveURL, !releaseURLString.isEmpty,
              let releaseURL = URL(string: releaseURLString) else {
            throw WineEngineSetupError.message(
                "no local archivePath and no releaseArchiveURL given; one of the two is required"
            )
        }
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let dest = cacheDir.appendingPathComponent(releaseURL.lastPathComponent)
        if fileManager.fileExists(atPath: dest.path) {
            reporter.log("Using cached engine archive: \(dest.path)")
            return dest
        }
        reporter.log("Downloading engine archive: \(releaseURLString)")
        let data = try Data(contentsOf: releaseURL)
        try data.write(to: dest)
        return dest
    }

    /// MO2 is the primary/default launch target — not the raw game exe
    /// interactive_setup.py itself defaults to. `mo2Path` (the resolved
    /// ModOrganizer.exe path, same concept as the existing Sikarugir
    /// pipeline's `Preflight.mo2Path`) is expressed relative to
    /// `gammaRoot` and used as the exe-rel-path unless the caller supplies
    /// an explicit custom-exe override (advanced-settings escape hatch).
    private func resolveExeRelPath(request: WineEngineSetupRequest) throws -> String {
        if let override = request.exeRelPath, !override.isEmpty {
            return override
        }
        guard !request.mo2Path.isEmpty else {
            throw WineEngineSetupError.message(
                "mo2Path is required when exeRelPath is not explicitly overridden"
            )
        }
        let gammaRootURL = URL(fileURLWithPath: (request.gammaRoot as NSString).expandingTildeInPath)
            .resolvingSymlinksInPath()
        let mo2URL = URL(fileURLWithPath: (request.mo2Path as NSString).expandingTildeInPath)
            .resolvingSymlinksInPath()
        let gammaComponents = gammaRootURL.pathComponents
        let mo2Components = mo2URL.pathComponents
        guard mo2Components.count > gammaComponents.count,
              Array(mo2Components.prefix(gammaComponents.count)) == gammaComponents else {
            throw WineEngineSetupError.message(
                "mo2Path (\(mo2URL.path)) is not inside gammaRoot (\(gammaRootURL.path)); "
                + "pass an explicit exeRelPath override instead"
            )
        }
        return mo2Components[gammaComponents.count...].joined(separator: "/")
    }

    private func resolvePython3() throws -> String {
        for candidate in ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"] {
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        throw WineEngineSetupError.message("python3 not found (expected at /usr/bin/python3)")
    }

    // MARK: - Subprocess

    private func runPython(pythonBin: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonBin)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let decoder = JSONDecoder()
        var buffer = Data()
        var sawFailure = false
        var failureMessage = "interactive_setup.py failed"
        let newline = Data([0x0A])

        pipe.fileHandleForReading.readabilityHandler = { [reporter] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            buffer.append(chunk)
            while let range = buffer.range(of: newline) {
                let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                guard !lineData.isEmpty else { continue }
                if let event = try? decoder.decode(SetupEngineEvent.self, from: lineData) {
                    reporter.forward(event)
                    if event.type == .completed, event.success == false {
                        sawFailure = true
                        failureMessage = event.message ?? failureMessage
                    }
                } else if let text = String(data: lineData, encoding: .utf8) {
                    reporter.log(text)
                }
            }
        }

        try process.run()
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil

        if process.terminationStatus != 0 || sawFailure {
            throw WineEngineSetupError.message(failureMessage)
        }
    }
}

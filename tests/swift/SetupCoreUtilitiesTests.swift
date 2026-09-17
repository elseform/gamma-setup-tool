import Foundation

/// Salvaged from the deleted SetupEngineCoreTests.swift: the cases whose
/// subjects still exist in GAMMASetupCore's SetupCoreUtilities.swift after the
/// Sikarugir pipeline was replaced by gamma-wine-engine's create-wine-engine.
final class SetupCoreUtilitiesTests {
    func testAppendWordsSplitsSpacesAndCommas() {
        XCTAssertEqual(SetupPathTools.appendWords("corefonts,d3dx9 dxvk"), ["corefonts", "d3dx9", "dxvk"])
    }

    func testPathHelpers() throws {
        XCTAssertTrue(SetupPathTools.pathIsUnder("/tmp/root/child", parent: "/tmp/root"))
        XCTAssertTrue(SetupPathTools.pathIsUnder("/tmp/root", parent: "/tmp/root"))
        XCTAssertFalse(SetupPathTools.pathIsUnder("/tmp/rooted", parent: "/tmp/root"))
        XCTAssertEqual(SetupPathTools.commonParent("/Users/me/Games/GAMMA", "/Users/me/Games/Anomaly"), "/Users/me/Games")
        XCTAssertEqual(SetupPathTools.decodeModOrganizerIniValue(#"@ByteArray("Z:/Games/Anomaly")"#), "Z:/Games/Anomaly")
        XCTAssertEqual(SetupPathTools.windowsPathDrive(#"Z:\Games\Anomaly"#), "z")
        XCTAssertEqual(SetupPathTools.windowsPathRelative(#"Z:\Games\Anomaly"#), "Games/Anomaly")
        XCTAssertEqual(try SetupPathTools.nativeToWindowsPath("/Users/me/Games/GAMMA/ModOrganizer.exe", driveRoot: "/Users/me/Games", driveLetter: "g"), "G:/GAMMA/ModOrganizer.exe")
        XCTAssertEqual(SetupPathTools.windowsDirectoryPath("G:/GAMMA/ModOrganizer.exe"), "G:/GAMMA")
        XCTAssertEqual(SetupPathTools.windowsDirectoryPath(#"G:\GAMMA\ModOrganizer.exe"#), "G:/GAMMA")
        XCTAssertEqual(SetupPathTools.windowsDirectoryPath("G:/ModOrganizer.exe"), "G:/")
    }

    func testWinetricksVerbSupportRequiresEveryExactVerb() {
        let output = """
        corefonts                 Microsoft Core Fonts
        d3dx9_43                  DirectX 9 helper
        d3dx11_43                 DirectX 11 helper
        d3dcompiler_47            Direct3D compiler
        vcrun2026                 Visual C++ 2017-2026 libraries
        """
        XCTAssertTrue(WinetricksTools.supports(
            ["corefonts", "d3dx9_43", "d3dx11_43", "d3dcompiler_47", "vcrun2026"],
            listOutput: output
        ))
        XCTAssertFalse(WinetricksTools.supports(["vcrun2022"], listOutput: output))

        let installed = """
        corefonts
        d3dx9_43
        d3dx11_43
        d3dcompiler_47
        vcrun2022
        """
        XCTAssertEqual(
            WinetricksTools.missingVerbs(
                ["corefonts", "d3dx9_43", "d3dx11_43", "d3dcompiler_47", "vcrun2026"],
                installedOutput: installed
            ),
            ["vcrun2026"]
        )
    }

    func testWinetricksCurrentVCRunChecksumsReplaceStaleValues() {
        let script = """
        w_download x86 e7267c1bdf9237c0b4a28cf027c382b97aa909934f84f1c92d3fb9f04173b33e
        w_download x64 8995548dfffcde7c49987029c764355612ba6850ee09a7b6f0fddc85bdc5c280
        keep unrelated-checksum
        """
        let updated = WinetricksTools.updatingKnownPayloadChecksums(in: script)

        XCTAssertContains(updated, "f0bab33a302b3cdb2e11113760d016f54fd3d2632c65ba7834fac4f0abd7f1a3")
        XCTAssertContains(updated, "843068991daaa1f73ad9f6239bce4d0f6a07a51f18c37ea2a867e9beca71295c")
        XCTAssertContains(updated, "keep unrelated-checksum")
        XCTAssertFalse(updated.contains("e7267c1bdf9237c0b4a28cf027c382b97aa909934f84f1c92d3fb9f04173b33e"))
        XCTAssertFalse(updated.contains("8995548dfffcde7c49987029c764355612ba6850ee09a7b6f0fddc85bdc5c280"))
    }

    func testUSVFSDefaultSourceIsNotUserSpecific() {
        XCTAssertEqual(SetupDefaults.defaultUSVFSSource, "")
    }

    func testLaunchBatchEnvironmentIsOnlyAddedForModOrganizer() {
        let gameLines = SetupLaunchBatchTools.commandLines(
            executableWindowsPath: #"G:\Anomaly\bin\AnomalyDX11AVX.exe"#,
            workingDirectoryWindowsPath: #"G:\Anomaly\bin"#,
            usesModOrganizerEnvironment: false,
            launchArguments: "  --dxgi-old  "
        )
        XCTAssertFalse(gameLines.contains { $0.contains("QT_OPENGL") })
        XCTAssertEqual(gameLines.last, #"start "" /D "G:\Anomaly\bin" "G:\Anomaly\bin\AnomalyDX11AVX.exe" --dxgi-old"#)

        let mo2Lines = SetupLaunchBatchTools.commandLines(
            executableWindowsPath: #"G:\GAMMA\ModOrganizer.exe"#,
            workingDirectoryWindowsPath: #"G:\GAMMA"#,
            usesModOrganizerEnvironment: true,
            launchArguments: #"--profile "Default""#
        )
        XCTAssertTrue(mo2Lines.contains(#"set "QT_OPENGL=software""#))
        XCTAssertTrue(mo2Lines.contains(#"set "QT_QUICK_BACKEND=software""#))
        XCTAssertTrue(mo2Lines.contains(#"set "QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu""#))
        XCTAssertEqual(mo2Lines.last, #"start "" /D "G:\GAMMA" "G:\GAMMA\ModOrganizer.exe" --profile "Default""#)

        let noArguments = SetupLaunchBatchTools.commandLines(
            executableWindowsPath: #"G:\Anomaly\bin\Anomaly.exe"#,
            workingDirectoryWindowsPath: #"G:\Anomaly\bin"#,
            usesModOrganizerEnvironment: false,
            launchArguments: "   "
        )
        XCTAssertEqual(noArguments.last, #"start "" /D "G:\Anomaly\bin" "G:\Anomaly\bin\Anomaly.exe""#)
    }

    func testModOrganizerBatchUsesWindowsWorkingDirectory() {
        let lines = SetupLaunchBatchTools.modOrganizerCommandLines(
            executableWindowsPath: "G:/g/ModOrganizer.exe",
            launchArguments: "--portable"
        )
        XCTAssertContains(lines.joined(separator: "\n"), #"cd /d "G:\g""#)
        XCTAssertContains(lines.joined(separator: "\n"), #"start "" "G:\g\ModOrganizer.exe" --portable"#)
        XCTAssertFalse(lines.joined(separator: "\n").contains("Contents\\Resources"))
    }

    func testDefaultModOrganizerBatchDetectionIsNarrow() {
        let generated = SetupLaunchBatchTools.modOrganizerCommandLines(executableWindowsPath: "G:/g/ModOrganizer.exe")
            .joined(separator: "\r\n")
        XCTAssertTrue(SetupLaunchBatchTools.isDefaultModOrganizerBatch(generated))

        let edited = generated + "\r\nrem user customization"
        XCTAssertFalse(SetupLaunchBatchTools.isDefaultModOrganizerBatch(edited))
    }

    /// Replaces the deleted engine-level testLaunchArgumentsRejectLineBreaks,
    /// which drove the removed SetupRequest/GAMMASetupEngine pair. The rule it
    /// protected — a launch-argument string can never smuggle in a second
    /// command — now lives only in this helper and in
    /// SetupConfiguration.launchArgumentsAreValid.
    func testContainsLineBreakDetectsBothNewlineForms() {
        XCTAssertFalse(SetupLaunchBatchTools.containsLineBreak("--dxgi-old --profile \"Gold\""))
        XCTAssertFalse(SetupLaunchBatchTools.containsLineBreak(""))
        XCTAssertTrue(SetupLaunchBatchTools.containsLineBreak("--first\nstart unwanted.exe"))
        XCTAssertTrue(SetupLaunchBatchTools.containsLineBreak("--first\r\nstart unwanted.exe"))
        XCTAssertTrue(SetupLaunchBatchTools.containsLineBreak("--first\rstart unwanted.exe"))
    }

    func testRegistryKeyValueEditorUpdatesSection() {
        let input = #"""
        [Existing]
        "Keep"="1"

        [Software\\Wine\\DllOverrides] 1780780400
        "*old"="builtin"
        """#

        let output = SetupTextEditor.ensureSectionKeyValues(
            text: input,
            section: #"Software\\Wine\\DllOverrides"#,
            entries: [
                "*d3dcompiler_47": "native,builtin",
                "*vcruntime140": "native,builtin"
            ]
        )

        XCTAssertTrue(output.contains(#""*d3dcompiler_47"="native,builtin""#))
        XCTAssertTrue(output.contains(#""*vcruntime140"="native,builtin""#))
        XCTAssertTrue(output.contains("[Existing]"))
    }

    func testRegistryRawLineEditorUpdatesSection() {
        let input = #"""
        [System\\CurrentControlSet\\Services\\winebus] 1780780400
        "DisableInput"=dword:00000000
        """#

        let output = SetupTextEditor.ensureSectionRawLines(
            text: input,
            section: #"System\\CurrentControlSet\\Services\\winebus"#,
            lines: [
                #""DisableInput"=dword:00000001"#,
                #""Enable SDL"=dword:00000001"#
            ]
        )

        XCTAssertTrue(output.contains(#""DisableInput"=dword:00000001"#))
        XCTAssertTrue(output.contains(#""Enable SDL"=dword:00000001"#))
    }

    func testRegistryKeyValueEditorCreatesMissingSection() {
        let output = SetupTextEditor.ensureSectionKeyValues(
            text: "[Existing]\n\"Keep\"=\"1\"\n",
            section: #"Software\\Wine\\Drivers"#,
            entries: ["Graphics": "mac"]
        )

        XCTAssertContains(output, #"[Software\\Wine\\Drivers]"#)
        XCTAssertContains(output, #""Graphics"="mac""#)
        XCTAssertContains(output, "[Existing]")
    }
}

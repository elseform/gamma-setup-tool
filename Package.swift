// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GAMMASetupTool",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GAMMA Setup Tool", targets: ["GAMMASetupTool"]),
        .executable(name: "gamma-setup-engine", targets: ["GAMMASetupEngine"])
    ],
    targets: [
        .target(
            name: "GAMMASetupCore",
            path: "sources/GAMMASetupCore"
        ),
        .executableTarget(
            name: "GAMMASetupTool",
            dependencies: ["GAMMASetupCore"],
            path: "sources/GAMMASetupTool",
            // wine-engine/ carries its own Anomaly.icns alongside
            // interactive_setup.py (the script resolves it by literal path
            // next to itself, not via Bundle.module) — same basename as the
            // top-level app icon Resources/Anomaly.icns, so .process()
            // (which flattens all of Resources into one namespace) rejects
            // it as a duplicate. It doesn't need a SwiftPM resource rule of
            // its own either: WineEngineSetup.locateScript() finds it by a
            // literal filesystem path relative to the running executable
            // (Contents/Resources/wine-engine for the build.sh-built app,
            // sources/GAMMASetupTool/Resources/wine-engine for `swift run`),
            // never through Bundle.module — build.sh already copies the
            // whole directory into the built app independently of SwiftPM.
            exclude: ["Resources/wine-engine"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        ),
        .executableTarget(
            name: "GAMMASetupEngine",
            dependencies: ["GAMMASetupCore"],
            path: "sources/GAMMASetupEngine",
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        )
    ]
)

import SwiftUI

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupPage: View {
    @Bindable var model: AppModel

    @State private var showLocalEngine = false
    @State private var showRedistInstallers = false
    @State private var showAdvanced = false
    @State private var redistInstallerStatuses: [RedistInstallers.Status] = []

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardCard {
                summary
            }

            WizardCard {
                VStack(alignment: .leading, spacing: 16) {
                    engineArchiveControls
                    Divider()
                    redistInstallerControls
                    Divider()
                    advancedControls
                }
            }
            .disabled(!model.selectedLaunchExecutableFound || model.isRunning)
            .opacity((model.selectedLaunchExecutableFound && !model.isRunning) ? 1 : 0.45)
        }
        .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)
        .task(id: model.selectedLaunchExecutablePath) {
            model.refreshUSVFSPlan()
        }
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeading(title: "What setup will do")
            Label {
                Text("Create **\(model.outputAppName)** in ~/Applications")
            } icon: {
                Image(systemName: "app.badge.checkmark")
                    .foregroundStyle(.tint)
            }
            Label {
                Text(model.wineEngineArchivePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                     ? "Download latest gamma-wine-engine"
                     : "Use local engine copy")
            } icon: {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.tint)
            }
            Label {
                Text("Set up the wine prefix for \(model.selectedLaunchExecutableLabel)")
            } icon: {
                Image(systemName: "play.circle")
                    .foregroundStyle(.tint)
            }
            USVFSStatusRow(outcome: model.usvfsPlan)
        }
        .font(.callout)
    }

    // Left empty (the default), the
    // newest published gamma-wine-engine release is resolved and downloaded
    // automatically; a path here is a local archive, used as is.
    private var engineArchiveControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardHeading(title: "Wine engine")
            Text(model.wineEngineArchivePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "Get latest release from github."
                 : "Using your local engine file as is.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("Use local engine pack instead", isExpanded: $showLocalEngine) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("Automatic download", text: $model.wineEngineArchivePath)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Engine archive")
                        Button("Choose…") {
                            model.chooseWineEngineArchive()
                        }
                        .accessibilityLabel("Choose engine archive")
                    }
                    Text("Pick .tar.xz engine archive.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !model.wineEngineArchivePath.isEmpty {
                        Button("Use automatic download") {
                            model.wineEngineArchivePath = ""
                        }
                        .buttonStyle(.link)
                    }
                }
                .padding(.top, 6)
            }
            .onAppear {
                if !model.wineEngineArchivePath.isEmpty {
                    showLocalEngine = true
                }
            }
        }
    }

    // MARK: - Redistributables

    // The DirectX/VC++ DLLs are not shipped with the engine — it declares
    // which ones it needs and fetches them from Microsoft's own pinned
    // installers during setup. Nothing here has to be filled in; the picker
    // only lets someone who already has the installers point at them so the
    // run stays offline. Collapsed by default, since the default path needs
    // no decision.
    private var redistInstallerControls: some View {
        DisclosureGroup(isExpanded: $showRedistInstallers) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(redistInstallerStatuses, id: \.installer.filename) { status in
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(status.installer.title)
                                .font(.callout)
                            Text(status.isPresent
                                 ? "Found locally; verified during setup"
                                 : "Will be downloaded (\(status.installer.sizeLabel))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: status.isPresent ? "checkmark.circle.fill" : "arrow.down.circle")
                            .foregroundStyle(status.isPresent ? .green : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                HStack(spacing: 8) {
                    TextField("Optional folder with downloaded installers",
                              text: $model.redistInstallerDirectory)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Downloaded installers folder")
                    Button("Choose…") {
                        model.chooseRedistInstallerDirectory()
                    }
                    .accessibilityLabel("Choose downloaded installers folder")
                }

                Text("Setup verifies every file against the engine’s required checksum. Missing files are downloaded automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                CardHeading(title: "Dependencies")
                Text("Downloaded automatically")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: model.redistInstallerDirectory) {
            redistInstallerStatuses = RedistInstallers.statuses(
                userDirectory: model.redistInstallerDirectory
            )
        }
    }

    // MARK: - Advanced

    private var advancedControls: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 14) {
                driveMappingControls
                Toggle(SetupOptionCopy.saveDetailedLog, isOn: $model.saveVerboseLog)
            }
            .padding(.top, 6)
        } label: {
            CardHeading(title: "Advanced")
        }
    }

    // MARK: - Drive Mapping

    private var driveMappingControls: some View {
        VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
            Text("Drive mappings")
                .font(.subheadline.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
                GridRow {
                    Text("Game root (G:)")
                        .foregroundStyle(.secondary)
                    Text(model.configuration.optionalGDriveRoot)
                        .font(.system(.callout, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Mac root (Z:)")
                        .foregroundStyle(.secondary)
                    Text("/")
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .font(.callout)

            Text("G: uses the parent of the selected executable’s folder. Z: provides access to your Mac’s filesystem. Existing ModOrganizer paths must still point to the correct folders.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

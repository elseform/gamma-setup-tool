import SwiftUI

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupPage: View {
    @ObservedObject var model: AppModel
    @Binding var showWinetricksList: Bool

    @State private var showRedistInstallers = false
    @State private var redistInstallerStatuses: [RedistInstallers.Status] = []

    // MARK: - Body

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Layout.setupColumnSpacing) {
                setupOptionsCard
                    .frame(width: Layout.setupLeftColumnWidth, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    additionalOptionsCard
                }
                .frame(width: Layout.setupRightColumnWidth, alignment: .topLeading)
            }
            .frame(width: Layout.setupContentWidth, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 12) {
                setupOptionsCard
                additionalOptionsCard
            }
            .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)
        }
        .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)
        .disabled(!model.selectedModOrganizerExecutableFound || model.isRunning)
        .opacity((model.selectedModOrganizerExecutableFound && !model.isRunning) ? 1 : 0.45)
    }

    // MARK: - App And Prefix

    private var setupOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            prefixPanel
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var prefixPanel: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                engineArchiveControls
                Divider()
                redistInstallerControls
                Divider()
                driveMappingControls
            }
        }
    }

    // gamma-wine-engine ships its own engine build — there is no
    // CX/Sikarugir choice for this pipeline. No release is published yet
    // (see gamma-wine-engine/scripts/publish-release.sh), so this is a
    // local-file picker rather than a download; swap for a download once
    // that lands.
    private var engineArchiveControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardHeading(title: "Engine archive")
            HStack(spacing: 8) {
                TextField(".tar.zst or .tar.xz path", text: $model.wineEngineArchivePath)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") {
                    model.chooseWineEngineArchive()
                }
            }
            if model.wineEngineArchivePath.isEmpty {
                Text("Required — pick a gamma-wine-engine build (e.g. dist/artifacts/*.tar.zst).")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
                                 ? "Already downloaded"
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
                    Button("Choose…") {
                        model.chooseRedistInstallerDirectory()
                    }
                }

                Text("Each file is verified against the checksum the engine pins, wherever it came from.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
        } label: {
            CardHeading(title: "Microsoft redistributables")
        }
        .task(id: model.redistInstallerDirectory) {
            redistInstallerStatuses = RedistInstallers.statuses(
                userDirectory: model.redistInstallerDirectory
            )
        }
    }

    // MARK: - Drive Mapping

    // gamma-wine-engine always mounts both Z: (host root) and G: (game
    // root) unconditionally — there is no mode choice here anymore, unlike
    // the Sikarugir pipeline's optional G: mapping.
    @ViewBuilder
    private var driveMappingControls: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
            GridRow {
                Text("Mapping")
                Text(model.plannedWineDriveMapping)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }

        Text("Mounts the game root into wine as G: (and the host root as Z:, always).")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Additional Options

    // No runtime-dependency-mode or dxmt-only controls: redist is always
    // used (see wineEngineRequest()),
    // and USVFS updates always run with an automatic up-to-date check
    // instead of a manual toggle (WineEngineSetup.updateUSVFSIfNeeded).
    private var additionalOptionsCard: some View {
        WizardCard {
            VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                CardHeading(title: "Additional options")
                Toggle(SetupOptionCopy.saveDetailedLog, isOn: $model.saveVerboseLog)
            }
        }
    }
}

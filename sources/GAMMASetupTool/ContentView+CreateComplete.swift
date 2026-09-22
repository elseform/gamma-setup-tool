import SwiftUI
import AppKit

struct CreatePage: View {
    @ObservedObject var model: AppModel
    @Binding var createButtonSubmitted: Bool

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.isRunning || createButtonSubmitted || model.installFailed {
                runStatus
            } else {
                setupReviewCard(items: model.setupSummaryItems)
            }
        }
        .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)
    }

    // MARK: - Setup Review

    private func setupReviewCard(items: [SetupSummaryItem]) -> some View {
        WizardCard {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                ForEach(items) { item in
                    SetupSummaryRow(item: item)
                }
            }
            .font(.system(size: 15))
            .padding(.vertical, 4)
        }
        .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)
    }

    // MARK: - Run Status

    private var runStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isRunning || model.installFailed {
                WizardCard {
                    installStages
                }
                .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)

                ProgressView(value: model.progress)

                if model.installFailed {
                    installFailureView
                }
            }

            if model.isRunning || !model.logText.isEmpty {
                DisclosureGroup("Output", isExpanded: $model.showOutput) {
                    TextEditor(text: $model.logText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 130)
                        .border(Color(nsColor: .separatorColor))
                }
            }
        }
        .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)
    }

    private var installFailureView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 5) {
                Text("Installation failed")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
                if model.savedLogPath.isEmpty {
                    Text("Failed to save log. Expand Output and copy the visible log.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Text("Log:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            model.openSavedLog()
                        } label: {
                            Text(model.savedLogPath)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.link)
                        .help("Open log")
                    }
                }
                Text("Open the Discord support thread and attach the log.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }

    private var installStages: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(installStageRows.enumerated()), id: \.offset) { _, row in
                installStageRow(row: row)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    // Stage numbers (0-6) match SetupEngineStage's declaration order
    // (dependencies/wrapper/engine/prefix/driveMapping/winetricks/finalize)
    // — interactive_setup.py (Resources/wine-engine/) emits that same schema
    // directly, relayed by WineEngineSetup.swift.
    private var installStageRows: [(stage: Int, title: String, detail: String)] {
        [
            (0, "Preparing", "Resolving engine archive"),
            (1, model.wrapperStageTitle, ""),
            (2, "Engine", "Extracting DXMT engine"),
            (3, "Prefix", "Bootstrapping Wine prefix"),
            (4, "Drive mapping", model.plannedWineDriveMapping),
            (5, "Runtime dependencies", "Microsoft redistributables"),
            (6, "Finalize", "Signing, registering & checking USVFS")
        ]
    }

    private func installStageRow(row: (stage: Int, title: String, detail: String)) -> some View {
        HStack(spacing: 8) {
            stageIcon(for: row.stage)
            Text(row.title)
                .font(.caption.weight(.semibold))
            if !row.detail.isEmpty {
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .frame(height: 16)
    }

    private func stageIcon(for index: Int) -> some View {
        return Group {
            if model.installFailed && index == model.installStageIndex {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            } else if index <= model.installStageCompletedIndex {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if index == model.installStageIndex {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 16)
    }
}

struct CompletePage: View {
    @ObservedObject var model: AppModel

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WizardCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.green)
                        Text(WrapperCreatedCopy.title)
                            .font(.headline)
                    }

                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                        GridRow {
                            Text("App created:")
                                .foregroundStyle(.secondary)
                            Text(model.outputAppPath)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        if model.saveVerboseLog {
                            GridRow {
                                Text("Log saved:")
                                    .foregroundStyle(.secondary)
                                if model.savedLogPath.isEmpty {
                                    Text("Log path not found")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Button {
                                        model.openSavedLog()
                                    } label: {
                                        Text(model.savedLogPath)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    .buttonStyle(.link)
                                    .help("Show log")
                                }
                            }
                        }
                    }
                    .font(.callout)

                    Text("Open the new app to launch ModOrganizer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: Layout.completeMaxWidth, alignment: .topLeading)
        }
        .frame(maxWidth: Layout.completeMaxWidth, alignment: .topLeading)
    }
}

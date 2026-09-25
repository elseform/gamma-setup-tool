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
            .font(.body)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)
    }

    // MARK: - Run Status

    private var runStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isRunning || createButtonSubmitted || model.installFailed {
                WizardCard {
                    installStages
                }
                .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)

                ProgressView(value: model.progress)
                    .accessibilityLabel("Wrapper creation progress")

                if model.installFailed {
                    installFailureView
                }
            }

            if model.isRunning || model.installFailed || !model.logText.isEmpty {
                DisclosureGroup("Setup output", isExpanded: $model.showOutput) {
                    ScrollView {
                        Text(model.logText.isEmpty ? "No setup output is available yet." : model.logText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 130)
                    .border(Color(nsColor: .separatorColor))
                    .accessibilityLabel("Setup output")
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
                Text("Wrapper creation failed")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
                if model.savedLogPath.isEmpty {
                    Text(model.saveVerboseLog
                         ? "The setup log location is unavailable. Expand Setup output and copy any available details."
                         : "Saving the setup log was turned off. Expand Setup output and copy any available details.")
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
                Text("For help, use Discord support below and share the log or setup output.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }

    private var installStages: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(installStageRows, id: \.stage) { row in
                installStageRow(row: row)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    // Row numbers are indices into SetupEngineStage.allCases, the order a
    // run reaches them (dependencies, engine, prefix, driveMapping,
    // winetricks, wrapper, finalize).
    private var installStageRows: [(stage: Int, title: String, detail: String)] {
        [
            (0, "Preparing", "Resolving engine archive"),
            (1, "Engine", "Extracting DXMT engine"),
            (2, "Wine prefix", "Preparing the Windows environment"),
            (3, "Drive mapping", model.plannedWineDriveMapping),
            (4, "Runtime dependencies", "Microsoft redistributables"),
            (5, "Wrapper", "Launcher, settings and Configurator"),
            (6, "Finishing", "Signing the app and checking ModOrganizer USVFS")
        ]
    }

    private func installStageRow(row: (stage: Int, title: String, detail: String)) -> some View {
        HStack(alignment: .top, spacing: 8) {
            stageIcon(for: row.stage)
                .accessibilityHidden(true)
            Text(row.title)
                .font(.caption.weight(.semibold))
            if !row.detail.isEmpty {
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.detail.isEmpty ? row.title : "\(row.title), \(row.detail)")
        .accessibilityValue(stageStatus(for: row.stage))
    }

    private func stageStatus(for index: Int) -> String {
        if model.installFailed && index == model.installStageIndex { return "Failed" }
        if index <= model.installStageCompletedIndex { return "Completed" }
        if index == model.installStageIndex { return "In progress" }
        return "Pending"
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
                            Text("Application:")
                                .foregroundStyle(.secondary)
                            Text(model.outputAppPath)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        if model.saveVerboseLog {
                            GridRow {
                                Text("Setup log:")
                                    .foregroundStyle(.secondary)
                                if model.savedLogPath.isEmpty {
                                    Text("Log location unavailable")
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
                                    .help("Open setup log")
                                }
                            }
                        }
                    }
                    .font(.callout)

                    Text("Open the new app to launch \(model.selectedLaunchExecutableLabel).")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Use the adjacent Configurator alias to change game settings and launch arguments. If the alias is missing, open Configurator.app in the wrapper’s Contents/Resources folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: Layout.completeMaxWidth, alignment: .topLeading)
        }
        .frame(maxWidth: Layout.completeMaxWidth, alignment: .topLeading)
    }
}

import SwiftUI
import AppKit

struct CreatePage: View {
    @Bindable var model: AppModel
    @Binding var createButtonSubmitted: Bool

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.installFailed {
                Text(currentStageTitle)
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.updatesFrequently)
            }

            ProgressView(value: model.progress)
                .accessibilityLabel("App creation progress")

            WizardCard {
                installStages
            }

            if model.installFailed {
                installFailureView
            }

            DisclosureGroup("Show technical details", isExpanded: $model.showOutput) {
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
        .frame(maxWidth: Layout.setupContentWidth, alignment: .topLeading)
    }

    private var currentStageTitle: String {
        guard installStageRows.indices.contains(model.installStageIndex) else {
            return model.installStageCompletedIndex >= 0 ? "Almost done\u{2026}" : "Getting started\u{2026}"
        }
        return "\(installStageRows[model.installStageIndex].detail)\u{2026}"
    }

    // MARK: - Run Status

    private var installFailureView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 5) {
                Text("The app couldn't be created")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
                if model.savedLogPath.isEmpty {
                    Text(model.saveVerboseLog
                         ? "The setup log location is unavailable. Copy the technical details below instead."
                         : "Saving the setup log was turned off. Copy the technical details below instead.")
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
                Text("Press Try again, or ask for help in the GAMMA Discord and share the log.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Copy details", action: model.copyLog)
                        .disabled(model.logText.isEmpty)
                    Link(SupportCopy.discordTitle, destination: SupportCopy.discordURL)
                        .help(SupportCopy.discordHelp)
                }
                .controlSize(.small)
                .padding(.top, 2)
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
            (0, "Preparing", "Finding the game engine"),
            (1, "Engine", "Unpacking the game engine"),
            (2, "Windows environment", "Preparing the Windows environment"),
            (3, "Drives", "Connecting your GAMMA folder"),
            (4, "Windows components", "Installing Windows components"),
            (5, "App", "Building the app and its Configurator"),
            (6, "Finishing", "Finishing up")
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
    let model: AppModel

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WizardCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.outputAppName)
                                .font(.headline)
                            Text(model.outputAppPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                    }
                    USVFSStatusRow(outcome: model.usvfsPlanForRun, finished: true)
                }
            }

            WizardCard {
                VStack(alignment: .leading, spacing: 10) {
                    CardHeading(title: "Next steps")
                    ForEach(nextSteps, id: \.number) { step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "\(step.number).circle.fill")
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                            Text(step.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .font(.callout)
                .help("If the Configurator alias is missing, open Configurator.app in the app's Contents/Resources folder.")
            }

            WizardCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(model.saveVerboseLog
                             ? "Problems? Ask in the GAMMA Discord and share your setup log."
                             : "Problems? Ask in the GAMMA Discord.")
                        Link(SupportCopy.discordTitle, destination: SupportCopy.discordURL)
                            .help(SupportCopy.discordHelp)
                    }
                    if model.saveVerboseLog {
                        if model.savedLogPath.isEmpty {
                            Text("Setup log location unavailable")
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
                .font(.callout)
            }
        }
        .frame(maxWidth: Layout.completeMaxWidth, alignment: .topLeading)
    }

    /// The Configurator alias is "<app name> Configurator", next to the app
    /// (interactive_setup.py).
    private var nextSteps: [(number: Int, text: LocalizedStringKey)] {
        let launch: LocalizedStringKey = model.configuration.usesCustomLaunchExecutable
            ? "It starts **\(model.selectedLaunchExecutableLabel)**."
            : "It opens Mod Organizer. Press **Run** there to start the game."
        return [
            (1, "Open **\(model.outputAppName)** from ~/Applications. Show in Finder below takes you there."),
            (2, launch),
            (3, "The first start can take longer while shaders are prepared."),
            (4, "To change graphics or launch options, open **\(model.outputAppName) Configurator**, next to the app."),
        ]
    }
}

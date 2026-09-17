import SwiftUI

struct WrapperNamePage: View {
    @ObservedObject var model: AppModel
    @FocusState private var appNameIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name and installation")
                .font(.title3)
                .bold()

            WizardCard {
                HStack(alignment: .center, spacing: 12) {
                    StatusIndicator(ok: model.wrapperNameIsValid)

                    VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
                        CardHeading(title: "Application name")
                        TextField("stalker-gamma", text: $model.appName)
                            .textFieldStyle(.roundedBorder)
                            .focused($appNameIsFocused)
                        if !model.wrapperNameValidationMessage.isEmpty {
                            nameValidationContent
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Creates:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(model.outputAppPath)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)

                            if model.outputAppAlreadyExists {
                                Spacer(minLength: 8)
                                Button("Show Existing App", action: model.showExistingApp)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: Layout.environmentPanelWidth, alignment: .leading)

            WizardCard {
                modOrganizerRow()
            }
            .frame(maxWidth: Layout.environmentPanelWidth, alignment: .topLeading)

            Text("You'll review the wrapper settings on the next step. They can be changed later using the Configure application.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.wrapperNameIsValid
                && model.selectedModOrganizerExecutableFound
                && !model.driveMappingReady {
                Label("Drive mapping is not valid. Fix it on the next step.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .frame(maxWidth: Layout.environmentPanelWidth, alignment: .leading)
        .defaultFocus($appNameIsFocused, true)
    }

    private var nameValidationContent: some View {
        Text(model.wrapperNameValidationMessage)
            .font(.caption)
            .foregroundStyle(.red)
    }

    private func modOrganizerRow() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CheckRow(
                label: launchExecutableStatusLabel,
                status: "",
                ok: model.selectedModOrganizerExecutableFound,
                warning: true,
                detail: model.selectedModOrganizerExecutableFound
                    ? model.selectedLaunchExecutablePath
                    : "Not found — click Choose\u{2026} to locate it"
            ) {
                Button(model.selectedModOrganizerExecutableFound ? "Change…" : "Choose…") {
                    model.chooseLaunchExecutable()
                }
            }

            if model.programBatch != "/mo2.bat" {
                HStack(spacing: 8) {
                    Text("Flags")
                        .frame(width: 38, alignment: .leading)
                    TextField("Optional launch flags", text: $model.launchArguments)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.leading, 34)
                .padding(.bottom, 12)
            }
        }
    }

    private var launchExecutableStatusLabel: String {
        if model.programBatch != "/mo2.bat" {
            return "\(model.selectedLaunchExecutableLabel) selected"
        }
        return model.selectedModOrganizerExecutableFound ? "ModOrganizer.exe found" : "Select ModOrganizer.exe"
    }
}

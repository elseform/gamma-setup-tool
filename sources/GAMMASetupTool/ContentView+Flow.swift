import SwiftUI

struct WrapperNamePage: View {
    @Bindable var model: AppModel
    @FocusState private var appNameIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Name and launch target")
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
                            .accessibilityLabel("Application name")
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
                                Button("Show existing app", action: model.showExistingApp)
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

            Text("Creates a wrapper for your existing installation. It does not install G.A.M.M.A. After setup, use the Configurator to change game settings and launch arguments.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                ok: model.selectedLaunchExecutableFound,
                warning: true,
                detail: model.selectedLaunchExecutableFound
                    ? model.selectedLaunchExecutablePath
                    : "Not found — click Choose\u{2026} to locate it"
            ) {
                Button(model.selectedLaunchExecutableFound ? "Change…" : "Choose…") {
                    model.chooseLaunchExecutable()
                }
                .accessibilityLabel("Choose launch executable")
            }
        }
    }

    private var launchExecutableStatusLabel: String {
        if model.configuration.usesCustomLaunchExecutable {
            return "\(model.selectedLaunchExecutableLabel) selected"
        }
        return model.selectedLaunchExecutableFound ? "ModOrganizer.exe found" : "Select ModOrganizer.exe"
    }
}

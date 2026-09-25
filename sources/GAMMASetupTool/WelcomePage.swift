import SwiftUI
import AppKit

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

/// First page: pick the launch executable, then name the app. The name
/// field appears only once an executable is picked, replacing the picker
/// with a one-line summary of the choice.
struct WelcomePage: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var appNameIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardCard {
                VStack(alignment: .leading, spacing: 14) {
                    if model.selectedLaunchExecutableFound {
                        pickedLocation
                        Divider()
                        appNameSection
                            .transition(.opacity)
                    } else {
                        locationPicker
                            .transition(.opacity)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.selectedLaunchExecutableFound)
            }
        }
        .frame(maxWidth: Layout.wizardContentWidth, alignment: .leading)
        .task(id: model.selectedLaunchExecutablePath) {
            model.refreshUSVFSPlan()
        }
        .onChange(of: model.selectedLaunchExecutableFound) { _, found in
            appNameIsFocused = found
        }
    }

    // MARK: - Location

    private var locationPicker: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Select ModOrganizer location")
                    .font(.body.weight(.semibold))
                Text("Choose ModOrganizer.exe in your GAMMA folder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("Choose…", action: model.chooseLaunchExecutable)
                .buttonStyle(.borderedProminent)
                .help("Pick ModOrganizer.exe, or another Windows program to launch instead")
        }
    }

    private var pickedLocation: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(URL(fileURLWithPath: model.selectedLaunchExecutablePath).lastPathComponent)
                        .font(.body.weight(.semibold))
                    Text(model.selectedLaunchExecutablePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 12)
                Button("Change…", action: model.chooseLaunchExecutable)
                    .controlSize(.small)
                    .accessibilityLabel("Change launch executable")
            }
            .accessibilityElement(children: .contain)
            USVFSStatusRow(outcome: model.usvfsPlan)
                .padding(.leading, 36)
        }
    }

    // MARK: - App Name

    private var appNameSection: some View {
        VStack(alignment: .leading, spacing: Layout.cardContentSpacing) {
            Text("App name")
                .font(.body.weight(.semibold))
            TextField("App name", text: $model.appName)
                .textFieldStyle(.roundedBorder)
                .focused($appNameIsFocused)
                .labelsHidden()
            if !model.wrapperNameValidationMessage.isEmpty {
                Text(model.wrapperNameValidationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Saved as:")
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

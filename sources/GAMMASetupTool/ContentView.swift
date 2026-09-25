import SwiftUI

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = AppModel()
    @State private var step: WizardStep = .wrapperName
    @State private var createButtonSubmitted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                currentStepView
                    .id(step)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
                    .frame(maxWidth: Layout.contentMaxWidth, alignment: .top)
                    .padding(.horizontal, Layout.contentHorizontalPadding)
                    .padding(.vertical, Layout.contentVerticalPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Divider()
            footer
        }
        .frame(minWidth: Layout.windowMinimumWidth, minHeight: Layout.windowMinimumHeight)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: step)
        .onChange(of: model.isRunning) { _, isRunning in
            if isRunning {
                step = .create
            }
        }
    }
}

extension ContentView {
    // MARK: - Header

    private var headerText: (title: String, subtitle: String) {
        switch step {
        case .wrapperName:
            return (
                "Create GAMMA wrapper",
                "Name the wrapper and choose ModOrganizer.exe or another Windows executable."
            )

        case .setup:
            return (
                "Wrapper settings",
                "Review the engine archive and options, then continue."
            )
        case .create:
            return (model.createHeaderTitle, model.createHeaderSubtitle)
        case .complete:
            return (WrapperCreatedCopy.title, WrapperCreatedCopy.subtitle)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 7) {
                Text(headerText.title)
                    .font(.title2.weight(.semibold))
                Text(headerText.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Layout.headerHorizontalPadding)
        .padding(.top, Layout.headerTopPadding)
        .padding(.bottom, Layout.headerBottomPadding)
        .frame(minHeight: Layout.headerHeight, alignment: .topLeading)
        .background(Color(nsColor: .underPageBackgroundColor))
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .wrapperName:
            WrapperNamePage(model: model)
        case .setup:
            SetupPage(model: model)
        case .create:
            CreatePage(
                model: model,
                createButtonSubmitted: $createButtonSubmitted
            )
        case .complete:
            CompletePage(model: model)
        }
    }

    // MARK: - Footer

    private var footerVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? SetupDefaults.toolVersion
    }

    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                footerMetadata
                Spacer()
                footerBackButton
                footerPrimaryButton
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    footerMetadata
                    Spacer()
                }
                HStack(spacing: 12) {
                    Spacer()
                    footerBackButton
                    footerPrimaryButton
                }
            }
        }
        .padding(.horizontal, Layout.footerHorizontalPadding)
        .padding(.vertical, Layout.footerVerticalPadding)
        .frame(minHeight: Layout.footerHeight, alignment: .center)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var footerMetadata: some View {
        HStack(spacing: 12) {
            Text("v\(footerVersion)")
                .font(.caption)
                .foregroundStyle(.tertiary)
            footerLinks
        }
    }

    private var footerLinks: some View {
        let sourceURL = URL(string: "https://github.com/elseform/gamma-setup-tool")!
        let supportURL = URL(string: "https://discord.com/channels/912320241713958912/1315449108797980762")!

        return HStack(spacing: 12) {
            Link("GitHub - elseform", destination: sourceURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Open the GAMMA Setup Tool repository by elseform")

            Link("Discord support", destination: supportURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Discord support thread")

        }
    }

    @ViewBuilder
    private var footerBackButton: some View {
        if step != .wrapperName && step != .complete && !model.isRunning && !createButtonSubmitted {
            Button("Back") {
                if let previous = previousStep {
                    step = previous
                }
            }
            .disabled(previousStep == nil)
        }
    }

    @ViewBuilder
    private var footerPrimaryButton: some View {
        switch step {
        case .wrapperName:
            Button {
                continueToNextStep()
            } label: {
                Label("Continue", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(wrapperNameActionsDisabled)
        case .setup:
            Button {
                continueToNextStep()
            } label: {
                Label("Review settings", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!canContinue)
        case .create:
            if !model.isRunning && !createButtonSubmitted {
                Button {
                    startCreate()
                } label: {
                    Label("Create wrapper", systemImage: "play.circle")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.isRunning || !model.setupReady)
            }
        case .complete:
            Button {
                model.showCreatedAppAndQuit()
            } label: {
                Label("Show in Finder and quit", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command])
            .help("Reveal the wrapper in Finder and quit GAMMA Setup Tool")
        }
    }

    // MARK: - Navigation State

    private var visibleSteps: [WizardStep] {
        if step == .complete {
            return []
        }
        return [.wrapperName, .setup, .create]
    }

    private var currentStepIndex: Int? {
        visibleSteps.firstIndex(of: step)
    }

    private var previousStep: WizardStep? {
        guard let index = currentStepIndex, index > 0 else { return nil }
        return visibleSteps[index - 1]
    }

    private var nextStep: WizardStep? {
        guard let index = currentStepIndex, index + 1 < visibleSteps.count else { return nil }
        return visibleSteps[index + 1]
    }

    private var canContinue: Bool {
        if model.isRunning {
            return false
        }
        if step == .setup {
            return nextStep != nil && model.setupReady
        }
        return nextStep != nil
    }

    private var wrapperNameActionsDisabled: Bool {
        !model.wrapperNameIsValid || !model.selectedLaunchExecutableFound
    }

    private func continueToNextStep() {
        guard let next = nextStep else { return }
        step = next
    }

    private func startCreate() {
        createButtonSubmitted = true
        Task {
            let created = await model.createWineEngine()
            createButtonSubmitted = false
            if created {
                step = .complete
            }
        }
    }
}

#if DEBUG
#Preview("GAMMA Setup Tool") {
    ContentView()
}
#endif

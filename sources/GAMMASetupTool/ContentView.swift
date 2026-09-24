import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject var model = AppModel()
    @State var step: WizardStep = .wrapperName
    @State var furthestUnlockedStep = WizardStep.setup
    @State var createButtonSubmitted = false

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
        .background(WindowMinimumSize(width: Layout.windowMinimumWidth, height: Layout.windowMinimumHeight))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: step)
        .onChange(of: model.isRunning) { _, isRunning in
            if isRunning {
                step = .create
                furthestUnlockedStep = maxStep(furthestUnlockedStep, .create)
            }
        }
    }

}

#if DEBUG
#Preview("GAMMA Setup Tool") {
    ContentView()
}
#endif

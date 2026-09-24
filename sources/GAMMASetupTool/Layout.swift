import SwiftUI
import AppKit

struct WindowMinimumSize: NSViewRepresentable {
    let width: CGFloat
    let height: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            applySizing(to: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            applySizing(to: view.window)
        }
    }

    private func applySizing(to window: NSWindow?) {
        guard let window else { return }
        window.minSize = NSSize(width: width, height: height)
    }
}

enum Layout {
    static let windowDefaultWidth: CGFloat = 820
    static let windowDefaultHeight: CGFloat = 640
    static let windowMinimumWidth: CGFloat = 760
    static let windowMinimumHeight: CGFloat = 560
    static let contentMaxWidth: CGFloat = 1000
    static let contentHorizontalPadding: CGFloat = 30
    static let contentVerticalPadding: CGFloat = 16
    static let headerHeight: CGFloat = 82
    static let headerHorizontalPadding: CGFloat = 28
    static let headerTopPadding: CGFloat = 14
    static let headerBottomPadding: CGFloat = 12
    static let headerContentHeight: CGFloat = headerHeight - headerTopPadding - headerBottomPadding
    static let footerHeight: CGFloat = 52
    static let footerHorizontalPadding: CGFloat = 28
    static let footerVerticalPadding: CGFloat = 12
    static let wizardContentWidth: CGFloat = 740
    static let environmentPanelWidth: CGFloat = wizardContentWidth
    static let environmentPanelHorizontalPadding: CGFloat = 14
    static let environmentPanelVerticalPadding: CGFloat = 12
    static let setupContentWidth: CGFloat = wizardContentWidth
    static let setupPanelHorizontalPadding: CGFloat = 14
    static let setupPanelVerticalPadding: CGFloat = 12
    static let cardContentSpacing: CGFloat = 8
    static let winetricksPanelVerticalPadding: CGFloat = 12
    static let completeMaxWidth: CGFloat = wizardContentWidth
}

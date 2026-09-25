import SwiftUI

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct CardHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
    }
}

struct WizardCard<Content: View>: View {
    var horizontalPadding = Layout.setupPanelHorizontalPadding
    var verticalPadding = Layout.setupPanelVerticalPadding
    @ViewBuilder var content: () -> Content

    var body: some View {
        GroupBox {
            content()
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

enum WizardStep {
    case welcome
    case setup
    case create
    case complete
}

struct CheckRow<Action: View>: View {
    let label: String
    let status: String
    let ok: Bool
    let warning: Bool
    let detail: String?
    let prominent: Bool
    @ViewBuilder let action: () -> Action

    init(
        label: String,
        status: String,
        ok: Bool,
        warning: Bool = false,
        detail: String? = nil,
        prominent: Bool = false,
        @ViewBuilder action: @escaping () -> Action
    ) {
        self.label = label
        self.status = status
        self.ok = ok
        self.warning = warning
        self.detail = detail
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusIndicator(ok: ok, warning: warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.title3.weight(.semibold))
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 12)

            if !status.isEmpty {
                Text(status)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(SetupStatusTone.checkRow(ok: ok, warning: warning).color)
                    .multilineTextAlignment(.trailing)
            }

            action()
                .frame(minHeight: 28, alignment: .trailing)
        }
        .padding(.vertical, 11)
        .frame(minHeight: 50)
    }
}

struct StatusIndicator: View {
    let ok: Bool
    var warning = false

    private var label: String {
        if ok { return "Valid" }
        return warning ? "Needs attention" : "Invalid"
    }

    var body: some View {
        Image(systemName: ok ? "checkmark.circle.fill" : (warning ? "exclamationmark.triangle.fill" : "xmark.circle.fill"))
            .font(.title3.weight(.semibold))
            .foregroundStyle(SetupStatusTone.checkRow(ok: ok, warning: warning).color)
            .frame(width: 22)
            .accessibilityLabel(label)
    }
}

extension CheckRow where Action == EmptyView {
    init(
        label: String,
        status: String,
        ok: Bool,
        warning: Bool = false,
        detail: String? = nil,
        prominent: Bool = false
    ) {
        self.init(label: label, status: status, ok: ok, warning: warning, detail: detail, prominent: prominent) {
            EmptyView()
        }
    }
}

/// One line saying what setup does (or did) to ModOrganizer's USVFS files.
struct USVFSStatusRow: View {
    let outcome: USVFSUpdater.Outcome?
    var finished = false

    var body: some View {
        if let outcome {
            Label {
                Text(message(for: outcome))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: symbol(for: outcome))
                    .foregroundStyle(tint(for: outcome))
            }
            .font(.callout)
            .help("USVFS is the virtual file system Mod Organizer uses to load mods.")
        }
    }

    private func message(for outcome: USVFSUpdater.Outcome) -> String {
        switch outcome {
        case .notModOrganizer:
            return "USVFS binaries \(finished ? "were" : "won't be") updated, selected target is not Mod Organizer."
        case .upToDate:
            return "USVFS binaries \(finished ? "were" : "are") already up to date."
        case .updated(_, let replaced, _):
            let files = replaced.count == 1 ? "1 file" : "\(replaced.count) files"
            return finished
                ? "Updated USVFS binaries (\(files)). The originals were backed up to \(USVFSUpdater.backupFolderName) in the Mod Organizer folder."
                : "USVFS binaries will be updated (\(files)). The originals are backed up first."
        }
    }

    private func symbol(for outcome: USVFSUpdater.Outcome) -> String {
        switch outcome {
        case .notModOrganizer: return "minus.circle"
        case .upToDate: return "checkmark.circle.fill"
        case .updated: return finished ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    private func tint(for outcome: USVFSUpdater.Outcome) -> Color {
        switch outcome {
        case .notModOrganizer: return .secondary
        case .upToDate: return .green
        case .updated: return finished ? .green : .orange
        }
    }
}

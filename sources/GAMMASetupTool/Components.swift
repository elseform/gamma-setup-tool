import SwiftUI

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
    case wrapperName
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

struct SetupSummaryRow: View {
    let item: SetupSummaryItem

    var body: some View {
        GridRow {
            Text(item.label)
                .font(.body)
                .foregroundStyle(.secondary)
            Text(item.planned)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}

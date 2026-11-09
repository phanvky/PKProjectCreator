import SwiftUI

/// Grouped rounded container; inserts a divider between each child row automatically.
struct FormCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    if row.id != rows.first?.id {
                        Divider()
                    }
                    row
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardFill, in: .rect(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder))
    }
}

/// Label on the left, control on the right — the standard settings row.
struct FormRow<Trailing: View>: View {
    private let label: String
    private let trailing: Trailing

    init(_ label: String, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 16)
            trailing
        }
        .padding(Theme.rowPadding)
    }
}

/// Checkbox row inside a FormCard.
struct ToggleRow: View {
    private let title: String
    @Binding private var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        Toggle(title, isOn: $isOn)
            .padding(Theme.rowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Small secondary label + value, used for paths and inspector details.
struct InfoRow: View {
    let label: String
    let value: String
    var monospaced = false
    var labelWidth: CGFloat = 72

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .font(monospaced ? Theme.mono : .body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

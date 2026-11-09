import SwiftUI

/// Fixed footer: status message on the left, actions on the right.
struct BottomActionBar<Actions: View>: View {
    let message: StatusMessage
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 12) {
            ValidationMessage(text: message.text, kind: message.kind)
                .lineLimit(2)
            Spacer(minLength: 16)
            actions
                .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

import SwiftUI

struct StatusDot: View {
    let kind: StatusKind
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(kind.color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Dot + text, e.g. "KIOXIA connected".
struct StatusLabel: View {
    let text: String
    let kind: StatusKind

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(kind: kind)
            Text(text)
                .foregroundStyle(kind == .neutral ? Color.secondary : kind.color)
        }
        .font(.callout)
    }
}

/// Tinted pill, e.g. "Template found".
struct StatusBadge: View {
    let text: String
    let kind: StatusKind

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(kind: kind)
            Text(text)
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(kind == .neutral ? Color.secondary : kind.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(kind.color.opacity(0.14), in: Capsule())
    }
}

/// Inline message with a status icon; used for validation and the bottom bar.
struct ValidationMessage: View {
    let text: String
    var kind: StatusKind = .danger

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: kind.symbol)
        }
        .font(.callout)
        .foregroundStyle(kind == .neutral ? Color.secondary : kind.color)
    }
}

/// Grey capsule for project types in tables.
struct TagLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.1), in: Capsule())
    }
}

/// Selectable capsule button, e.g. default project types.
struct ChipButtonStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .background(isOn ? Color.accentColor : Color.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Color.clear : Theme.cardBorder))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

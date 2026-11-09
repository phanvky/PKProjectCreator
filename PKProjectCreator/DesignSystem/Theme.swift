import SwiftUI

/// Design tokens for the graphite PKProjectCreator look. Colors lean on system semantics so they stay native.
enum Theme {
    static let cornerRadius: CGFloat = 8
    static let cardFill = Color.primary.opacity(0.04)
    static let cardBorder = Color.primary.opacity(0.09)
    /// Darker well used behind folder trees.
    static let wellFill = Color.black.opacity(0.18)
    static let folderTint = Color(red: 0.36, green: 0.66, blue: 0.96)
    static let fileTint = Color.purple

    static let rowPadding = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
    static let pagePadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 22

    static let sectionTitle = Font.subheadline.weight(.semibold)
    static let mono = Font.system(.callout, design: .monospaced)
}

enum StatusKind {
    case success
    case warning
    case danger
    case neutral

    var color: Color {
        switch self {
        case .success: .green
        case .warning: .orange
        case .danger: .red
        case .neutral: .gray
        }
    }

    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .danger: "exclamationmark.circle.fill"
        case .neutral: "info.circle"
        }
    }
}

struct StatusMessage: Equatable {
    var text: String
    var kind: StatusKind
}

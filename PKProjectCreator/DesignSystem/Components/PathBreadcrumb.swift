import SwiftUI

/// Finder-style path: drive › folder › folder, last component highlighted.
struct PathBreadcrumb: View {
    let path: String
    var isInvalid = false

    private var parts: [String] {
        let all = path.split(separator: "/").map(String.init)
        return all.first == "Volumes" ? Array(all.dropFirst()) : all
    }

    private var isOnVolume: Bool { path.volumeName != nil }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                let isLast = index == parts.count - 1
                Label {
                    Text(part)
                        .fontWeight(isLast ? .semibold : .regular)
                        .foregroundStyle(isLast ? Color.accentColor : Color.secondary)
                } icon: {
                    Image(systemName: index == 0 && isOnVolume ? "externaldrive" : "folder.fill")
                        .foregroundStyle(index == 0 && isOnVolume ? Color.secondary : Theme.folderTint)
                }
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.15), in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isInvalid ? Color.red : Theme.cardBorder))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Destination \(path)")
    }
}

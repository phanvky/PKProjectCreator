import SwiftUI

/// Display model for a folder tree row: template folders plus the project root and the Premiere file.
struct FolderTreeItem: Identifiable {
    enum Kind { case root, folder, file }

    let id: UUID
    var name: String
    var kind: Kind
    var note: String?
    var isMissing = false
    var children: [FolderTreeItem] = []

    struct FilePlacement {
        let id: UUID
        let folderPath: [String]
        let name: String
        let note: String
        let isMissing: Bool
    }

    static func folders(_ nodes: [FolderNode]) -> [FolderTreeItem] {
        items(from: nodes, parentPath: [], file: nil)
    }

    /// Project root → template folders, with the Premiere file placed inside `file.folderPath`.
    static func projectPreview(rootID: UUID, rootName: String, folders: [FolderNode], file: FilePlacement?) -> FolderTreeItem {
        FolderTreeItem(id: rootID, name: rootName, kind: .root, children: items(from: folders, parentPath: [], file: file))
    }

    private static func items(from nodes: [FolderNode], parentPath: [String], file: FilePlacement?) -> [FolderTreeItem] {
        nodes.map { node in
            let path = parentPath + [node.name]
            var children = items(from: node.children, parentPath: path, file: file)
            if let file, file.folderPath == path {
                children.append(FolderTreeItem(id: file.id, name: file.name, kind: .file, note: file.note, isMissing: file.isMissing))
            }
            return FolderTreeItem(id: node.id, name: node.name, kind: .folder, children: children)
        }
    }
}

/// Indented folder tree, optionally collapsible and selectable.
struct FolderTreeView: View {
    let items: [FolderTreeItem]
    @Binding var collapsed: Set<UUID>
    var selection: Binding<UUID?>?
    var showsDisclosure = true
    /// When set, folders can be dragged onto each other: called with (dragged folder, folder it was dropped on).
    var onMove: ((UUID, UUID) -> Void)?

    private struct Row: Identifiable {
        let item: FolderTreeItem
        let depth: Int
        var id: UUID { item.id }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 1) {
            ForEach(rows(items, depth: 0)) { row in
                FolderTreeRow(
                    item: row.item,
                    depth: row.depth,
                    showsDisclosure: showsDisclosure,
                    isExpanded: !collapsed.contains(row.id),
                    isSelected: selection?.wrappedValue == row.id,
                    onToggle: { toggle(row.id) },
                    onSelect: selection.map { binding in { binding.wrappedValue = row.id } }
                )
                .modifier(FolderDragAndDrop(id: row.id, onMove: row.item.kind == .folder ? onMove : nil))
            }
        }
    }

    private func rows(_ items: [FolderTreeItem], depth: Int) -> [Row] {
        items.flatMap { item -> [Row] in
            let expanded = !showsDisclosure || !collapsed.contains(item.id)
            return [Row(item: item, depth: depth)] + (expanded ? rows(item.children, depth: depth + 1) : [])
        }
    }

    private func toggle(_ id: UUID) {
        if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
    }
}

private struct FolderDragAndDrop: ViewModifier {
    let id: UUID
    let onMove: ((UUID, UUID) -> Void)?

    func body(content: Content) -> some View {
        if let onMove {
            content
                .draggable(id.uuidString)
                .dropDestination(for: String.self) { items, _ in
                    guard let dragged = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                    onMove(dragged, id)
                    return true
                }
        } else {
            content
        }
    }
}

private struct FolderTreeRow: View {
    let item: FolderTreeItem
    let depth: Int
    let showsDisclosure: Bool
    let isExpanded: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let onSelect: (() -> Void)?

    private var noteColor: Color { item.isMissing ? StatusKind.warning.color : Color.accentColor }

    var body: some View {
        HStack(spacing: 6) {
            if showsDisclosure {
                Button(action: onToggle) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .opacity(item.children.isEmpty ? 0 : 1)
                .disabled(item.children.isEmpty)
                .accessibilityLabel(isExpanded ? "Collapse \(item.name)" : "Expand \(item.name)")
            }
            Image(systemName: item.kind == .file ? "doc.fill" : "folder.fill")
                .foregroundStyle(item.kind == .file ? Theme.fileTint : Theme.folderTint)
            Text(item.name)
                .fontWeight(item.kind == .root ? .semibold : .regular)
                .strikethrough(item.isMissing)
                .foregroundStyle(item.isMissing ? StatusKind.warning.color : Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let note = item.note {
                Text(note)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(noteColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(noteColor.opacity(0.15), in: Capsule())
                    .fixedSize()
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(depth) * 18 + 6)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(background, in: .rect(cornerRadius: 5))
        .contentShape(Rectangle())
        .onTapGesture { onSelect?() }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        if isSelected { return Color.accentColor.opacity(0.35) }
        if item.kind == .file { return Color.accentColor.opacity(0.1) }
        return .clear
    }
}

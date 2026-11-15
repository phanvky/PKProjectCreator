import SwiftUI

/// A folder tree with its edit toolbar (add, subfolder, move, rename, delete) and drag-and-drop moving.
/// Folder Templates edits a template with it; New Project edits one project's own folders.
struct FolderStructureEditor: View {
    /// The folders being edited (the root is not one of them).
    let nodes: [FolderNode]
    /// What the tree shows: `nodes` under a root row, plus any project files.
    let root: FolderTreeItem
    /// Applies a change, or throws a `FolderEditIssue` and changes nothing.
    let apply: ((inout [FolderNode]) throws -> Void) throws -> Void
    let emptyMessage: String
    var showsDisclosure = false
    var collapsed: Binding<Set<UUID>> = .constant([])
    /// The tree scrolls inside the editor instead of growing with its page.
    var scrolls = false
    /// Why a folder can't be deleted; nil when it can.
    var deleteIssue: (UUID) -> String? = { _ in nil }

    @State private var selectedID: UUID?
    @State private var renameText = ""
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false
    /// Why the last folder action was refused.
    @State private var editIssue: String?

    private var selectedFolder: FolderNode? { selectedID.flatMap(nodes.node(withID:)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if scrolls {
                    ScrollView { tree }
                } else {
                    tree
                }
            }
            .frame(maxWidth: .infinity, maxHeight: scrolls ? .infinity : nil, alignment: .topLeading)
            .background(Theme.wellFill)

            Divider()
            ViewThatFits(in: .horizontal) {
                toolbar.labelStyle(.titleAndIcon)
                toolbar.labelStyle(.iconOnly)
            }
            if let editIssue {
                ValidationMessage(text: editIssue)
                    .padding([.horizontal, .bottom], 12)
            }
        }
        .background(Theme.cardFill, in: .rect(cornerRadius: Theme.cornerRadius))
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder))
        .alert("Rename Folder", isPresented: $isRenaming) {
            TextField("Folder name", text: $renameText)
            Button("Rename") {
                if let id = selectedID { edit { try $0.renameFolder(id, to: renameText) } }
            }
            .disabled(selectedID.flatMap { nodes.folderNameIssue(renameText, for: $0) } != nil)
            Button("Cancel", role: .cancel) {}
        } message: {
            // The text of an open alert doesn't refresh while typing, so the rules are spelled out up front.
            Text("Names can’t be empty, contain “/” or “:”, or repeat another folder at the same level. Everything inside the folder is kept.")
        }
        .confirmationDialog("Delete “\(selectedFolder?.name ?? "")”?", isPresented: $isConfirmingDelete) {
            Button("Delete Folder", role: .destructive) { deleteFolder() }
        } message: {
            let inside = selectedFolder?.children.totalCount ?? 0
            Text(inside == 0 ? "The folder is removed from this list." : "The \(inside) folders inside it are removed too.")
        }
    }

    private var tree: some View {
        VStack(alignment: .leading, spacing: 0) {
            FolderTreeView(
                items: [root],
                collapsed: collapsed,
                selection: $selectedID,
                showsDisclosure: showsDisclosure,
                // Dropping a folder on the project root moves it to the top level.
                onMove: { dragged, target in edit { try $0.move(dragged, intoParent: target == root.id ? nil : target) } }
            )
            if nodes.isEmpty {
                ContentUnavailableView("No Folders", systemImage: "folder.badge.questionmark", description: Text(emptyMessage))
                    .frame(height: 220)
            }
        }
        .padding(10)
    }

    private var toolbar: some View {
        let hasSelection = selectedFolder != nil
        return HStack(spacing: 14) {
            Button("Folder", systemImage: "plus") { addFolder(inParent: nil) }
                .help("Add a top-level folder")
            Button("Subfolder", systemImage: "arrow.turn.down.right") { addFolder(inParent: selectedID) }
                .disabled(!hasSelection)
                .help("Add a folder inside the selected folder")
            Divider().frame(height: 14)
            Button("Move Up", systemImage: "arrow.up") { move(by: -1) }
                .labelStyle(.iconOnly)
                .disabled(!hasSelection)
                .help("Move Up")
            Button("Move Down", systemImage: "arrow.down") { move(by: 1) }
                .labelStyle(.iconOnly)
                .disabled(!hasSelection)
                .help("Move Down")
            Button("Rename", systemImage: "pencil") { startRename(selectedFolder) }
                .disabled(!hasSelection)
                .help("Rename the selected folder")
            Spacer(minLength: 0)
            Button("Delete", systemImage: "minus", role: .destructive) { isConfirmingDelete = true }
                .disabled(!hasSelection)
                .help("Delete the selected folder")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Applies a change and shows why it was refused, if it was.
    private func edit(_ body: (inout [FolderNode]) throws -> Void) {
        do {
            try apply(body)
            editIssue = nil
        } catch {
            editIssue = (error as? FolderEditIssue)?.message ?? error.localizedDescription
        }
    }

    private func addFolder(inParent parentID: UUID?) {
        var added: FolderNode?
        edit { added = $0.addFolder(inParent: parentID) }
        startRename(added)
    }

    private func move(by offset: Int) {
        guard let id = selectedID else { return }
        edit { $0.move(id, by: offset) }
    }

    private func deleteFolder() {
        guard let id = selectedID else { return }
        if let issue = deleteIssue(id) {
            editIssue = issue
            return
        }
        edit { $0.remove(id) }
        selectedID = nil
    }

    private func startRename(_ folder: FolderNode?) {
        guard let folder else { return }
        selectedID = folder.id
        renameText = folder.name
        isRenaming = true
    }
}

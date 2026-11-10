import SwiftUI

/// Editor for one template. Every change goes through AppState, which saves it.
struct FolderTemplateEditor: View {
    @Environment(AppState.self) private var app
    let template: FolderTemplate

    @State private var nameText = ""
    @State private var selectedFolderID: UUID?
    @State private var renameText = ""
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false
    /// Why the last folder action was refused.
    @State private var editIssue: String?

    private var selectedFolder: FolderNode? {
        selectedFolderID.flatMap(template.nodes.node(withID:))
    }

    private var renameIssue: FolderEditIssue? {
        selectedFolderID.flatMap { template.folderNameIssue(renameText, for: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Template Name")
                    TextField("Template Name", text: $nameText)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .labelsHidden()
                        .frame(maxWidth: 440)
                        .onAppear { nameText = template.name }
                        // A valid name is applied as it is typed; an invalid one leaves the saved name unchanged.
                        .onChange(of: nameText) { app.renameTemplate(template.id, to: nameText) }
                    if let issue = app.templateNameIssue(nameText, for: template.id) {
                        ValidationMessage(text: issue)
                            .padding(.horizontal, 6)
                    }
                    if !template.description.isEmpty {
                        Text(template.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Structure") {
                        Text("\(template.folderCount) folders + root · drag a folder onto another to move it inside")
                    }
                    structureCard
                    if let editIssue {
                        ValidationMessage(text: editIssue)
                            .padding(.horizontal, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Default for Project Types")
                    FormCard {
                        HStack(spacing: 8) {
                            ForEach(ProjectType.allCases) { type in
                                let isOn = template.defaultProjectTypes.contains(type)
                                Button(type.rawValue) {
                                    app.setDefault(type, isOn: !isOn, forTemplate: template.id)
                                }
                                .buttonStyle(ChipButtonStyle(isOn: isOn))
                            }
                        }
                        .padding(12)
                    }
                    .disabled(!template.isConfigured)
                    Text(
                        template.isConfigured
                            ? "A type uses one template. Turning a type on here moves it from its current template; a type with no template uses the first configured one."
                            : "Add at least one folder before making this template a default."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                }
            }
            .padding(Theme.pagePadding)
        }
        .alert("Rename Folder", isPresented: $isRenaming) {
            TextField("Folder name", text: $renameText)
            Button("Rename") {
                if let id = selectedFolderID { edit { try $0.renameFolder(id, to: renameText) } }
            }
            .disabled(renameIssue != nil)
            Button("Cancel", role: .cancel) {}
        } message: {
            // The text of an open alert doesn't refresh while typing, so the rules are spelled out up front.
            Text("Names can’t be empty, contain “/” or “:”, or repeat another folder at the same level. Everything inside the folder is kept.")
        }
        .confirmationDialog(
            "Delete “\(selectedFolder?.name ?? "")” from this template?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Delete Folder", role: .destructive) { deleteFolder() }
        } message: {
            let inside = selectedFolder?.children.totalCount ?? 0
            Text(inside == 0 ? "This can’t be undone." : "The \(inside) folders inside it are deleted too. This can’t be undone.")
        }
    }

    private var structureCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text("[Generated Project Name]").italic().foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "folder.fill").foregroundStyle(Theme.folderTint)
            }
            .padding(Theme.rowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            // Dropping a folder on the project root moves it to the top level.
            .dropDestination(for: String.self) { items, _ in
                guard let dragged = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                edit { try $0.nodes.move(dragged, intoParent: nil) }
                return true
            }
            Divider()

            Group {
                if template.nodes.isEmpty {
                    ContentUnavailableView(
                        "Needs Configuration",
                        systemImage: "folder.badge.questionmark",
                        description: Text("Add folders below. This template can’t be used for new projects until it has at least one folder.")
                    )
                    .frame(height: 260)
                } else {
                    FolderTreeView(
                        items: FolderTreeItem.folders(template.nodes),
                        collapsed: .constant([]),
                        selection: $selectedFolderID,
                        showsDisclosure: false,
                        onMove: { dragged, target in edit { try $0.nodes.move(dragged, intoParent: target) } }
                    )
                    .padding(10)
                }
            }
            .background(Theme.wellFill)

            Divider()
            toolbar
        }
        .background(Theme.cardFill, in: .rect(cornerRadius: Theme.cornerRadius))
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder))
    }

    private var toolbar: some View {
        let hasSelection = selectedFolder != nil
        return HStack(spacing: 14) {
            Button("Folder", systemImage: "plus") { addFolder(inParent: nil) }
                .help("Add a top-level folder")
            Button("Subfolder", systemImage: "arrow.turn.down.right") { addFolder(inParent: selectedFolderID) }
                .disabled(!hasSelection)
                .help("Add a folder inside the selected folder")
            Divider().frame(height: 14)
            Button("Move Up", systemImage: "arrow.up") { move(by: -1) }
                .labelStyle(.iconOnly)
                .disabled(!hasSelection)
            Button("Move Down", systemImage: "arrow.down") { move(by: 1) }
                .labelStyle(.iconOnly)
                .disabled(!hasSelection)
            Button("Rename", systemImage: "pencil") { startRename(selectedFolder) }
                .disabled(!hasSelection)
            Spacer()
            Button("Delete", systemImage: "minus", role: .destructive) { isConfirmingDelete = true }
                .disabled(!hasSelection)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Applies a change through AppState (which saves it) and shows why it was refused, if it was.
    private func edit(_ body: (inout FolderTemplate) throws -> Void) {
        do {
            try app.updateTemplate(template.id, body)
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
        guard let id = selectedFolderID else { return }
        edit { $0.nodes.move(id, by: offset) }
    }

    private func deleteFolder() {
        guard let id = selectedFolderID else { return }
        if template.nodes.map(\.id) == [id], !app.canRemoveTemplate(template.id) {
            editIssue = "This is the last folder of the only configured template, so it can’t be deleted."
            return
        }
        edit { $0.nodes.remove(id) }
        selectedFolderID = nil
    }

    private func startRename(_ folder: FolderNode?) {
        guard let folder else { return }
        selectedFolderID = folder.id
        renameText = folder.name
        isRenaming = true
    }
}

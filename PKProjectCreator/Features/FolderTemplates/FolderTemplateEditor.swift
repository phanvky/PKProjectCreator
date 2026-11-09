import SwiftUI

/// In-memory editor for one template. Persistence arrives in a later phase.
struct FolderTemplateEditor: View {
    @Binding var template: FolderTemplate
    let onAssignType: (ProjectType) -> Void

    @State private var selectedFolderID: UUID?
    @State private var renameText = ""
    @State private var isRenaming = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Template Name")
                    TextField("Template Name", text: $template.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .labelsHidden()
                        .frame(maxWidth: 440)
                    if !template.summary.isEmpty {
                        Text(template.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Structure") {
                        Text("\(template.folderCount) folders + root · select a folder to rename")
                    }
                    structureCard
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Default for Project Types")
                    FormCard {
                        HStack(spacing: 8) {
                            ForEach(ProjectType.allCases) { type in
                                let isOn = template.defaultTypes.contains(type)
                                Button(type.rawValue) {
                                    if !isOn { onAssignType(type) }
                                }
                                .buttonStyle(ChipButtonStyle(isOn: isOn))
                            }
                        }
                        .padding(12)
                    }
                    Text("A type uses exactly one template. Selecting a type here moves it from its current template.")
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
                if let id = selectedFolderID { template.folders.rename(id, to: renameText) }
            }
            .disabled(ProjectNaming.issue(forProjectName: renameText, generatedName: renameText) != nil)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Folder names can’t be empty or contain “/” or “:”.")
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
            Divider()

            Group {
                if !template.isStructureSpecified {
                    ContentUnavailableView(
                        "Structure Not Specified Yet",
                        systemImage: "folder.badge.questionmark",
                        description: Text("“\(template.name)” is planned with \(template.folderCount) folders. Its hierarchy will be added once it’s approved.")
                    )
                    .frame(height: 260)
                } else if template.folders.isEmpty {
                    ContentUnavailableView("No Folders", systemImage: "folder", description: Text("Add a folder below."))
                        .frame(height: 200)
                } else {
                    FolderTreeView(
                        items: FolderTreeItem.folders(template.folders),
                        collapsed: .constant([]),
                        selection: $selectedFolderID,
                        showsDisclosure: false
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
        let hasSelection = selectedFolderID != nil
        return HStack(spacing: 14) {
            Button("Folder", systemImage: "plus") { addFolder() }
            Button("Subfolder", systemImage: "arrow.turn.down.right") { addSubfolder() }
                .disabled(!hasSelection)
            Divider().frame(height: 14)
            Button("Move Up", systemImage: "arrow.up") { move(by: -1) }
                .labelStyle(.iconOnly)
                .disabled(!hasSelection)
            Button("Move Down", systemImage: "arrow.down") { move(by: 1) }
                .labelStyle(.iconOnly)
                .disabled(!hasSelection)
            Button("Rename", systemImage: "pencil") { startRename() }
                .disabled(!hasSelection)
            Spacer()
            Button("Delete", systemImage: "minus", role: .destructive) { deleteFolder() }
                .disabled(!hasSelection)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func addFolder() {
        let node = FolderNode("New Folder")
        if let id = selectedFolderID {
            template.folders.insert(node, after: id)
        } else {
            template.folders.append(node)
        }
        selectedFolderID = node.id
        startRename()
    }

    private func addSubfolder() {
        guard let id = selectedFolderID else { return }
        let node = FolderNode("New Folder")
        template.folders.appendChild(node, to: id)
        selectedFolderID = node.id
        startRename()
    }

    private func move(by offset: Int) {
        guard let id = selectedFolderID else { return }
        template.folders.move(id, by: offset)
    }

    private func deleteFolder() {
        guard let id = selectedFolderID else { return }
        template.folders.remove(id)
        selectedFolderID = nil
    }

    private func startRename() {
        guard let id = selectedFolderID else { return }
        renameText = template.folders.node(withID: id)?.name ?? ""
        isRenaming = true
    }
}

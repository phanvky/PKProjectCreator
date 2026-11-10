import SwiftUI

/// Edits the folders of a project that already exists. Shown as a sheet from Recent Projects.
struct ProjectUpdateView: View {
    @Environment(AppState.self) private var app
    let initial: ProjectUpdateSession
    /// Always the live form; `initial` only covers the moment the sheet closes.
    private var session: ProjectUpdateSession { app.projectUpdate ?? initial }

    @State private var selectedID: FolderNode.ID?
    @State private var renameText = ""
    @State private var isRenaming = false
    @State private var isConfirmingDeletes = false
    @State private var editIssue: String?

    private var plan: ProjectUpdatePlan { app.projectUpdatePlan ?? ProjectUpdatePlan() }
    private var lockReason: String? { selectedID.flatMap(session.lockReason) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Theme.pagePadding) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Folders on Disk") {
                        Text("Add folders anywhere · empty folders can be renamed or deleted")
                    }
                    treeCard
                    if let message = editIssue ?? lockReason {
                        ValidationMessage(text: message, kind: .warning)
                            .padding(.horizontal, 6)
                    }
                }
                .frame(minWidth: 420, maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    projectFiles
                    changes
                }
                .frame(width: 320)
            }
            .padding(Theme.pagePadding)

            BottomActionBar(message: status) {
                if app.projectUpdateTask != nil { ProgressView().controlSize(.small) }
                Button("Cancel", role: .cancel) { app.projectUpdate = nil }
                    .disabled(app.projectUpdateTask != nil)
                Button("Update") { plan.deletes.isEmpty ? app.applyProjectUpdate() : (isConfirmingDeletes = true) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(app.projectUpdateBlocker != nil || app.projectUpdateTask != nil)
            }
        }
        .frame(minWidth: 880, minHeight: 600)
        .alert("Rename Folder", isPresented: $isRenaming) {
            TextField("Folder name", text: $renameText)
            Button("Rename") { rename() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Names can’t be empty, contain “/” or “:”, or repeat another folder at the same level.")
        }
        .confirmationDialog("Delete \(plan.deletes.count) empty \(plan.deletes.count == 1 ? "folder" : "folders")?", isPresented: $isConfirmingDeletes) {
            Button("Update and Delete", role: .destructive) { app.applyProjectUpdate() }
        } message: {
            Text(plan.deletes.map { "• " + $0.joined(separator: "/") }.joined(separator: "\n")
                + "\n\nOnly empty folders are deleted. A folder that has anything inside by then is kept.")
        }
    }

    private var status: StatusMessage {
        if app.projectUpdateTask != nil { return StatusMessage(text: "Updating “\(session.project.name)”…", kind: .neutral) }
        let count = plan.renames.count + plan.creates.count + plan.deletes.count
            + (plan.premiereFolder == nil ? 0 : 1) + (plan.resolveFolder == nil ? 0 : 1)
        return app.projectUpdateBlocker ?? StatusMessage(text: "Ready to make \(count) \(count == 1 ? "change" : "changes") in “\(session.project.name)”.", kind: .success)
    }

    // MARK: Tree

    private var treeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text(session.project.name).fontWeight(.medium)
            } icon: {
                Image(systemName: "folder.fill").foregroundStyle(Theme.folderTint)
            }
            .padding(Theme.rowPadding)
            Divider()
            ScrollView {
                FolderTreeView(items: items(session.nodes), collapsed: .constant([]), selection: $selectedID, showsDisclosure: false)
                    .padding(10)
            }
            .frame(minHeight: 340)
            .background(Theme.wellFill)
            Divider()
            HStack(spacing: 14) {
                Button("Folder", systemImage: "plus") { add(inParent: nil) }
                    .help("Add a top-level folder")
                Button("Subfolder", systemImage: "arrow.turn.down.right") { add(inParent: selectedID) }
                    .disabled(selectedID == nil)
                    .help("Add a folder inside the selected folder")
                Button("Rename", systemImage: "pencil") { startRename() }
                    .disabled(selectedID == nil || lockReason != nil)
                Spacer()
                Button("Delete", systemImage: "minus", role: .destructive) { delete() }
                    .disabled(selectedID == nil || lockReason != nil)
                    .help("Only empty folders can be deleted")
            }
            .buttonStyle(.borderless)
            .padding(Theme.rowPadding)
        }
        .background(Theme.cardFill, in: .rect(cornerRadius: Theme.cornerRadius))
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder))
    }

    private func items(_ nodes: [FolderNode]) -> [FolderTreeItem] {
        nodes.map { node in
            FolderTreeItem(id: node.id, name: node.name, kind: .folder, note: note(for: node), children: items(node.children))
        }
    }

    private func note(for node: FolderNode) -> String {
        guard let folder = session.existing(node.id) else { return "new" }
        var parts: [String] = []
        if folder.path.last != node.name { parts.append("renamed · was “\(folder.path.last ?? "")”") }
        parts.append(folder.isEmpty ? "empty" : "🔒 \(folder.itemCount) \(folder.itemCount == 1 ? "item" : "items")")
        if folder.hasDeeperFolders { parts.append("more folders inside") }
        return parts.joined(separator: " · ")
    }

    // MARK: Side panels

    private var projectFiles: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Project Files")
            FormCard {
                fileToggle(
                    "Add Premiere project", isOn: binding(\.addPremiere), canAdd: session.canAddPremiere,
                    folder: app.premiere.destinationFolder, template: app.premiereTemplate
                )
                fileToggle(
                    "Add DaVinci Resolve project", isOn: binding(\.addResolve), canAdd: session.canAddResolve,
                    folder: app.premiere.resolveFolder, template: app.resolveTemplate
                )
            }
            Text("A project file is only added when the project has none yet. Existing files are never replaced.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
    }

    private func fileToggle(_ title: String, isOn: Binding<Bool>, canAdd: Bool, folder: [String], template: ResourceStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: isOn)
                .disabled(!canAdd)
            Text(canAdd ? "Into \(folder.joined(separator: "/")) · template \(template.templateLabel.lowercased())" : "Already in this project")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var changes: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Changes")
            FormCard {
                VStack(alignment: .leading, spacing: 6) {
                    if plan.isEmpty {
                        Text("Nothing yet. Add a folder, or choose a project file above.").foregroundStyle(.secondary)
                    }
                    ForEach(plan.renames, id: \.from) { change("pencil", "Rename \(text(change: $0.from)) → \($0.to.last ?? "")") }
                    ForEach(plan.creates, id: \.self) { change("plus", "Add \(text(change: $0))") }
                    if let folder = plan.premiereFolder { change("doc.badge.plus", "Premiere project in \(text(change: folder))") }
                    if let folder = plan.resolveFolder { change("doc.badge.plus", "DaVinci Resolve project in \(text(change: folder))") }
                    ForEach(plan.deletes, id: \.self) { change("trash", "Delete empty \(text(change: $0))", color: .red) }
                }
                .font(.callout)
                .padding(Theme.rowPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func change(_ symbol: String, _ text: String, color: Color = .primary) -> some View {
        Label(text, systemImage: symbol)
            .foregroundStyle(color)
            .lineLimit(2)
            .truncationMode(.middle)
    }

    private func text(change path: [String]) -> String { path.joined(separator: "/") }

    // MARK: Actions

    private func binding(_ keyPath: WritableKeyPath<ProjectUpdateSession, Bool>) -> Binding<Bool> {
        Binding(
            get: { app.projectUpdate?[keyPath: keyPath] ?? false },
            set: { app.projectUpdate?[keyPath: keyPath] = $0 }
        )
    }

    private func add(inParent parentID: FolderNode.ID?) {
        guard let added = app.projectUpdate?.addFolder(inParent: parentID) else { return }
        editIssue = nil
        selectedID = added.id
        startRename()
    }

    private func startRename() {
        guard let id = selectedID, let node = session.nodes.node(withID: id) else { return }
        renameText = node.name
        isRenaming = true
    }

    private func rename() {
        guard let id = selectedID else { return }
        do {
            try app.projectUpdate?.rename(id, to: renameText)
            editIssue = nil
        } catch {
            editIssue = (error as? FolderEditIssue)?.message ?? error.localizedDescription
        }
    }

    private func delete() {
        guard let id = selectedID else { return }
        app.projectUpdate?.delete(id)
        selectedID = nil
        editIssue = nil
    }
}

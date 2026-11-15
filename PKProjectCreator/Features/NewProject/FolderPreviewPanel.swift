import SwiftUI

/// Right column of New Project: the full tree that will be created, root included. Its folders can be changed
/// for this project only; the template stays as it is.
struct FolderPreviewPanel: View {
    @Environment(AppState.self) private var app
    @State private var collapsed: Set<UUID> = []

    private static let rootID = UUID()
    private static let premiereFileID = UUID()
    private static let resolveFileID = UUID()

    var body: some View {
        let plan = app.creationPlan
        let root = previewRoot(plan)

        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Folder Preview") {
                HStack(spacing: 10) {
                    Text(summary(plan))
                    if app.draft.folders != nil {
                        Button("Reset to Template", systemImage: "arrow.uturn.backward") { app.draft.folders = nil }
                            .labelStyle(.iconOnly)
                            .help("Undo this project’s folder changes and use “\(app.selectedTemplate?.name ?? "")” as it is")
                    }
                    Button {
                        collapsed = []
                    } label: {
                        Label("Expand All", systemImage: "arrow.up.left.and.arrow.down.right").labelStyle(.iconOnly)
                    }
                    .help("Expand All")
                    Button {
                        collapsed = Set(Self.folderIDsWithChildren(root.children))
                    } label: {
                        Label("Collapse All", systemImage: "arrow.down.right.and.arrow.up.left").labelStyle(.iconOnly)
                    }
                    .help("Collapse All")
                }
                .buttonStyle(.borderless)
            }

            FolderStructureEditor(
                nodes: plan.folders,
                root: root,
                apply: { change in try app.editProjectFolders(change) },
                emptyMessage: "Add this project’s folders with the buttons below, or click Reset to Template.",
                showsDisclosure: true,
                collapsed: $collapsed,
                scrolls: true
            )

            Text(app.draft.folders == nil
                ? "Changes here apply to this project only. The template is not changed."
                : "Edited for this project only. “\(app.selectedTemplate?.name ?? "")” is not changed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
    }

    /// Drawn from the same plan that Create Project executes.
    private func previewRoot(_ plan: ProjectCreationPlan) -> FolderTreeItem {
        var files: [FolderTreeItem.FilePlacement] = []
        if let folder = plan.premiereFolder {
            files.append(FolderTreeItem.FilePlacement(
                id: Self.premiereFileID,
                folderPath: folder,
                name: "\(app.displayName).prproj",
                note: app.premiereTemplate.isReady ? "from template" : "template not ready",
                isMissing: !app.premiereTemplate.isReady
            ))
        }
        if let folder = plan.resolveFolder {
            files.append(FolderTreeItem.FilePlacement(
                id: Self.resolveFileID,
                folderPath: folder,
                name: "\(app.displayName).\(PremiereTemplateService.resolveExtension)",
                note: app.resolveTemplate.isReady ? "from template" : "template not ready",
                isMissing: !app.resolveTemplate.isReady
            ))
        }
        return FolderTreeItem.projectPreview(rootID: Self.rootID, rootName: app.displayName, folders: plan.folders, files: files)
    }

    private func summary(_ plan: ProjectCreationPlan) -> String {
        let paths = plan.folders.allPaths
        let files = [plan.premiereFolder, plan.resolveFolder].compactMap(\.self).filter(paths.contains).count
        return "\(plan.directoryCount) directories (root + \(plan.directoryCount - 1)) · \(files) \(files == 1 ? "file" : "files")"
    }

    private static func folderIDsWithChildren(_ items: [FolderTreeItem]) -> [UUID] {
        items.flatMap { item in
            (item.children.isEmpty ? [] : [item.id]) + folderIDsWithChildren(item.children)
        }
    }
}

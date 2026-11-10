import SwiftUI

/// Right column of New Project: the full tree that will be created, root included.
struct FolderPreviewPanel: View {
    @Environment(AppState.self) private var app
    @State private var collapsed: Set<UUID> = []

    private static let rootID = UUID()
    private static let premiereFileID = UUID()
    private static let resolveFileID = UUID()

    var body: some View {
        let template = app.selectedTemplate
        let plan = app.creationPlan
        let root = previewRoot(plan)

        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Folder Preview") {
                HStack(spacing: 10) {
                    Text(summary(plan))
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

            Group {
                if let template, template.isConfigured {
                    ScrollView {
                        FolderTreeView(items: [root], collapsed: $collapsed)
                            .padding(10)
                    }
                } else {
                    ContentUnavailableView(
                        "Needs Configuration",
                        systemImage: "folder.badge.questionmark",
                        description: Text("Add this template’s folders in Folder Templates.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.wellFill, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder))
        }
    }

    /// Drawn from the same plan that Create Project executes.
    private func previewRoot(_ plan: ProjectCreationPlan) -> FolderTreeItem {
        var files: [FolderTreeItem.FilePlacement] = []
        if plan.createsPremiereProject {
            files.append(FolderTreeItem.FilePlacement(
                id: Self.premiereFileID,
                folderPath: app.premiere.destinationFolder,
                name: "\(app.displayName).prproj",
                note: app.premiereTemplate.isReady ? "from template" : "template not ready",
                isMissing: !app.premiereTemplate.isReady
            ))
        }
        if plan.createsResolveProject {
            files.append(FolderTreeItem.FilePlacement(
                id: Self.resolveFileID,
                folderPath: app.premiere.resolveFolder,
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

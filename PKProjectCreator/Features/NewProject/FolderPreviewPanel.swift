import SwiftUI

/// Right column of New Project: the full tree that will be created, root included.
struct FolderPreviewPanel: View {
    @Environment(AppState.self) private var app
    @State private var collapsed: Set<UUID> = []

    private static let rootID = UUID()
    private static let premiereFileID = UUID()

    var body: some View {
        let template = app.selectedTemplate
        let root = previewRoot(template)

        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Folder Preview") {
                HStack(spacing: 10) {
                    Text(summary(template))
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
                if let template, template.isStructureSpecified {
                    ScrollView {
                        FolderTreeView(items: [root], collapsed: $collapsed)
                            .padding(10)
                    }
                } else {
                    ContentUnavailableView(
                        "Structure Not Specified Yet",
                        systemImage: "folder.badge.questionmark",
                        description: Text("This template’s folder hierarchy hasn’t been approved yet.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.wellFill, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder))
        }
    }

    private func previewRoot(_ template: FolderTemplate?) -> FolderTreeItem {
        let folders = template?.folders ?? []
        let file: FolderTreeItem.FilePlacement? = app.draft.createPremiere
            ? FolderTreeItem.FilePlacement(
                id: Self.premiereFileID,
                folderPath: app.premiere.destinationFolder,
                name: "\(app.displayName).prproj",
                note: app.premiere.status == .missing ? "template missing" : "from template",
                isMissing: app.premiere.status == .missing
            )
            : nil
        return FolderTreeItem.projectPreview(rootID: Self.rootID, rootName: app.displayName, folders: folders, file: file)
    }

    private func summary(_ template: FolderTemplate?) -> String {
        let count = template?.folderCount ?? 0
        let destinationExists = template?.folders.allPaths.contains(app.premiere.destinationFolder) ?? false
        let files = app.draft.createPremiere && destinationExists ? 1 : 0
        return "\(count + 1) directories (root + \(count)) · \(files) \(files == 1 ? "file" : "files")"
    }

    private static func folderIDsWithChildren(_ items: [FolderTreeItem]) -> [UUID] {
        items.flatMap { item in
            (item.children.isEmpty ? [] : [item.id]) + folderIDsWithChildren(item.children)
        }
    }
}

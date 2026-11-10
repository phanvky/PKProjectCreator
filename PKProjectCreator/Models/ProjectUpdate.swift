import Foundation

/// One folder of an existing project, as found on disk when Update Project opened.
nonisolated struct ScannedFolder: Hashable, Sendable {
    /// Path from the project root, e.g. `["04_Project", "Premiere Pro"]`.
    let path: [String]
    /// Everything inside except Finder's `.DS_Store` and `._` metadata files: files, folders, hidden items.
    let itemCount: Int
    /// Folders below the scan depth that aren't shown.
    let hasDeeperFolders: Bool

    var isEmpty: Bool { itemCount == 0 }
}

/// What Update Project found on disk.
nonisolated struct ProjectScan: Sendable {
    var nodes: [FolderNode]
    var folders: [FolderNode.ID: ScannedFolder]
    /// A `.prproj` is already in the Premiere folder.
    var premiereFileExists: Bool
    /// A `.drp` is already in the DaVinci Resolve folder.
    var resolveFileExists: Bool
}

/// The Update Project form. Rules: folders can be added anywhere; an existing folder can be renamed or deleted only
/// while it is empty; nothing is moved; Premiere / Resolve files are only added when the project has none yet.
struct ProjectUpdateSession: Identifiable {
    let project: RecentProject
    let scan: ProjectScan
    var nodes: [FolderNode]
    var addPremiere = false
    var addResolve = false

    var id: RecentProject.ID { project.id }

    init(project: RecentProject, scan: ProjectScan) {
        self.project = project
        self.scan = scan
        nodes = scan.nodes
    }

    var canAddPremiere: Bool { !project.hasPremiereProject && !scan.premiereFileExists }
    var canAddResolve: Bool { project.resolveProjectRelativePath == nil && !scan.resolveFileExists }

    func existing(_ id: FolderNode.ID) -> ScannedFolder? { scan.folders[id] }

    /// Why `id` can't be renamed or deleted; nil when it can.
    func lockReason(_ id: FolderNode.ID) -> String? {
        guard let folder = existing(id), !folder.isEmpty else { return nil }
        return "“\(folder.path.last ?? "")” has \(folder.itemCount) \(folder.itemCount == 1 ? "item" : "items") inside, so it can’t be renamed or deleted."
    }

    @discardableResult
    mutating func addFolder(inParent parentID: FolderNode.ID?) -> FolderNode {
        let siblings = parentID.map { nodes.node(withID: $0)?.children ?? [] } ?? nodes
        let node = FolderNode(FolderNaming.uniqueName("New Folder", among: siblings.map(\.name)))
        if let parentID { nodes.appendChild(node, to: parentID) } else { nodes.append(node) }
        return node
    }

    func nameIssue(_ name: String, for id: FolderNode.ID) -> FolderEditIssue? {
        let siblings = nodes.siblings(of: id)?.filter { $0.id != id }.map(\.name) ?? []
        return FolderNaming.issue(for: name, siblings: siblings)
    }

    mutating func rename(_ id: FolderNode.ID, to name: String) throws {
        guard lockReason(id) == nil else { return }
        if let issue = nameIssue(name, for: id) { throw issue }
        nodes.rename(id, to: name)
    }

    mutating func delete(_ id: FolderNode.ID) {
        guard lockReason(id) == nil else { return }
        nodes.remove(id)
    }

    /// The disk changes this form describes.
    func plan(premiereFolder: [String], resolveFolder: [String]) -> ProjectUpdatePlan {
        var plan = ProjectUpdatePlan()
        func walk(_ nodes: [FolderNode], path: [String]) {
            for node in nodes {
                let current = path + [node.name]
                if let folder = existing(node.id) {
                    if folder.path.last != node.name {
                        // A renamed folder is empty, so its parent kept its original name and path.
                        plan.renames.append(.init(from: folder.path, to: Array(folder.path.dropLast()) + [node.name]))
                    }
                } else {
                    plan.creates.append(current)
                }
                walk(node.children, path: current)
            }
        }
        walk(nodes, path: [])
        let kept = Set(nodes.allIDs)
        plan.deletes = scan.folders.filter { !kept.contains($0.key) }.map(\.value.path).sorted { $0.count > $1.count }
        if addPremiere && canAddPremiere { plan.premiereFolder = premiereFolder }
        if addResolve && canAddResolve { plan.resolveFolder = resolveFolder }
        return plan
    }
}

/// What Update Project will do on disk, in this order: renames, new folders, project files, deletes.
nonisolated struct ProjectUpdatePlan: Equatable, Sendable {
    struct Rename: Equatable, Sendable {
        let from: [String]
        let to: [String]
    }

    var renames: [Rename] = []
    var creates: [[String]] = []
    var deletes: [[String]] = []
    var premiereFolder: [String]?
    var resolveFolder: [String]?

    var isEmpty: Bool { renames.isEmpty && creates.isEmpty && deletes.isEmpty && premiereFolder == nil && resolveFolder == nil }

    /// Every folder that exists once the renames and new folders are done, plus `existing`.
    func foldersAfter(existing: [[String]]) -> Set<[String]> {
        var folders = Set(existing)
        for rename in renames { folders.remove(rename.from); folders.insert(rename.to) }
        folders.formUnion(creates)
        return folders
    }
}

nonisolated extension Array where Element == FolderNode {
    var allIDs: [FolderNode.ID] { flatMap { [$0.id] + $0.children.allIDs } }
}

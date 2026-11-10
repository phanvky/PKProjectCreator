import Foundation

struct FolderTemplate: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var description: String
    /// Top-level folders. A template is configured (usable for new projects) once it has at least one folder.
    var nodes: [FolderNode] {
        didSet {
            isConfigured = !nodes.isEmpty
            if !isConfigured { defaultProjectTypes = [] }
        }
    }
    /// Only a configured template can be a default.
    var defaultProjectTypes: [ProjectType]
    var isConfigured: Bool

    init(id: UUID = UUID(), name: String, description: String = "", nodes: [FolderNode] = [], defaultProjectTypes: [ProjectType] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.nodes = nodes
        self.isConfigured = !nodes.isEmpty
        self.defaultProjectTypes = nodes.isEmpty ? [] : defaultProjectTypes
    }

    /// Folders below the project root.
    var folderCount: Int { nodes.totalCount }

    /// Default types in the app's standard order, for display.
    var defaultTypesList: [ProjectType] {
        ProjectType.allCases.filter(defaultProjectTypes.contains)
    }
}

// MARK: Folder editing

extension FolderTemplate {
    /// Adds "New Folder" (with a number if that name is taken) at the top level or inside `parentID`.
    @discardableResult
    mutating func addFolder(inParent parentID: UUID? = nil) -> FolderNode {
        let siblings = parentID.map { nodes.node(withID: $0)?.children ?? [] } ?? nodes
        let node = FolderNode(FolderNaming.uniqueName("New Folder", among: siblings.map(\.name)))
        if let parentID { nodes.appendChild(node, to: parentID) } else { nodes.append(node) }
        return node
    }

    func folderNameIssue(_ name: String, for id: UUID) -> FolderEditIssue? {
        let siblings = nodes.siblings(of: id)?.filter { $0.id != id }.map(\.name) ?? []
        return FolderNaming.issue(for: name, siblings: siblings)
    }

    /// Renames one folder; everything inside it is kept.
    mutating func renameFolder(_ id: UUID, to name: String) throws {
        if let issue = folderNameIssue(name, for: id) { throw issue }
        nodes.rename(id, to: name)
    }

    /// A copy with new IDs everywhere and no default project types.
    func duplicated(named name: String) -> FolderTemplate {
        FolderTemplate(name: name, description: description, nodes: nodes.withNewIDs)
    }

    /// Repairs data that breaks the rules: only configured templates hold defaults, and a type has at most one template.
    static func normalized(_ templates: [FolderTemplate]) -> [FolderTemplate] {
        var taken: Set<ProjectType> = []
        return templates.map { template in
            var template = template
            template.isConfigured = !template.nodes.isEmpty
            template.defaultProjectTypes = template.isConfigured
                ? template.defaultProjectTypes.filter { taken.insert($0).inserted }
                : []
            return template
        }
    }
}

// MARK: Built-in templates (seeded on first launch only)

extension FolderTemplate {
    static func builtIn() -> [FolderTemplate] {
        [standardProduction(), reelsLite()]
    }

    /// The approved PHANKY FILM structure: 18 folders, 19 with the project root.
    static func standardProduction() -> FolderTemplate {
        FolderTemplate(
            name: "Standard Production",
            description: "Multi-camera events, tournaments and commercials.",
            nodes: [
                FolderNode("01_Footages", children: ["Cam 01", "Cam 02", "Flycam", "FPV", "Cam 360", "Action Cam"].map { FolderNode($0) }),
                FolderNode("02_Music"),
                FolderNode("03_SFX"),
                FolderNode("04_Project", children: ["Premiere Pro", "DaVinci Resolve", "After Effects"].map { FolderNode($0) }),
                FolderNode("05_AI", children: [FolderNode("Images"), FolderNode("Video")]),
                FolderNode("06_Graphic"),
                FolderNode("07_Export"),
            ],
            defaultProjectTypes: [.event, .psc, .psh, .tour, .golfTournament, .tvc]
        )
    }

    /// Planned with 9 folders including the root, but the hierarchy was never supplied, so it starts with no
    /// folders and is not a default for any type until the user configures it.
    static func reelsLite() -> FolderTemplate {
        FolderTemplate(
            name: "Reels — Lite",
            description: "Short-form social content. Planned with 9 folders including the root; the folder names haven’t been supplied yet."
        )
    }
}

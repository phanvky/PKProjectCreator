import Foundation

/// One folder in a template hierarchy. The project root is not a node; it is added at creation time.
/// Folders are identified by `id`, never by name.
struct FolderNode: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var children: [FolderNode]

    init(_ name: String, children: [FolderNode] = [], id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.children = children
    }
}

extension Array where Element == FolderNode {
    /// Number of folders at every depth (the project root is not counted).
    var totalCount: Int {
        reduce(0) { $0 + 1 + $1.children.totalCount }
    }

    /// Every folder path, depth-first, e.g. `["04_Project", "Premiere Pro"]`.
    var allPaths: [[String]] {
        flatMap { node in
            [[node.name]] + node.children.allPaths.map { [node.name] + $0 }
        }
    }

    /// The same tree with a new ID for every folder, for duplicated templates.
    var withNewIDs: [FolderNode] {
        map { FolderNode($0.name, children: $0.children.withNewIDs) }
    }

    func node(withID id: UUID) -> FolderNode? {
        for node in self {
            if node.id == id { return node }
            if let found = node.children.node(withID: id) { return found }
        }
        return nil
    }

    /// The folders at the same level as `id`, including `id` itself.
    func siblings(of id: UUID) -> [FolderNode]? {
        if contains(where: { $0.id == id }) { return self }
        for node in self {
            if let found = node.children.siblings(of: id) { return found }
        }
        return nil
    }

    /// Finds the sibling array that holds `id` and lets `body` edit it in place.
    @discardableResult
    mutating func modifySiblings(of id: UUID, _ body: (inout [FolderNode], Int) -> Void) -> Bool {
        if let index = firstIndex(where: { $0.id == id }) {
            body(&self, index)
            return true
        }
        for index in indices {
            if self[index].children.modifySiblings(of: id, body) { return true }
        }
        return false
    }

    mutating func rename(_ id: UUID, to name: String) {
        modifySiblings(of: id) { siblings, index in siblings[index].name = name }
    }

    mutating func remove(_ id: UUID) {
        modifySiblings(of: id) { siblings, index in siblings.remove(at: index) }
    }

    mutating func appendChild(_ node: FolderNode, to id: UUID) {
        modifySiblings(of: id) { siblings, index in siblings[index].children.append(node) }
    }

    /// Moves a folder up (negative offset) or down among its siblings; no-op at the edges.
    mutating func move(_ id: UUID, by offset: Int) {
        modifySiblings(of: id) { siblings, index in
            let target = index + offset
            guard siblings.indices.contains(target) else { return }
            siblings.swapAt(index, target)
        }
    }

    /// Moves a folder, with everything inside it, into another folder — or to the top level when `parentID` is nil.
    mutating func move(_ id: UUID, intoParent parentID: UUID?) throws {
        guard let node = node(withID: id) else { return }
        if parentID == id { throw FolderEditIssue.moveIntoItself }
        var newSiblings = self
        if let parentID {
            if node.children.node(withID: parentID) != nil { throw FolderEditIssue.moveIntoDescendant }
            guard let parent = self.node(withID: parentID) else { return }
            newSiblings = parent.children
        }
        let names = newSiblings.filter { $0.id != id }.map(\.name)
        if let issue = FolderNaming.issue(for: node.name, siblings: names) { throw issue }
        remove(id)
        if let parentID { appendChild(node, to: parentID) } else { append(node) }
    }
}

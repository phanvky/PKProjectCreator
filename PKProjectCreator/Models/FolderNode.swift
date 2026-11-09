import Foundation

/// One folder in a template hierarchy. The project root is not a node; it is added at creation time.
struct FolderNode: Identifiable, Hashable {
    let id: UUID
    var name: String
    var children: [FolderNode]

    init(_ name: String, children: [FolderNode] = []) {
        self.id = UUID()
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

    func node(withID id: UUID) -> FolderNode? {
        for node in self {
            if node.id == id { return node }
            if let found = node.children.node(withID: id) { return found }
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

    mutating func insert(_ node: FolderNode, after id: UUID) {
        modifySiblings(of: id) { siblings, index in siblings.insert(node, at: index + 1) }
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
}

import Foundation

/// Why a folder edit was refused.
nonisolated enum FolderEditIssue: Error, Equatable {
    case empty
    case forbiddenCharacter
    case controlCharacter
    case reservedName
    case tooLong
    case duplicateName
    case moveIntoItself
    case moveIntoDescendant

    var message: String {
        switch self {
        case .empty: "Enter a folder name."
        case .forbiddenCharacter: "Folder names can’t contain “/” or “:” on macOS."
        case .controlCharacter: "Folder names can’t contain line breaks or control characters."
        case .reservedName: "“.” and “..” can’t be used as folder names."
        case .tooLong: "This name is too long for a macOS folder name (255 bytes max)."
        case .duplicateName: "Another folder at this level already has this name."
        case .moveIntoItself: "A folder can’t be moved into itself."
        case .moveIntoDescendant: "A folder can’t be moved into one of its own subfolders."
        }
    }
}

/// macOS rules for one folder name. The text is validated, never rewritten.
nonisolated enum FolderNaming {
    static func issue(for name: String, siblings: [String]) -> FolderEditIssue? {
        if name.isBlank { return .empty }
        if name == "." || name == ".." { return .reservedName }
        if name.contains(where: { $0 == "/" || $0 == ":" }) { return .forbiddenCharacter }
        if name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) { return .controlCharacter }
        if name.utf8.count > 255 { return .tooLong }
        if siblings.contains(where: { sameName($0, name) }) { return .duplicateName }
        return nil
    }

    /// Mac volumes ignore letter case by default, so "Cam 01" and "cam 01" are the same folder.
    static func sameName(_ a: String, _ b: String) -> Bool {
        a.lowercased() == b.lowercased()
    }

    /// "New Folder", then "New Folder 2", "New Folder 3"…
    static func uniqueName(_ base: String, among existing: [String]) -> String {
        var name = base
        var number = 2
        while existing.contains(where: { sameName($0, name) }) {
            name = "\(base) \(number)"
            number += 1
        }
        return name
    }
}

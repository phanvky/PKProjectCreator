import Foundation

/// The one place that turns filesystem errors into words a user can act on. The system's own text is kept only as
/// a detail after the explanation.
nonisolated enum FileErrorText {
    static func describe(_ error: Error) -> String {
        let error = error as NSError
        if let known = explanation(for: error) { return known }
        // The app's own errors already explain themselves; only raw system errors get a lead-in.
        guard [NSCocoaErrorDomain, NSPOSIXErrorDomain, NSURLErrorDomain].contains(error.domain) else { return error.localizedDescription }
        return "A disk operation failed (\(error.localizedDescription))."
    }

    private static func explanation(for error: NSError) -> String? {
        if error.domain == NSCocoaErrorDomain {
            switch CocoaError.Code(rawValue: error.code) {
            case .fileWriteOutOfSpace: return outOfSpace
            case .fileWriteNoPermission, .fileReadNoPermission: return noPermission
            case .fileWriteVolumeReadOnly: return readOnly
            case .fileNoSuchFile, .fileReadNoSuchFile: return gone
            case .fileWriteFileExists: return "Something with the same name is already there. Nothing was replaced."
            default: break
            }
        }
        if error.domain == NSPOSIXErrorDomain {
            switch Int32(error.code) {
            case ENOSPC, EDQUOT: return outOfSpace
            case EACCES, EPERM: return noPermission
            case EROFS: return readOnly
            case ENOENT, ENXIO, EIO, ENODEV: return gone
            default: break
            }
        }
        return (error.userInfo[NSUnderlyingErrorKey] as? NSError).flatMap(explanation(for:))
    }

    private static let outOfSpace = "There isn’t enough free space on the drive. Free up space, then try again."
    private static let noPermission = "macOS didn’t allow PKProjectCreator to write there. Choose the folder again to reauthorize it."
    private static let readOnly = "The drive is read-only, so nothing can be written to it."
    private static let gone = "A file or folder was no longer there. The drive may have been disconnected; reconnect it and try again."
}

nonisolated extension FileManager {
    /// Removes `folder` only if it is empty apart from Finder metadata (`.DS_Store`, `._*`). Never recursive: the
    /// final step is `rmdir`, which the system refuses for a folder that still has anything inside.
    func removeEmptyFolder(at folder: URL) throws {
        let entries = try contentsOfDirectory(atPath: folder.plainPath)
        guard entries.allSatisfy(ProjectUpdateService.isMetadata) else {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSLocalizedDescriptionKey: "“\(folder.lastPathComponent)” isn’t empty."])
        }
        for name in entries {
            let item = folder.appending(path: name)
            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true else { continue }
            try removeItem(at: item)
        }
        guard rmdir(folder.plainPath) == 0 else { throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO) }
    }
}

nonisolated extension Array where Element == FolderNode {
    /// The first folder whose name breaks the macOS rules (empty, "/", ":", "..", duplicate…); nil when all are fine.
    /// Guards against a hand-edited `folder-templates.json` pointing outside the project.
    var firstInvalidPath: [String]? {
        for node in self {
            let siblings = filter { $0.id != node.id }.map(\.name)
            if FolderNaming.issue(for: node.name, siblings: siblings) != nil { return [node.name] }
            if let inner = node.children.firstInvalidPath { return [node.name] + inner }
        }
        return nil
    }
}

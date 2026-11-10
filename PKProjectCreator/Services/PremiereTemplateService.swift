import Foundation

nonisolated enum PremiereTemplateError: LocalizedError, Equatable, Sendable {
    case missing(String)
    case notAFile(String)
    case wrongExtension(String)
    case notReadable(String)
    case destinationFolderMissing(String)
    case outputExists(String)
    case copyFailed(String)
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missing(let name): "The master template “\(name)” can’t be found. Check that the WORK drive is connected, or choose the template again."
        case .notAFile(let name): "“\(name)” isn’t a file. Choose the .prproj master project itself."
        case .wrongExtension(let name): "“\(name)” isn’t a Premiere Pro project. Choose a file ending in .prproj."
        case .notReadable(let name): "PKProjectCreator isn’t allowed to read “\(name)”. Choose the template again to reauthorize it."
        case .destinationFolderMissing(let path): "The folder “\(path)” for the Premiere project doesn’t exist in the new project."
        case .outputExists(let name): "A file named “\(name)” is already there. Nothing was replaced."
        case .copyFailed(let reason): "The master template couldn’t be copied: \(reason)"
        case .verificationFailed(let name): "The copy “\(name)” doesn’t match the master template."
        }
    }
}

/// Copies the Premiere Pro master project. It only ever reads the master: no rename, move, delete or write.
/// Resolving the master's bookmark and holding its access is `FileAccessService`'s job; this service gets the
/// URL macOS granted.
nonisolated enum PremiereTemplateService {
    static let fileExtension = "prproj"

    /// The output name always comes from the project's generated name (`ProjectNameGenerator`).
    static func outputFilename(for generatedName: String) -> String {
        "\(generatedName).\(fileExtension)"
    }

    /// Checks that `source` is a readable regular `.prproj` file. Reads nothing but its attributes.
    static func validate(_ source: URL) throws {
        let name = source.lastPathComponent
        guard source.pathExtension.lowercased() == fileExtension else { throw PremiereTemplateError.wrongExtension(name) }
        let files = FileManager.default
        var isDirectory: ObjCBool = false
        guard files.fileExists(atPath: source.plainPath, isDirectory: &isDirectory) else { throw PremiereTemplateError.missing(name) }
        let isRegular = (try? source.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
        guard !isDirectory.boolValue, isRegular else { throw PremiereTemplateError.notAFile(name) }
        guard files.isReadableFile(atPath: source.plainPath) else { throw PremiereTemplateError.notReadable(name) }
    }

    /// Copies `source` into `folder` as `{generatedName}.prproj` in one step (copy and rename together, so the
    /// master's own name never appears in the project), then checks the copy byte for byte.
    @discardableResult
    static func copy(_ source: URL, into folder: URL, generatedName: String) throws -> URL {
        try validate(source)
        let files = FileManager.default
        var isDirectory: ObjCBool = false
        guard files.fileExists(atPath: folder.plainPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw PremiereTemplateError.destinationFolderMissing(folder.lastPathComponent)
        }
        let name = outputFilename(for: generatedName)
        let output = folder.appending(path: name, directoryHint: .notDirectory)
        guard !files.fileExists(atPath: output.plainPath) else { throw PremiereTemplateError.outputExists(name) }

        do {
            try files.copyItem(at: source, to: output)
        } catch {
            throw PremiereTemplateError.copyFailed(error.localizedDescription)
        }
        let sourceSize = (try? source.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        let outputSize = (try? output.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        guard sourceSize != nil, sourceSize == outputSize, files.contentsEqual(atPath: source.plainPath, andPath: output.plainPath) else {
            try? files.removeItem(at: output)
            throw PremiereTemplateError.verificationFailed(name)
        }
        return output
    }
}

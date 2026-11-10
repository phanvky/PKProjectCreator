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
    case resolveFileFailed(String)

    var errorDescription: String? {
        switch self {
        case .missing(let name): "The master template “\(name)” can’t be found. Check that the WORK drive is connected, or choose the template again."
        case .notAFile(let name): "“\(name)” isn’t a file. Choose the master project file itself."
        case .wrongExtension(let name): "“\(name)” isn’t the right kind of project file (.prproj for Premiere Pro, .drp for DaVinci Resolve)."
        case .notReadable(let name): "PKProjectCreator isn’t allowed to read “\(name)”. Choose the template again to reauthorize it."
        case .destinationFolderMissing(let path): "The folder “\(path)” for the project file doesn’t exist in the new project."
        case .outputExists(let name): "A file named “\(name)” is already there. Nothing was replaced."
        case .copyFailed(let reason): "The master template couldn’t be copied: \(reason)"
        case .verificationFailed(let name): "The copy “\(name)” doesn’t match the master template."
        case .resolveFileFailed(let reason): "The DaVinci Resolve file couldn’t be prepared: \(reason)"
        }
    }
}

/// Copies a master project file: the Premiere Pro `.prproj`, or the DaVinci Resolve `.drp` (pass `resolveExtension`). It only ever reads the master: no rename, move, delete or write.
/// Resolving the master's bookmark and holding its access is `FileAccessService`'s job; this service gets the
/// URL macOS granted.
nonisolated enum PremiereTemplateService {
    static let fileExtension = "prproj"
    static let resolveExtension = "drp"

    /// The output name always comes from the project's generated name (`ProjectNameGenerator`).
    static func outputFilename(for generatedName: String, fileExtension: String = Self.fileExtension) -> String {
        "\(generatedName).\(fileExtension)"
    }

    /// Checks that `source` is a readable regular file with `fileExtension`. Reads nothing but its attributes.
    static func validate(_ source: URL, fileExtension: String = Self.fileExtension) throws {
        let name = source.lastPathComponent
        guard source.pathExtension.lowercased() == fileExtension else { throw PremiereTemplateError.wrongExtension(name) }
        let files = FileManager.default
        var isDirectory: ObjCBool = false
        guard files.fileExists(atPath: source.plainPath, isDirectory: &isDirectory) else { throw PremiereTemplateError.missing(name) }
        let isRegular = (try? source.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
        guard !isDirectory.boolValue, isRegular else { throw PremiereTemplateError.notAFile(name) }
        guard files.isReadableFile(atPath: source.plainPath) else { throw PremiereTemplateError.notReadable(name) }
    }

    /// Copies `source` into `folder` as `{generatedName}.{fileExtension}` in one step (copy and rename together, so the
    /// master's own name never appears in the project), then checks the copy byte for byte.
    @discardableResult
    static func copy(_ source: URL, into folder: URL, generatedName: String, fileExtension: String = Self.fileExtension) throws -> URL {
        try validate(source, fileExtension: fileExtension)
        let files = FileManager.default
        var isDirectory: ObjCBool = false
        guard files.fileExists(atPath: folder.plainPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw PremiereTemplateError.destinationFolderMissing(folder.lastPathComponent)
        }
        let name = outputFilename(for: generatedName, fileExtension: fileExtension)
        let output = folder.appending(path: name, directoryHint: .notDirectory)
        guard !files.fileExists(atPath: output.plainPath) else { throw PremiereTemplateError.outputExists(name) }

        do {
            try files.copyItem(at: source, to: output)
        } catch {
            throw PremiereTemplateError.copyFailed(FileErrorText.describe(error))
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

/// A DaVinci Resolve `.drp` is a zip archive whose `project.xml` holds the name Resolve shows on import. Renaming the
/// file alone isn't enough, so the copy gets the generated name written into `<ProjectName>`. Only the copy inside
/// the new project is changed; the master is never opened for writing. The Working Folders are left as in the master.
nonisolated enum ResolveProjectFile {
    /// Replaces the single `<ProjectName>` in `drp` with `name`, keeping every other entry and their order.
    static func setProjectName(_ name: String, in drp: URL) throws {
        let files = FileManager.default
        // The zip tools run as child processes, so they only touch the app's own temporary folder.
        let work = files.temporaryDirectory.appending(path: "PKResolve-\(UUID().uuidString)", directoryHint: .isDirectory)
        let contents = work.appending(path: "contents", directoryHint: .isDirectory)
        let original = work.appending(path: "original.drp"), output = work.appending(path: "output.drp")
        defer { try? files.removeItem(at: work) }
        do {
            try files.createDirectory(at: contents, withIntermediateDirectories: true)
            try files.copyItem(at: drp, to: original)
            let entries = try run("/usr/bin/zipinfo", ["-1", original.plainPath]).split(separator: "\n").map(String.init)
            guard entries.contains("project.xml") else { throw PremiereTemplateError.resolveFileFailed("project.xml is missing.") }
            _ = try run("/usr/bin/unzip", ["-q", original.plainPath, "-d", contents.plainPath])

            let xmlURL = contents.appending(path: "project.xml")
            let xml = try String(contentsOf: xmlURL, encoding: .utf8)
            let pattern = /<ProjectName>[^<]*<\/ProjectName>/
            guard xml.matches(of: pattern).count == 1 else {
                throw PremiereTemplateError.resolveFileFailed("project.xml doesn’t have exactly one <ProjectName>.")
            }
            try xml.replacing(pattern, with: "<ProjectName>\(escaped(name))</ProjectName>").write(to: xmlURL, atomically: true, encoding: .utf8)

            // -X: no macOS extra attributes, -D: no folder entries (Resolve's own export has none).
            _ = try run("/usr/bin/zip", ["-q", "-X", "-D", output.plainPath] + entries, in: contents)
            _ = try run("/usr/bin/unzip", ["-tq", output.plainPath])
            guard try run("/usr/bin/zipinfo", ["-1", output.plainPath]).split(separator: "\n").map(String.init) == entries else {
                throw PremiereTemplateError.resolveFileFailed("the rewritten file is missing entries.")
            }
            // A plain copy back: `replaceItemAt` can't swap across volumes (the temporary folder is on the Mac's disk).
            // If it fails, project creation rolls back the whole staging folder, so no half-written file stays.
            try files.removeItem(at: drp)
            try files.copyItem(at: output, to: drp)
        } catch let error as PremiereTemplateError {
            throw error
        } catch {
            throw PremiereTemplateError.resolveFileFailed(FileErrorText.describe(error))
        }
    }

    static func escaped(_ text: String) -> String {
        text.replacing("&", with: "&amp;").replacing("<", with: "&lt;").replacing(">", with: "&gt;")
            .replacing("\"", with: "&quot;").replacing("'", with: "&apos;")
    }

    /// Runs a system tool and returns its output; a non-zero exit is an error.
    private static func run(_ tool: String, _ arguments: [String], in folder: URL? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        process.currentDirectoryURL = folder
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw PremiereTemplateError.resolveFileFailed("\((tool as NSString).lastPathComponent) failed: \(text.prefix(200))")
        }
        return text
    }
}

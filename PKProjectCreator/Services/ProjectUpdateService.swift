import Foundation

nonisolated enum ProjectUpdateError: LocalizedError, Equatable {
    /// Found before anything was written.
    case changedOnDisk(String)
    case template(PremiereTemplateError)
    /// Something failed part-way; `done` lists what was already changed.
    case stopped(reason: String, done: [String])

    var errorDescription: String? {
        switch self {
        case .changedOnDisk(let reason): "\(reason)\n\nNothing was changed. Close Update Project and open it again to see the folders as they are now."
        case .template(let error): "\(error.localizedDescription)\n\nNothing was changed."
        case .stopped(let reason, let done):
            done.isEmpty
                ? "The update stopped: \(reason)\n\nNothing was changed."
                : "The update stopped: \(reason)\n\nAlready done:\n" + done.map { "• \($0)" }.joined(separator: "\n")
                    + "\n\nNothing was deleted or overwritten."
        }
    }
}

/// Reads and changes the folders of a project that already exists. It never deletes a file, never deletes or renames
/// a folder that has anything inside, never moves a folder, and never overwrites a Premiere or Resolve file.
nonisolated struct ProjectUpdateService: Sendable {
    /// Folders deeper than this aren't shown; footage card structures can be very deep.
    static let scanDepth = 4

    /// Called just before each change. Tests use it to inject a failure.
    var willWrite: @Sendable (URL) throws -> Void = { _ in }

    // MARK: Scan

    @concurrent
    func scan(root: URL, premiereFolder: [String], resolveFolder: [String]) async throws -> ProjectScan {
        var folders: [FolderNode.ID: ScannedFolder] = [:]
        func read(_ url: URL, path: [String], depth: Int) throws -> [FolderNode] {
            try Self.subfolders(of: url).map { name in
                let child = url.appending(path: name, directoryHint: .isDirectory)
                let childPath = path + [name]
                let deeper = depth >= Self.scanDepth
                let children = deeper ? [] : try read(child, path: childPath, depth: depth + 1)
                let node = FolderNode(name, children: children)
                let hasDeeper = try deeper && !Self.subfolders(of: child).isEmpty
                folders[node.id] = ScannedFolder(path: childPath, itemCount: try Self.contents(of: child).count, hasDeeperFolders: hasDeeper)
                return node
            }
        }
        let nodes = try read(root, path: [], depth: 1)
        return ProjectScan(
            nodes: nodes, folders: folders,
            premiereFileExists: Self.hasFile(withExtension: PremiereTemplateService.fileExtension, in: Self.url(premiereFolder, in: root)),
            resolveFileExists: Self.hasFile(withExtension: PremiereTemplateService.resolveExtension, in: Self.url(resolveFolder, in: root))
        )
    }

    // MARK: Apply

    /// Checks the whole plan against the disk first, then applies it. Returns what was done, in plain words.
    @concurrent
    func apply(
        _ plan: ProjectUpdatePlan, in root: URL, generatedName: String,
        premiereTemplate: URL? = nil, resolveTemplate: URL? = nil
    ) async throws -> [String] {
        try check(plan, in: root, generatedName: generatedName, premiereTemplate: premiereTemplate, resolveTemplate: resolveTemplate)

        let files = FileManager.default
        var done: [String] = []
        func step(_ url: URL, _ description: String, _ body: () throws -> Void) throws {
            do {
                try Task.checkCancellation()
                try willWrite(url)
                try body()
                done.append(description)
            } catch {
                let reason = FileErrorText.describe(error)
                throw ProjectUpdateError.stopped(reason: "\(description): \(reason)", done: done)
            }
        }

        for rename in plan.renames {
            let source = Self.url(rename.from, in: root), target = Self.url(rename.to, in: root)
            try step(source, "Renamed “\(Self.text(rename.from))” to “\(rename.to.last ?? "")”") {
                // Checked again right before the change: something may have been put inside meanwhile.
                guard try Self.contents(of: source).isEmpty else { throw Self.reason("it isn’t empty any more") }
                guard !files.fileExists(atPath: target.plainPath) else { throw Self.reason("“\(Self.text(rename.to))” already exists") }
                try files.moveItem(at: source, to: target)
            }
        }
        for path in plan.creates {
            let folder = Self.url(path, in: root)
            try step(folder, "Added “\(Self.text(path))”") {
                try files.createDirectory(at: folder, withIntermediateDirectories: false)
            }
        }
        if let folder = plan.premiereFolder, let premiereTemplate {
            let target = Self.url(folder, in: root)
            try step(target, "Added the Premiere project in “\(Self.text(folder))”") {
                guard !Self.hasFile(withExtension: PremiereTemplateService.fileExtension, in: target) else { throw Self.reason("a Premiere project is already there") }
                try PremiereTemplateService.copy(premiereTemplate, into: target, generatedName: generatedName)
            }
        }
        if let folder = plan.resolveFolder, let resolveTemplate {
            let target = Self.url(folder, in: root)
            let ext = PremiereTemplateService.resolveExtension
            try step(target, "Added the DaVinci Resolve project in “\(Self.text(folder))”") {
                guard !Self.hasFile(withExtension: ext, in: target) else { throw Self.reason("a DaVinci Resolve project is already there") }
                let copy = try PremiereTemplateService.copy(resolveTemplate, into: target, generatedName: generatedName, fileExtension: ext)
                do {
                    try ResolveProjectFile.setProjectName(generatedName, in: copy)
                } catch {
                    try? files.removeItem(at: copy)
                    throw error
                }
            }
        }
        for path in plan.deletes {
            let folder = Self.url(path, in: root)
            try step(folder, "Deleted the empty folder “\(Self.text(path))”") {
                guard try Self.contents(of: folder).isEmpty else { throw Self.reason("it isn’t empty any more, so it was kept") }
                try files.removeEmptyFolder(at: folder)
            }
        }
        return done
    }

    private func check(_ plan: ProjectUpdatePlan, in root: URL, generatedName: String, premiereTemplate: URL?, resolveTemplate: URL?) throws {
        let files = FileManager.default
        func exists(_ path: [String]) -> Bool { files.fileExists(atPath: Self.url(path, in: root).plainPath) }
        func isEmpty(_ path: [String]) -> Bool { (try? Self.contents(of: Self.url(path, in: root)).isEmpty) == true }

        guard files.fileExists(atPath: root.plainPath) else { throw ProjectUpdateError.changedOnDisk("The project folder can’t be found.") }
        for rename in plan.renames {
            guard exists(rename.from), isEmpty(rename.from) else {
                throw ProjectUpdateError.changedOnDisk("“\(Self.text(rename.from))” is gone or isn’t empty any more.")
            }
            guard !exists(rename.to) else { throw ProjectUpdateError.changedOnDisk("“\(Self.text(rename.to))” already exists.") }
        }
        var willExist = Set(plan.renames.map(\.to))
        for path in plan.creates {
            guard !exists(path) else { throw ProjectUpdateError.changedOnDisk("“\(Self.text(path))” already exists.") }
            let parent = Array(path.dropLast())
            guard parent.isEmpty || exists(parent) || willExist.contains(parent) else {
                throw ProjectUpdateError.changedOnDisk("The folder for “\(Self.text(path))” is missing.")
            }
            willExist.insert(path)
        }
        for path in plan.deletes {
            guard exists(path), isEmpty(path) else {
                throw ProjectUpdateError.changedOnDisk("“\(Self.text(path))” is gone or isn’t empty any more, so it won’t be deleted.")
            }
        }
        let fileTargets: [([String]?, URL?, String)] = [
            (plan.premiereFolder, premiereTemplate, PremiereTemplateService.fileExtension),
            (plan.resolveFolder, resolveTemplate, PremiereTemplateService.resolveExtension),
        ]
        for case let (folder?, template, ext) in fileTargets {
            guard let template else { throw ProjectUpdateError.template(.missing("the .\(ext) master template")) }
            do {
                try PremiereTemplateService.validate(template, fileExtension: ext)
            } catch let error as PremiereTemplateError {
                throw ProjectUpdateError.template(error)
            }
            guard exists(folder) || willExist.contains(folder) else {
                throw ProjectUpdateError.changedOnDisk("The folder “\(Self.text(folder))” for the .\(ext) file is missing.")
            }
            guard !Self.hasFile(withExtension: ext, in: Self.url(folder, in: root)) else {
                throw ProjectUpdateError.changedOnDisk("A .\(ext) project is already in “\(Self.text(folder))”.")
            }
        }
    }

    // MARK: Disk helpers

    /// Finder metadata that doesn't make a folder "not empty".
    static func isMetadata(_ name: String) -> Bool { name == ".DS_Store" || name.hasPrefix("._") }

    /// Everything in `folder` that counts as content.
    static func contents(of folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.plainPath).filter { !isMetadata($0) }
    }

    /// Visible subfolders (not hidden, not packages), sorted like Finder.
    static func subfolders(of folder: URL) throws -> [String] {
        try contents(of: folder).filter { name in
            guard !name.hasPrefix(".") else { return false }
            let values = try? folder.appending(path: name).resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return values?.isDirectory == true && values?.isPackage != true
        }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func hasFile(withExtension ext: String, in folder: URL) -> Bool {
        ((try? contents(of: folder)) ?? []).contains { ($0 as NSString).pathExtension.lowercased() == ext }
    }

    static func url(_ path: [String], in root: URL) -> URL {
        path.reduce(root) { $0.appending(path: $1, directoryHint: .isDirectory) }
    }

    static func text(_ path: [String]) -> String { path.joined(separator: "/") }

    private static func reason(_ text: String) -> NSError {
        NSError(domain: "PKProjectCreator", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}

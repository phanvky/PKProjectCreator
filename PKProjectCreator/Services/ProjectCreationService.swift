import Foundation

nonisolated enum ProjectCreationError: LocalizedError, Equatable {
    case invalidName(ProjectNameIssue)
    case templateNotConfigured(String)
    case invalidFolderName(String)
    case premiereTemplateUnavailable
    case premiereFolderMissing(String)
    case premiere(PremiereTemplateError)
    case resolveTemplateUnavailable
    case resolveFolderMissing(String)
    case resolve(PremiereTemplateError)
    case destinationUnavailable(String)
    case destinationNotWritable(String)
    case alreadyExists(String)
    case cancelled
    case failed(String)
    case cleanupFailed(reason: String, leftover: String)

    var errorDescription: String? {
        switch self {
        case .invalidName(let issue): issue.message
        case .templateNotConfigured(let name): "“\(name)” has no folders yet. Add its folders in Folder Templates."
        case .invalidFolderName(let path): "The folder template has an invalid folder name at “\(path)”. Fix it in Folder Templates. Nothing was created."
        case .premiereTemplateUnavailable: "The Premiere master template isn’t available. Choose it on Premiere Template, or turn off “Create Premiere project from template” to create the folders only. Nothing was created."
        case .premiereFolderMissing(let path): "The folder template has no “\(path)” folder for the Premiere project. Choose another folder in Premiere Template › Copy Into. Nothing was created."
        case .premiere(let error): "The Premiere project couldn’t be created. \(error.localizedDescription)\n\nNothing was created, and the master template was not changed."
        case .resolveTemplateUnavailable: "The DaVinci Resolve master template isn’t available. Choose it on Resolve Template, or turn off “Create DaVinci Resolve project from template”. Nothing was created."
        case .resolveFolderMissing(let path): "The folder template has no “\(path)” folder for the DaVinci Resolve project. Choose another folder in Resolve Template › Copy Into, or turn off “Create DaVinci Resolve project from template”. Nothing was created."
        case .resolve(let error): "The DaVinci Resolve project couldn’t be created. \(error.localizedDescription)\n\nNothing was created, and the master template was not changed."
        case .destinationUnavailable(let path): "The destination folder can’t be reached:\n\(path)\n\nNothing was created."
        case .destinationNotWritable(let path): "PKProjectCreator isn’t allowed to create folders in:\n\(path)\n\nChoose the destination again to reauthorize it. Nothing was created."
        case .alreadyExists(let name): "A project named “\(name)” already exists in the destination. It was not changed. Use a different name or date."
        case .cancelled: "Project creation was cancelled. Nothing was created."
        case .failed(let reason): "The project couldn’t be created: \(reason)\n\nNothing was left behind, and the master template was not changed."
        case .cleanupFailed(let reason, let leftover): "The project couldn’t be created: \(reason)\n\nA temporary folder couldn’t be removed. You can delete it yourself:\n\(leftover)"
        }
    }
}

/// Creates a project folder, and the Premiere and DaVinci Resolve projects inside it, from a plan. The folder tree is built in a hidden staging folder next to the final
/// location (same volume) and renamed into place only when everything succeeded, so a failure never leaves a
/// half-made project and an existing project is never overwritten or merged into.
nonisolated struct ProjectCreationService: Sendable {
    static let stagingPrefix = ".PKProjectCreator-Staging-"

    /// Called just before each folder is created and before the Premiere copy. Tests use it to inject a
    /// failure or a cancellation.
    var willWrite: @Sendable (URL) throws -> Void = { _ in }

    /// `destination` and `premiereTemplate` must be the URLs macOS granted access to (see
    /// `FileAccessService.withAccess`), not paths rebuilt from text. Runs off the main actor.
    @concurrent
    func create(_ plan: ProjectCreationPlan, in destination: URL, premiereTemplate: URL? = nil, resolveTemplate: URL? = nil) async throws -> RecentProject {
        let files = FileManager.default

        if let issue = ProjectNameGenerator.issue(forProjectName: plan.projectName, generatedName: plan.generatedName) {
            throw ProjectCreationError.invalidName(issue)
        }
        guard !plan.folders.isEmpty, let templateID = plan.templateID else { throw ProjectCreationError.templateNotConfigured(plan.templateName) }
        if let invalid = plan.folders.firstInvalidPath { throw ProjectCreationError.invalidFolderName(invalid.joined(separator: "/")) }
        // A plan that wants a Premiere project gets one or nothing: never a silent folders-only project.
        if let premiereFolder = plan.premiereFolder {
            guard plan.folders.allPaths.contains(premiereFolder) else {
                throw ProjectCreationError.premiereFolderMissing(premiereFolder.joined(separator: "/"))
            }
            guard let premiereTemplate else { throw ProjectCreationError.premiereTemplateUnavailable }
            do {
                try PremiereTemplateService.validate(premiereTemplate)
            } catch let error as PremiereTemplateError {
                throw ProjectCreationError.premiere(error)
            }
        }
        if let resolveFolder = plan.resolveFolder {
            guard plan.folders.allPaths.contains(resolveFolder) else {
                throw ProjectCreationError.resolveFolderMissing(resolveFolder.joined(separator: "/"))
            }
            guard let resolveTemplate else { throw ProjectCreationError.resolveTemplateUnavailable }
            do {
                try PremiereTemplateService.validate(resolveTemplate, fileExtension: PremiereTemplateService.resolveExtension)
            } catch let error as PremiereTemplateError {
                throw ProjectCreationError.resolve(error)
            }
        }

        var isDirectory: ObjCBool = false
        guard files.fileExists(atPath: destination.plainPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ProjectCreationError.destinationUnavailable(destination.plainPath)
        }
        guard files.isWritableFile(atPath: destination.plainPath) else {
            throw ProjectCreationError.destinationNotWritable(destination.plainPath)
        }
        let parent = plan.parentFolder(in: destination)
        let project = plan.projectFolder(in: destination)
        guard !files.fileExists(atPath: project.plainPath) else { throw ProjectCreationError.alreadyExists(plan.generatedName) }

        let createsParent = !files.fileExists(atPath: parent.plainPath)
        let staging = parent.appending(path: Self.stagingPrefix + UUID().uuidString, directoryHint: .isDirectory)
        do {
            if createsParent { try files.createDirectory(at: parent, withIntermediateDirectories: false) }
            try files.createDirectory(at: staging, withIntermediateDirectories: false)
            // Depth-first, so a parent always exists before its children.
            for path in plan.folders.allPaths {
                try Task.checkCancellation()
                let folder = path.reduce(staging) { $0.appending(path: $1, directoryHint: .isDirectory) }
                try willWrite(folder)
                try files.createDirectory(at: folder, withIntermediateDirectories: false)
            }
            if let premiereFolder = plan.premiereFolder, let premiereTemplate {
                try Task.checkCancellation()
                let folder = premiereFolder.reduce(staging) { $0.appending(path: $1, directoryHint: .isDirectory) }
                try willWrite(folder.appending(path: PremiereTemplateService.outputFilename(for: plan.generatedName)))
                try PremiereTemplateService.copy(premiereTemplate, into: folder, generatedName: plan.generatedName)
            }
            if let resolveFolder = plan.resolveFolder, let resolveTemplate {
                try Task.checkCancellation()
                let folder = resolveFolder.reduce(staging) { $0.appending(path: $1, directoryHint: .isDirectory) }
                let ext = PremiereTemplateService.resolveExtension
                try willWrite(folder.appending(path: PremiereTemplateService.outputFilename(for: plan.generatedName, fileExtension: ext)))
                do {
                    let copy = try PremiereTemplateService.copy(resolveTemplate, into: folder, generatedName: plan.generatedName, fileExtension: ext)
                    try ResolveProjectFile.setProjectName(plan.generatedName, in: copy)
                } catch let error as PremiereTemplateError {
                    throw ProjectCreationError.resolve(error)
                }
            }
            try Task.checkCancellation()
            // A rename within one folder: it fails rather than replace anything that appeared meanwhile.
            try files.moveItem(at: staging, to: project)
        } catch {
            let reason: ProjectCreationError = switch error {
            case is CancellationError: .cancelled
            case let known as ProjectCreationError: known
            case let premiere as PremiereTemplateError: .premiere(premiere)
            default: files.fileExists(atPath: project.plainPath) ? .alreadyExists(plan.generatedName) : .failed(FileErrorText.describe(error))
            }
            // Roll back only what this run made: the staging folder, and the year folder if it is still empty.
            if files.fileExists(atPath: staging.plainPath) {
                do {
                    try files.removeItem(at: staging)
                } catch {
                    throw ProjectCreationError.cleanupFailed(reason: reason.localizedDescription, leftover: staging.plainPath)
                }
            }
            if createsParent { try? files.removeEmptyFolder(at: parent) }
            throw reason
        }

        return RecentProject(
            projectName: plan.projectName, projectType: plan.type, projectDate: plan.date,
            folderTemplateID: templateID, folderTemplateName: plan.templateName, directoryCount: plan.directoryCount,
            destinationPath: parent.plainPath, premiereProjectRelativePath: plan.premiereOutputRelativePath,
            resolveProjectRelativePath: plan.resolveOutputRelativePath
        )
    }
}

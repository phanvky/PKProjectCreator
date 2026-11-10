import Foundation

nonisolated enum ProjectCreationError: LocalizedError, Equatable {
    case invalidName(ProjectNameIssue)
    case templateNotConfigured(String)
    case premiereNotAvailable
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
        case .premiereNotAvailable: "Creating the Premiere project isn’t available yet. Turn off “Create Premiere project from template” to create the folders only."
        case .destinationUnavailable(let path): "The destination folder can’t be reached:\n\(path)\n\nNothing was created."
        case .destinationNotWritable(let path): "PKProjectCreator isn’t allowed to create folders in:\n\(path)\n\nChoose the destination again to reauthorize it. Nothing was created."
        case .alreadyExists(let name): "A project named “\(name)” already exists in the destination. It was not changed. Use a different name or date."
        case .cancelled: "Project creation was cancelled. Nothing was created."
        case .failed(let reason): "The project couldn’t be created: \(reason)\n\nNothing was left behind."
        case .cleanupFailed(let reason, let leftover): "The project couldn’t be created: \(reason)\n\nA temporary folder couldn’t be removed. You can delete it yourself:\n\(leftover)"
        }
    }
}

/// Creates a project folder from a plan. The folder tree is built in a hidden staging folder next to the final
/// location (same volume) and renamed into place only when everything succeeded, so a failure never leaves a
/// half-made project and an existing project is never overwritten or merged into.
nonisolated struct ProjectCreationService: Sendable {
    static let stagingPrefix = ".PKProjectCreator-Staging-"

    /// Called just before each folder is created. Tests use it to inject a failure or a cancellation.
    var willCreateFolder: @Sendable (URL) throws -> Void = { _ in }

    /// `destination` must be the URL macOS granted access to (see `FileAccessService.withAccess`), not a path
    /// rebuilt from text. Runs off the main actor.
    @concurrent
    func create(_ plan: ProjectCreationPlan, in destination: URL) async throws -> RecentProject {
        let files = FileManager.default

        if let issue = ProjectNameGenerator.issue(forProjectName: plan.projectName, generatedName: plan.generatedName) {
            throw ProjectCreationError.invalidName(issue)
        }
        guard !plan.folders.isEmpty else { throw ProjectCreationError.templateNotConfigured(plan.templateName) }
        // Phase gate: copying the Premiere template arrives in Phase 05. Never pretend it was created.
        guard !plan.createsPremiereProject else { throw ProjectCreationError.premiereNotAvailable }

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
                try willCreateFolder(folder)
                try files.createDirectory(at: folder, withIntermediateDirectories: false)
            }
            try Task.checkCancellation()
            // A rename within one folder: it fails rather than replace anything that appeared meanwhile.
            try files.moveItem(at: staging, to: project)
        } catch {
            let reason: ProjectCreationError = switch error {
            case is CancellationError: .cancelled
            case let known as ProjectCreationError: known
            default: files.fileExists(atPath: project.plainPath) ? .alreadyExists(plan.generatedName) : .failed(error.localizedDescription)
            }
            // Roll back only what this run made: the staging folder, and the year folder if it is still empty.
            if files.fileExists(atPath: staging.plainPath) {
                do {
                    try files.removeItem(at: staging)
                } catch {
                    throw ProjectCreationError.cleanupFailed(reason: reason.localizedDescription, leftover: staging.plainPath)
                }
            }
            if createsParent, (try? files.contentsOfDirectory(atPath: parent.plainPath))?.isEmpty == true {
                try? files.removeItem(at: parent)
            }
            throw reason
        }

        return RecentProject(
            date: plan.date, type: plan.type, projectName: plan.projectName, templateName: plan.templateName,
            directoryCount: plan.directoryCount, premiere: .foldersOnly, parentFolder: parent.plainPath
        )
    }
}

import Foundation

/// Everything one project creation will do, fixed at one moment. The preview shows this plan and
/// `ProjectCreationService` executes this same plan, so the two can't disagree.
nonisolated struct ProjectCreationPlan: Equatable, Sendable {
    let generatedName: String
    let date: Date
    let type: ProjectType
    let projectName: String
    let templateID: FolderTemplate.ID?
    let templateName: String
    /// The folder the user authorized (Phase 03), e.g. `…/PROJECT VIDEO/EVENT`.
    let destinationFolderURL: URL
    /// The year of the project date, e.g. "2026"; nil when year-folder mode is off.
    let yearFolderName: String?
    /// The folders to create inside the project root, exactly as the selected template has them.
    let folders: [FolderNode]
    let createsPremiereProject: Bool
    /// e.g. `04_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj`; nil when Premiere is off.
    let premiereOutputRelativePath: String?

    init(
        date: Date, type: ProjectType, projectName: String,
        templateID: FolderTemplate.ID?, templateName: String, folders: [FolderNode],
        destinationFolderURL: URL, useYearFolder: Bool,
        createsPremiereProject: Bool, premiereFolder: [String]
    ) {
        let name = ProjectNameGenerator.generatedName(date: date, type: type, projectName: projectName)
        generatedName = name
        self.date = date
        self.type = type
        self.projectName = projectName
        self.templateID = templateID
        self.templateName = templateName
        self.folders = folders
        self.destinationFolderURL = destinationFolderURL
        yearFolderName = useYearFolder ? ProjectNameGenerator.year(for: date) : nil
        self.createsPremiereProject = createsPremiereProject
        premiereOutputRelativePath = createsPremiereProject ? (premiereFolder + ["\(name).prproj"]).joined(separator: "/") : nil
    }

    /// The folder that will contain the project: the destination, or its year folder.
    var yearFolderURL: URL { parentFolder(in: destinationFolderURL) }
    var projectURL: URL { projectFolder(in: destinationFolderURL) }
    /// Directories including the project root.
    var directoryCount: Int { folders.totalCount + 1 }

    /// The same locations relative to the destination URL that macOS actually granted access to.
    func parentFolder(in destination: URL) -> URL {
        yearFolderName.map { destination.appending(path: $0, directoryHint: .isDirectory) } ?? destination
    }

    func projectFolder(in destination: URL) -> URL {
        parentFolder(in: destination).appending(path: generatedName, directoryHint: .isDirectory)
    }
}

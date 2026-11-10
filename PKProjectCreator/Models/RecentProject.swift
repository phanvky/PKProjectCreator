import Foundation

/// A project this app created. Saved in `recent-projects.json`; records only ever come from a successful
/// creation, never from scanning a drive.
nonisolated struct RecentProject: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var projectName: String
    var projectType: ProjectType
    var projectDate: Date
    var folderTemplateID: UUID
    /// For display, in case the template is renamed or deleted later.
    var folderTemplateName: String
    /// Directories including the project root.
    var directoryCount: Int
    /// The folder that contains the project folder, for display and recovery.
    var destinationPath: String
    /// Permission to reach the project folder later; nil if macOS couldn't make one.
    var projectRootBookmark: Data?
    var volume: VolumeIdentity?
    /// e.g. `04_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj`.
    var premiereProjectRelativePath: String?
    var createdAt = Date()

    var hasPremiereProject: Bool { premiereProjectRelativePath != nil }

    var name: String {
        ProjectNameGenerator.generatedName(date: projectDate, type: projectType, projectName: projectName)
    }

    var rootURL: URL { URL(filePath: destinationPath, directoryHint: .isDirectory).appending(path: name, directoryHint: .isDirectory) }
    var fullPath: String { rootURL.plainPath + "/" }

    var premiereFilename: String? {
        premiereProjectRelativePath.map { ($0 as NSString).lastPathComponent }
    }

    /// Short location for the table, e.g. "KIOXIA › PROJECT VIDEO › EVENT › 2026".
    var locationSummary: String {
        destinationPath.split(separator: "/").filter { $0 != "Volumes" }.joined(separator: " › ")
    }

    /// Search by project name, optionally limited to one type. The order is kept.
    static func matching(_ projects: [RecentProject], search: String, type: ProjectType?) -> [RecentProject] {
        let search = search.trimmingCharacters(in: .whitespaces)
        return projects.filter { project in
            (type == nil || project.projectType == type) && (search.isEmpty || project.name.localizedStandardContains(search))
        }
    }

    // Stored as `hasPremiereProject` too, so the file reads on its own.
    private enum CodingKeys: String, CodingKey {
        case id, projectName, projectType, projectDate, folderTemplateID, folderTemplateName, directoryCount
        case destinationPath, projectRootBookmark, volume, premiereProjectRelativePath, createdAt, hasPremiereProject
    }

    init(
        id: UUID = UUID(), projectName: String, projectType: ProjectType, projectDate: Date,
        folderTemplateID: UUID, folderTemplateName: String, directoryCount: Int, destinationPath: String,
        projectRootBookmark: Data? = nil, volume: VolumeIdentity? = nil,
        premiereProjectRelativePath: String? = nil, createdAt: Date = Date()
    ) {
        self.id = id
        self.projectName = projectName
        self.projectType = projectType
        self.projectDate = projectDate
        self.folderTemplateID = folderTemplateID
        self.folderTemplateName = folderTemplateName
        self.directoryCount = directoryCount
        self.destinationPath = destinationPath
        self.projectRootBookmark = projectRootBookmark
        self.volume = volume
        self.premiereProjectRelativePath = premiereProjectRelativePath
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        projectName = try values.decode(String.self, forKey: .projectName)
        projectType = try values.decode(ProjectType.self, forKey: .projectType)
        projectDate = try values.decode(Date.self, forKey: .projectDate)
        folderTemplateID = try values.decode(UUID.self, forKey: .folderTemplateID)
        folderTemplateName = try values.decodeIfPresent(String.self, forKey: .folderTemplateName) ?? ""
        directoryCount = try values.decodeIfPresent(Int.self, forKey: .directoryCount) ?? 0
        destinationPath = try values.decode(String.self, forKey: .destinationPath)
        projectRootBookmark = try values.decodeIfPresent(Data.self, forKey: .projectRootBookmark)
        volume = try values.decodeIfPresent(VolumeIdentity.self, forKey: .volume)
        premiereProjectRelativePath = try values.decodeIfPresent(String.self, forKey: .premiereProjectRelativePath)
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? projectDate
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(projectName, forKey: .projectName)
        try values.encode(projectType, forKey: .projectType)
        try values.encode(projectDate, forKey: .projectDate)
        try values.encode(folderTemplateID, forKey: .folderTemplateID)
        try values.encode(folderTemplateName, forKey: .folderTemplateName)
        try values.encode(directoryCount, forKey: .directoryCount)
        try values.encode(destinationPath, forKey: .destinationPath)
        try values.encodeIfPresent(projectRootBookmark, forKey: .projectRootBookmark)
        try values.encodeIfPresent(volume, forKey: .volume)
        try values.encodeIfPresent(premiereProjectRelativePath, forKey: .premiereProjectRelativePath)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(hasPremiereProject, forKey: .hasPremiereProject)
    }
}

/// Where a recent project stands right now. Worked out on launch, on drive changes and on Retry; never saved.
struct RecentProjectStatus: Equatable {
    enum Location: Equatable {
        case notChecked, available, volumeDisconnected, missing, permissionNeeded
    }

    var location = Location.notChecked
    var volumeName = ""
    /// Where the folder really is (it may have been renamed or moved since); nil when it can't be reached.
    var url: URL?
    /// nil when the project has no Premiere file or can't be reached.
    var premiereFileExists: Bool?

    var isAvailable: Bool { location == .available }

    var label: String {
        switch location {
        case .notChecked: "Not checked"
        case .available: "Available"
        case .volumeDisconnected: "\(volumeName) disconnected"
        case .missing: "Missing"
        case .permissionNeeded: "Permission needed"
        }
    }

    var kind: StatusKind {
        switch location {
        case .notChecked: .neutral
        case .available: .success
        case .volumeDisconnected, .permissionNeeded: .warning
        case .missing: .danger
        }
    }

    /// What happened and what to do; nil when the project is available.
    var problem: String? {
        switch location {
        case .notChecked, .available: nil
        case .volumeDisconnected: "“\(volumeName)” is disconnected, so this project can’t be reached right now. Connect the drive and click Retry. The project is not deleted."
        case .missing: "The project folder isn’t where it was created. It may have been moved, renamed or deleted outside PKProjectCreator. Nothing will be recreated; you can remove this entry from the list."
        case .permissionNeeded: "PKProjectCreator no longer has permission to open this folder. You can still reach it in Finder using the path below."
        }
    }

    func premiereLabel(for project: RecentProject) -> (text: String, kind: StatusKind) {
        guard project.hasPremiereProject else { return ("Folders only", .neutral) }
        switch premiereFileExists {
        case true?: return ("Linked", .success)
        case false?: return ("Missing", .warning)
        case nil: return ("Unavailable", .neutral)
        }
    }
}

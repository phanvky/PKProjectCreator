import Foundation

nonisolated struct RecentProject: Identifiable, Hashable {
    enum PremiereLink: String {
        case linked = "Linked"
        case missing = "Missing"
    }

    let id = UUID()
    var date: Date
    var type: ProjectType
    var projectName: String
    var templateName: String
    /// Directories including the project root.
    var directoryCount: Int
    var premiere: PremiereLink
    /// Folder that contains the project folder.
    var parentFolder: String

    var name: String {
        ProjectNaming.generatedName(date: date, type: type, projectName: projectName)
    }

    var fullPath: String { "\(parentFolder)/\(name)/" }

    var premiereFilename: String { "\(name).prproj" }

    /// Short location for the table, e.g. "KIOXIA › PROJECT VIDEO › EVENT › 2026".
    var locationSummary: String {
        parentFolder.split(separator: "/").filter { $0 != "Volumes" }.joined(separator: " › ")
    }
}

extension RecentProject {
    /// SAMPLE DATA for the Phase 01 design only. These are not real projects and nothing on disk is read.
    static let samples: [RecentProject] = [
        sample(2026, 11, 3, .event, "Develon"),
        sample(2026, 10, 28, .tvc, "Lotus Tea Launch"),
        sample(2026, 10, 21, .golfTournament, "Spring Cup"),
        sample(2026, 10, 15, .reels, "Studio BTS", template: "Reels — Lite", directories: 9),
        sample(2026, 10, 9, .psc, "Annual Gala"),
        sample(2026, 9, 30, .tour, "Da Lat Retreat", premiere: .missing),
        sample(2026, 9, 18, .psh, "Product Launch"),
        sample(2025, 12, 20, .event, "Year End Party"),
    ]

    private static func sample(
        _ year: Int, _ month: Int, _ day: Int, _ type: ProjectType, _ name: String,
        template: String = "Standard Production", directories: Int = 19, premiere: PremiereLink = .linked
    ) -> RecentProject {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        let date = Calendar(identifier: .gregorian).date(from: components) ?? .now
        return RecentProject(
            date: date, type: type, projectName: name, templateName: template,
            directoryCount: directories, premiere: premiere,
            parentFolder: "/Volumes/KIOXIA/PROJECT VIDEO/EVENT/\(year)"
        )
    }
}

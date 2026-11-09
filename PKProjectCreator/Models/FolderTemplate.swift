import Foundation

struct FolderTemplate: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var summary: String
    var folders: [FolderNode]
    var defaultTypes: Set<ProjectType>
    /// shortcut: Reels — Lite's hierarchy isn't approved yet, so only its folder count is known; drop once real folders exist.
    var specifiedFolderCount: Int? = nil

    /// Folders below the project root.
    var folderCount: Int {
        folders.isEmpty ? (specifiedFolderCount ?? 0) : folders.totalCount
    }

    var isStructureSpecified: Bool {
        specifiedFolderCount == nil || !folders.isEmpty
    }

    /// Default types in the app's standard order, for display.
    var defaultTypesList: [ProjectType] {
        ProjectType.allCases.filter(defaultTypes.contains)
    }
}

extension FolderTemplate {
    static func builtIn() -> [FolderTemplate] {
        [standardProduction(), reelsLite()]
    }

    /// The approved PHANKY FILM structure: 18 folders, 19 with the project root.
    static func standardProduction() -> FolderTemplate {
        FolderTemplate(
            name: "Standard Production",
            summary: "Multi-camera events, tournaments and commercials.",
            folders: [
                FolderNode("01_Footages", children: ["Cam 01", "Cam 02", "Flycam", "FPV", "Cam 360", "Action Cam"].map { FolderNode($0) }),
                FolderNode("02_Music"),
                FolderNode("03_SFX"),
                FolderNode("04_Project", children: ["Premiere Pro", "DaVinci Resolve", "After Effects"].map { FolderNode($0) }),
                FolderNode("05_AI", children: [FolderNode("Images"), FolderNode("Video")]),
                FolderNode("06_Graphic"),
                FolderNode("07_Export"),
            ],
            defaultTypes: [.event, .psc, .psh, .tour, .golfTournament, .tvc]
        )
    }

    /// 9 folders including the root. The hierarchy itself is intentionally left empty until it is specified.
    static func reelsLite() -> FolderTemplate {
        FolderTemplate(
            name: "Reels — Lite",
            summary: "Short-form social content.",
            folders: [],
            defaultTypes: [.reels],
            specifiedFolderCount: 8
        )
    }
}

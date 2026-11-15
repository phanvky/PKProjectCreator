import Foundation
import Testing
@testable import PKProjectCreator

/// Per-project folder edits, Copy Into following renamed folders, and the user's own project types.
@MainActor
struct ProjectCustomizationTests {
    private func id(_ nodes: [FolderNode], _ path: [String]) throws -> UUID {
        try #require(nodes.node(atPath: path)?.id)
    }

    // MARK: Folders for one project

    @Test func projectFolderEditsLeaveTheTemplateAlone() throws {
        let app = AppState(directory: nil)
        let template = try #require(app.selectedTemplate)
        let music = try id(app.projectFolders, ["03_Music"])

        try app.editProjectFolders { try $0.renameFolder(music, to: "03_Audio") }
        try app.editProjectFolders { $0.addFolder(inParent: nil) }

        #expect(app.creationPlan.folders.allPaths.contains(["03_Audio"]))
        #expect(app.creationPlan.directoryCount == template.folderCount + 2)
        #expect(app.selectedTemplate?.nodes == template.nodes)

        // A refused edit changes nothing.
        let before = app.projectFolders
        #expect(throws: FolderEditIssue.duplicateName) { try app.editProjectFolders { try $0.renameFolder(music, to: "04_SFX") } }
        #expect(app.projectFolders == before)

        // Choosing another template starts again from that template.
        app.draft.projectName = "Develon"
        let other = app.addTemplate()
        app.draft.templateID = other
        #expect(app.draft.folders == nil)
        #expect(app.creationBlocker?.text.contains("needs configuration") == true)
    }

    @Test func emptyProjectFoldersBlockCreation() throws {
        let app = AppState(directory: nil)
        app.draft.projectName = "Develon"
        try app.editProjectFolders { $0 = [] }
        #expect(app.creationBlocker?.text.contains("at least one folder") == true)
    }

    // MARK: Copy Into follows the folder

    @Test func renumberedProjectFolderStillGetsTheProjectFiles() throws {
        let app = AppState(directory: nil)
        app.premiere = PremiereTemplateConfig()
        app.draft.createPremiere = true
        app.draft.createResolve = true
        let project = try id(app.projectFolders, ["07_Project"])

        try app.editProjectFolders { try $0.renameFolder(project, to: "05_Project") }

        #expect(app.creationPlan.premiereFolder == ["05_Project", "Premiere Pro"])
        #expect(app.creationPlan.resolveFolder == ["05_Project", "DaVinci Resolve"])
        #expect(app.premiereOutputPath.hasPrefix("05_Project/Premiere Pro/"))
    }

    @Test func renamedCopyFolderIsFollowedByID() throws {
        let app = AppState(directory: nil)
        app.premiere = PremiereTemplateConfig()
        app.draft.createPremiere = true
        let premiere = try id(app.projectFolders, ["07_Project", "Premiere Pro"])

        try app.editProjectFolders { try $0.renameFolder(premiere, to: "PR") }
        #expect(app.creationPlan.premiereFolder == ["07_Project", "PR"])

        try app.editProjectFolders { $0.remove(premiere) }
        #expect(app.copyFolder(app.premiere.destinationFolder) == nil)
    }

    @Test func savedCopyFolderMatchesARenumberedTemplate() throws {
        // The user's case: the template was renumbered to 05_Project, Copy Into still says 07_Project.
        var nodes = FolderTemplate.standardProduction().nodes
        try nodes.renameFolder(try id(nodes, ["07_Project"]), to: "05_Project")
        #expect(nodes.matchingPath(["07_Project", "DaVinci Resolve"]) == ["05_Project", "DaVinci Resolve"])
        #expect(nodes.matchingPath(["07_Project", "Nothing"]) == nil)
        #expect(FolderNaming.withoutNumber("05_Project") == "project")
        #expect(FolderNaming.withoutNumber("Cam 01") == "cam 01")
    }

    @Test func templateEditsMoveCopyInto() throws {
        let app = AppState(directory: nil)
        app.premiere = PremiereTemplateConfig()
        let template = try #require(app.selectedTemplate)
        let premiere = try id(template.nodes, ["07_Project", "Premiere Pro"])
        let project = try id(template.nodes, ["07_Project"])

        try app.updateTemplate(template.id) { try $0.renameFolder(project, to: "05_Project") }
        try app.updateTemplate(template.id) { try $0.renameFolder(premiere, to: "Premiere") }

        #expect(app.premiere.destinationFolder == ["05_Project", "Premiere"])
        #expect(app.premiere.resolveFolder == ["05_Project", "DaVinci Resolve"])
    }

    @Test func copyIntoIsSaved() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PKCustom-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppState(directory: directory)
        app.premiere.resolveFolder = ["05_Project", "DaVinci Resolve"]
        #expect(AppState(directory: directory).premiere.resolveFolder == ["05_Project", "DaVinci Resolve"])
    }

    // MARK: Project types

    @Test func projectTypesCanBeAddedRenamedAndRemoved() throws {
        let app = AppState(directory: nil)
        let standard = try #require(app.templates.first)
        app.settings.defaultProjectType = .psc
        app.draft.type = .psc

        app.renameProjectType(.psc, to: "Pre-wedding")
        let renamed = ProjectType("Pre-wedding")
        #expect(app.settings.projectTypes[1] == renamed)
        #expect(app.settings.defaultProjectType == renamed)
        #expect(app.draft.type == renamed)
        #expect(app.templates.first?.defaultProjectTypes.contains(renamed) == true)
        #expect(app.generatedName.contains("Pre-wedding"))

        #expect(app.projectTypeNameIssue("event", for: renamed) != nil)
        #expect(app.projectTypeNameIssue("A/B", for: nil) != nil)
        app.renameProjectType(renamed, to: "Event")
        #expect(app.settings.projectTypes[1] == renamed)

        let added = app.addProjectType()
        #expect(added.rawValue == "New Type")
        app.moveProjectType(added, by: -1)
        #expect(app.settings.projectTypes.firstIndex(of: added) == app.settings.projectTypes.count - 2)

        app.removeProjectType(renamed)
        #expect(!app.settings.projectTypes.contains(renamed))
        #expect(app.settings.defaultProjectType == app.settings.projectTypes[0])
        #expect(app.draft.type == app.settings.projectTypes[0])
        #expect(app.templates.first { $0.id == standard.id }?.defaultProjectTypes.contains(renamed) == false)

        for type in app.settings.projectTypes { app.removeProjectType(type) }
        #expect(app.settings.projectTypes.count == 1)
    }

    @Test func projectTypesLoadFromOldAndNewSettings() throws {
        let old = #"{"defaultProjectType": "Golf Tournament"}"#
        let loaded = try JSONDecoder().decode(AppSettings.self, from: Data(old.utf8))
        #expect(loaded.projectTypes == ProjectType.builtIn)
        #expect(loaded.defaultProjectType == .golfTournament)

        let custom = #"{"projectTypes": ["Wedding", "Corporate"], "defaultProjectType": "Event"}"#
        let customLoaded = try JSONDecoder().decode(AppSettings.self, from: Data(custom.utf8))
        #expect(customLoaded.projectTypes.map(\.rawValue) == ["Wedding", "Corporate"])
        #expect(customLoaded.defaultProjectType.rawValue == "Wedding")

        // Saved as plain text, exactly like the old fixed list.
        let data = try JSONEncoder().encode(ProjectType.event)
        #expect(String(decoding: data, as: UTF8.self) == #""Event""#)
    }
}

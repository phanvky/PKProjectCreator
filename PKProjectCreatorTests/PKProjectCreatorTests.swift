import Foundation
import Testing
@testable import PKProjectCreator

@MainActor
struct ProjectNameGeneratorTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return try #require(Calendar(identifier: .gregorian).date(from: components))
    }

    @Test func generatedNameMatchesApprovedFormat() throws {
        let name = ProjectNameGenerator.generatedName(date: try date(2026, 11, 12), type: .event, projectName: "Develon")
        #expect(name == "2026 - 11 - 12 Event Develon")
    }

    @Test func placeholderWhileNameIsEmpty() throws {
        let name = ProjectNameGenerator.displayName(date: try date(2026, 1, 5), type: .golfTournament, projectName: "  ")
        #expect(name == "2026 - 01 - 05 Golf Tournament [Project Name]")
    }

    @Test(arguments: ["Lễ hội Đà Lạt", "Tom & Jerry's (Day-1)", "Develon"])
    func acceptsValidNames(_ input: String) {
        #expect(ProjectNameGenerator.issue(forProjectName: input, generatedName: "2026 - 11 - 12 Event \(input)") == nil)
    }

    @Test func rejectsInvalidNames() {
        #expect(ProjectNameGenerator.issue(forProjectName: "", generatedName: "") == .empty)
        #expect(ProjectNameGenerator.issue(forProjectName: "   ", generatedName: "") == .empty)
        #expect(ProjectNameGenerator.issue(forProjectName: "Develon / Gala", generatedName: "x") == .forbiddenCharacter)
        #expect(ProjectNameGenerator.issue(forProjectName: "A:B", generatedName: "x") == .forbiddenCharacter)
        #expect(ProjectNameGenerator.issue(forProjectName: "A\tB", generatedName: "x") == .controlCharacter)
        let long = String(repeating: "Đ", count: 130)
        #expect(ProjectNameGenerator.issue(forProjectName: long, generatedName: long) == .tooLong)
    }

    @Test func rejectsNULAndPathSeparators() {
        #expect(ProjectNameGenerator.issue(forProjectName: "A\0B", generatedName: "x") == .controlCharacter)
        #expect(ProjectNameGenerator.issue(forProjectName: "../Other", generatedName: "x") == .forbiddenCharacter)
    }
}

@MainActor
struct FolderTemplateTests {
    @Test func standardProductionMatchesApprovedStructure() {
        let template = FolderTemplate.standardProduction()
        #expect(template.nodes.map(\.name) == ["01_Footages", "02_Music", "03_SFX", "04_Project", "05_AI", "06_Graphic", "07_Export"])
        #expect(template.nodes[0].children.map(\.name) == ["Cam 01", "Cam 02", "Flycam", "FPV", "Cam 360", "Action Cam"])
        #expect(template.nodes[3].children.map(\.name) == ["Premiere Pro", "DaVinci Resolve", "After Effects"])
        #expect(template.nodes[4].children.map(\.name) == ["Images", "Video"])
        #expect(template.folderCount == 18)
        #expect(template.folderCount + 1 == 19)
        #expect(template.isConfigured)
        #expect(template.defaultTypesList == [.event, .psc, .psh, .tour, .golfTournament, .tvc])
    }

    @Test func reelsLiteNeedsConfigurationAndIsNotADefault() {
        let template = FolderTemplate.reelsLite()
        #expect(template.nodes.isEmpty)
        #expect(!template.isConfigured)
        #expect(template.defaultProjectTypes.isEmpty)
    }

    @Test func codableRoundtripKeepsIDsAndNesting() throws {
        var template = FolderTemplate.standardProduction()
        let deep = template.addFolder(inParent: template.nodes[3].children[0].id)
        template.addFolder(inParent: deep.id)
        let decoded = try JSONDecoder().decode(FolderTemplate.self, from: JSONEncoder().encode(template))
        #expect(decoded == template)
        #expect(decoded.folderCount == 20)
    }

    @Test func nestedAddRenameDeleteAndReorder() throws {
        var template = FolderTemplate.standardProduction()
        let project = template.nodes[3]
        let premiere = project.children[0]

        let added = template.addFolder(inParent: premiere.id)
        let second = template.addFolder(inParent: premiere.id)
        #expect(added.name == "New Folder")
        #expect(second.name == "New Folder 2")
        #expect(template.folderCount == 20)

        try template.renameFolder(project.id, to: "04_Dự án (Edit) & Tom's - v2")
        #expect(template.nodes.node(withID: project.id)?.children.count == 3)
        #expect(template.nodes.node(withID: added.id) != nil)

        template.nodes.move(premiere.id, by: 1)
        #expect(template.nodes.node(withID: project.id)?.children.map(\.name) == ["DaVinci Resolve", "Premiere Pro", "After Effects"])
        template.nodes.move(premiere.id, by: 5)
        #expect(template.nodes.node(withID: project.id)?.children.map(\.name) == ["DaVinci Resolve", "Premiere Pro", "After Effects"])

        template.nodes.remove(project.id)
        #expect(template.folderCount == 14)
        #expect(template.nodes.node(withID: added.id) == nil)
    }

    @Test(arguments: ["Lễ hội Đà Lạt", "Tom & Jerry's (Day-1)", "Cam 01", "CON", "a?b*c", ".hidden"])
    func acceptsMacFolderNames(_ name: String) {
        #expect(FolderNaming.issue(for: name, siblings: ["Other"]) == nil)
    }

    @Test func rejectsInvalidFolderNames() {
        #expect(FolderNaming.issue(for: "", siblings: []) == .empty)
        #expect(FolderNaming.issue(for: "  ", siblings: []) == .empty)
        #expect(FolderNaming.issue(for: "a/b", siblings: []) == .forbiddenCharacter)
        #expect(FolderNaming.issue(for: "a:b", siblings: []) == .forbiddenCharacter)
        #expect(FolderNaming.issue(for: "a\nb", siblings: []) == .controlCharacter)
        #expect(FolderNaming.issue(for: "..", siblings: []) == .reservedName)
        #expect(FolderNaming.issue(for: String(repeating: "Đ", count: 130), siblings: []) == .tooLong)
    }

    @Test func duplicateNamesAreRefusedOnlyAmongSiblings() throws {
        var template = FolderTemplate.standardProduction()
        let cam02 = template.nodes[0].children[1]
        #expect(throws: FolderEditIssue.duplicateName) { try template.renameFolder(cam02.id, to: "cam 01") }
        try template.renameFolder(cam02.id, to: "Cam 02")
        // The same name is fine under a different parent.
        try template.renameFolder(template.nodes[4].children[0].id, to: "Cam 01")
        #expect(template.nodes[4].children[0].name == "Cam 01")
    }

    @Test func movingFolders() throws {
        var nodes = FolderTemplate.standardProduction().nodes
        let footages = nodes[0], project = nodes[3], ai = nodes[4]
        let images = ai.children[0]

        #expect(throws: FolderEditIssue.moveIntoItself) { try nodes.move(ai.id, intoParent: ai.id) }
        #expect(throws: FolderEditIssue.moveIntoDescendant) { try nodes.move(ai.id, intoParent: images.id) }
        #expect(nodes.totalCount == 18)

        try nodes.move(ai.id, intoParent: project.children[0].id)
        #expect(nodes.allPaths.contains(["04_Project", "Premiere Pro", "05_AI", "Images"]))
        #expect(nodes.totalCount == 18)

        try nodes.move(images.id, intoParent: nil)
        #expect(nodes.last?.id == images.id)

        // A move that would create two siblings with the same name is refused.
        nodes.rename(images.id, to: "Cam 01")
        #expect(throws: FolderEditIssue.duplicateName) { try nodes.move(images.id, intoParent: footages.id) }
    }

    @Test func duplicateTemplateGetsNewIDsAndNoDefaults() throws {
        let app = AppState(directory: nil)
        let source = try #require(app.templates.first)
        let copyID = try #require(app.duplicateTemplate(source.id))
        let copy = try #require(app.templates.first { $0.id == copyID })
        #expect(copy.name == "Standard Production Copy")
        #expect(copy.nodes.allPaths == source.nodes.allPaths)
        #expect(copy.nodes[0].id != source.nodes[0].id)
        #expect(copy.defaultProjectTypes.isEmpty)
        #expect(app.templateNameIssue("standard production", for: copyID) != nil)
    }

    @Test func defaultProjectTypeAssignments() throws {
        let app = AppState(directory: nil)
        let standard = app.templates[0], reels = app.templates[1]

        // Reels — Lite has no folders yet, so it can't be a default; Reels falls back to Standard Production.
        app.setDefault(.reels, isOn: true, forTemplate: reels.id)
        #expect(app.templates[1].defaultProjectTypes.isEmpty)
        #expect(app.defaultTemplate(for: .reels)?.id == standard.id)

        // Once configured it can take a type, and the type leaves its previous template.
        app.updateTemplate(reels.id) { $0.addFolder() }
        app.setDefault(.event, isOn: true, forTemplate: reels.id)
        #expect(app.defaultTemplate(for: .event)?.id == reels.id)
        #expect(app.templates.filter { $0.defaultProjectTypes.contains(.event) }.count == 1)

        // Removing its last folder makes it unusable again and releases its types.
        app.updateTemplate(reels.id) { $0.nodes.removeAll() }
        #expect(!app.templates[1].isConfigured)
        #expect(app.defaultTemplate(for: .event)?.id == standard.id)
    }

    @Test func lastConfiguredTemplateCannotBeDeleted() {
        let app = AppState(directory: nil)
        let standard = app.templates[0], reels = app.templates[1]
        #expect(!app.canRemoveTemplate(standard.id))
        app.removeTemplate(standard.id)
        #expect(app.templates.count == 2)
        app.removeTemplate(reels.id)
        #expect(app.templates.map(\.id) == [standard.id])
    }

    @Test func loadedDataIsRepaired() {
        var second = FolderTemplate.standardProduction()
        second.name = "Second"
        var broken = FolderTemplate.reelsLite()
        broken.isConfigured = true
        broken.defaultProjectTypes = [.reels]
        let repaired = FolderTemplate.normalized([.standardProduction(), second, broken])
        #expect(repaired[1].defaultProjectTypes.isEmpty)
        #expect(!repaired[2].isConfigured)
        #expect(repaired[2].defaultProjectTypes.isEmpty)
    }
}

@MainActor
struct FolderTemplateStoreTests {
    private func makeStore() -> FolderTemplateStore {
        FolderTemplateStore(directory: FileManager.default.temporaryDirectory.appending(path: "PKProjectCreatorTests-\(UUID().uuidString)"))
    }

    @Test func firstLaunchSeedsDefaultsOnceAndKeepsCustomizations() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        let app = AppState(directory: store.directory)
        #expect(app.notice == nil)
        #expect(app.templates.map(\.name) == ["Standard Production", "Reels — Lite"])
        #expect(FileManager.default.fileExists(atPath: store.fileURL.path))

        app.renameTemplate(app.templates[0].id, to: "Sản xuất chuẩn")
        try app.updateTemplate(app.templates[0].id) { try $0.renameFolder($0.nodes[0].id, to: "01_Quay") }

        let relaunched = AppState(directory: store.directory)
        #expect(relaunched.notice == nil)
        #expect(relaunched.templates == app.templates)
        #expect(relaunched.templates[0].name == "Sản xuất chuẩn")
        #expect(relaunched.templates[0].nodes[0].name == "01_Quay")
    }

    @Test func corruptedFileIsKeptAndBackupIsRestored() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        let app = AppState(directory: store.directory)
        app.renameTemplate(app.templates[0].id, to: "First edit")
        app.renameTemplate(app.templates[0].id, to: "Second edit")
        try Data("{ not json".utf8).write(to: store.fileURL)

        let recovered = store.load()
        #expect(recovered.notice?.contains("restored from the last backup") == true)
        #expect(recovered.templates[0].name == "First edit")
        #expect(try Data(contentsOf: store.damagedURL) == Data("{ not json".utf8))
        #expect(store.load().notice == nil)
    }

    @Test func corruptedFileWithoutBackupLoadsDefaults() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion": 99, "templates": []}"#.utf8).write(to: store.fileURL)

        let loaded = store.load()
        #expect(loaded.notice?.contains("newer version") == true)
        #expect(loaded.templates.map(\.name) == ["Standard Production", "Reels — Lite"])
        #expect(FileManager.default.fileExists(atPath: store.damagedURL.path))
    }
}

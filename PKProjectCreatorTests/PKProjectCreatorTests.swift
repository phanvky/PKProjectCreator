import Foundation
import Testing
@testable import PKProjectCreator

@MainActor
struct ProjectNamingTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return try #require(Calendar(identifier: .gregorian).date(from: components))
    }

    @Test func generatedNameMatchesApprovedFormat() throws {
        let name = ProjectNaming.generatedName(date: try date(2026, 11, 12), type: .event, projectName: "Develon")
        #expect(name == "2026 - 11 - 12 Event Develon")
    }

    @Test func placeholderWhileNameIsEmpty() throws {
        let name = ProjectNaming.displayName(date: try date(2026, 1, 5), type: .golfTournament, projectName: "  ")
        #expect(name == "2026 - 01 - 05 Golf Tournament [Project Name]")
    }

    @Test(arguments: ["Lễ hội Đà Lạt", "Tom & Jerry's (Day-1)", "Develon"])
    func acceptsValidNames(_ input: String) {
        #expect(ProjectNaming.issue(forProjectName: input, generatedName: "2026 - 11 - 12 Event \(input)") == nil)
    }

    @Test func rejectsInvalidNames() {
        #expect(ProjectNaming.issue(forProjectName: "", generatedName: "") == .empty)
        #expect(ProjectNaming.issue(forProjectName: "   ", generatedName: "") == .empty)
        #expect(ProjectNaming.issue(forProjectName: "Develon / Gala", generatedName: "x") == .forbiddenCharacter)
        #expect(ProjectNaming.issue(forProjectName: "A:B", generatedName: "x") == .forbiddenCharacter)
        #expect(ProjectNaming.issue(forProjectName: "A\tB", generatedName: "x") == .controlCharacter)
        let long = String(repeating: "Đ", count: 130)
        #expect(ProjectNaming.issue(forProjectName: long, generatedName: long) == .tooLong)
    }

    @Test func destinationUsesProjectYear() throws {
        let base = "/Volumes/KIOXIA/PROJECT VIDEO/EVENT"
        let day = try date(2027, 3, 1)
        #expect(ProjectNaming.destinationFolder(base: base, date: day, useYearFolder: true) == "\(base)/2027")
        #expect(ProjectNaming.destinationFolder(base: base, date: day, useYearFolder: false) == base)
    }
}

@MainActor
struct FolderTemplateTests {
    @Test func standardProductionHasEighteenFolders() {
        let template = FolderTemplate.standardProduction()
        #expect(template.folderCount == 18)
        #expect(template.folders.allPaths.contains(["04_Project", "Premiere Pro"]))
    }

    @Test func reelsLiteKeepsApprovedCountWithoutInventedFolders() {
        let template = FolderTemplate.reelsLite()
        #expect(template.folders.isEmpty)
        #expect(template.folderCount + 1 == 9)
        #expect(!template.isStructureSpecified)
    }

    @Test func treeEditing() throws {
        var folders = FolderTemplate.standardProduction().folders
        let project = try #require(folders.first { $0.name == "04_Project" })
        let premiere = try #require(project.children.first)

        folders.appendChild(FolderNode("Proxies"), to: premiere.id)
        #expect(folders.totalCount == 19)

        folders.move(premiere.id, by: 1)
        #expect(folders.node(withID: project.id)?.children.map(\.name) == ["DaVinci Resolve", "Premiere Pro", "After Effects"])

        folders.rename(premiere.id, to: "PR")
        folders.remove(project.id)
        #expect(folders.totalCount == 14)
        #expect(folders.node(withID: premiere.id) == nil)
    }

    @Test func assigningTypeMovesItBetweenTemplates() throws {
        let app = AppState()
        let reels = try #require(app.templates.last)
        app.assign(.event, toTemplate: reels.id)
        #expect(app.defaultTemplate(for: .event)?.id == reels.id)
        #expect(app.templates.filter { $0.defaultTypes.contains(.event) }.count == 1)
    }
}

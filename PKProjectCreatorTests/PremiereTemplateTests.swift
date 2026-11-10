import Foundation
import Testing
@testable import PKProjectCreator

/// Uses small fixture files in temporary folders. Never the real master template, KIOXIA or WORK.
@MainActor
struct PremiereTemplateTests {
    private struct InjectedFailure: Error {}

    private let files = FileManager.default
    private let fixtureBytes = Data("<?xml version=\"1.0\"?><PremiereData Version=\"3\">fixture · Lễ hội</PremiereData>".utf8)
    private let outputPath = "2026/2026 - 11 - 12 Event Develon/04_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj"

    private func makeFolder(_ label: String) throws -> URL {
        let url = files.temporaryDirectory.appending(path: "PK\(label)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try files.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A master template fixture, with its attributes captured so tests can prove it was not changed.
    private func makeMaster(in folder: URL, name: String = "Year - Month - Day - Name 2026.prproj") throws -> URL {
        let url = folder.appending(path: name, directoryHint: .notDirectory)
        try fixtureBytes.write(to: url)
        return url
    }

    private func snapshot(_ url: URL) throws -> [String] {
        let attributes = try files.attributesOfItem(atPath: url.plainPath)
        return [
            String(describing: attributes[.size]), String(describing: attributes[.modificationDate]),
            String(describing: attributes[.posixPermissions]), try Data(contentsOf: url).base64EncodedString(),
            String(describing: try files.contentsOfDirectory(atPath: url.deletingLastPathComponent().plainPath).sorted()),
        ]
    }

    private func plan(in destination: URL, folders: [FolderNode]? = nil) throws -> ProjectCreationPlan {
        let template = FolderTemplate.standardProduction()
        let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12)))
        return ProjectCreationPlan(
            date: date, type: .event, projectName: "Develon",
            templateID: template.id, templateName: template.name, folders: folders ?? template.nodes,
            destinationFolderURL: destination, useYearFolder: true,
            createsPremiereProject: true, premiereFolder: ["04_Project", "Premiere Pro"]
        )
    }

    private func error(_ body: () async throws -> Void) async -> ProjectCreationError? {
        do {
            try await body()
            return nil
        } catch {
            return error as? ProjectCreationError
        }
    }

    // MARK: End to end

    @Test func createsFoldersAndCopiesTheMasterUnderTheGeneratedName() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)
        let before = try snapshot(master)

        let project = try await ProjectCreationService().create(try plan(in: destination), in: destination, premiereTemplate: master)

        let output = destination.appending(path: outputPath)
        #expect(try Data(contentsOf: output) == fixtureBytes)
        #expect(try files.attributesOfItem(atPath: output.plainPath)[.size] as? Int == fixtureBytes.count)
        let root = destination.appending(path: "2026/2026 - 11 - 12 Event Develon")
        let entries = files.enumerator(atPath: root.plainPath)?.compactMap { $0 as? String } ?? []
        #expect(entries.count == 19)
        #expect(entries.filter { $0.hasSuffix(".prproj") } == ["04_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj"])
        #expect(try files.contentsOfDirectory(atPath: destination.appending(path: "2026").plainPath) == ["2026 - 11 - 12 Event Develon"])
        #expect(project.hasPremiereProject)
        #expect(project.premiereProjectRelativePath == "04_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj")
        // The master was only read: same bytes, size, date, permissions, and nothing new beside it.
        #expect(try snapshot(master) == before)
    }

    @Test func appCreatesTheFullProjectWithRealPermissions() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)
        let before = try snapshot(master)
        let app = AppState(directory: nil)
        app.settings.openFinderAfterCreation = false
        app.settings.openPremiereAfterCreation = false
        app.setDestination(destination)
        app.setPremiereTemplate(master)
        app.draft.date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12)))
        app.draft.projectName = "Develon"

        #expect(app.premiereTemplate.templateLabel == "Ready to copy")
        #expect(app.creationBlocker == nil)
        #expect(app.creationStatus.text.contains("and the Premiere project"))
        app.createProject()
        await app.creationTask?.value

        #expect(app.notice == nil)
        #expect(app.createdProject?.hasPremiereProject == true)
        #expect(try Data(contentsOf: destination.appending(path: outputPath)) == fixtureBytes)
        #expect(try snapshot(master) == before)
    }

    // MARK: Refusals before anything is written

    @Test func badSourcesAreRefusedAndNothingIsCreated() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let service = ProjectCreationService()

        let missing = work.appending(path: "Gone.prproj")
        #expect(await error { _ = try await service.create(try plan(in: destination), in: destination, premiereTemplate: missing) } == .premiere(.missing("Gone.prproj")))

        let text = try makeMaster(in: work, name: "Notes.txt")
        #expect(await error { _ = try await service.create(try plan(in: destination), in: destination, premiereTemplate: text) } == .premiere(.wrongExtension("Notes.txt")))

        let folder = work.appending(path: "Bundle.prproj", directoryHint: .isDirectory)
        try files.createDirectory(at: folder, withIntermediateDirectories: false)
        #expect(await error { _ = try await service.create(try plan(in: destination), in: destination, premiereTemplate: folder) } == .premiere(.notAFile("Bundle.prproj")))

        let locked = try makeMaster(in: work, name: "Locked.prproj")
        try files.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.plainPath)
        defer { try? files.setAttributes([.posixPermissions: 0o644], ofItemAtPath: locked.plainPath) }
        #expect(await error { _ = try await service.create(try plan(in: destination), in: destination, premiereTemplate: locked) } == .premiere(.notReadable("Locked.prproj")))

        // The folder template has no 04_Project/Premiere Pro to copy into.
        let master = try makeMaster(in: work)
        let noProjectFolder = FolderTemplate.standardProduction().nodes.filter { $0.name != "04_Project" }
        #expect(await error { _ = try await service.create(try plan(in: destination, folders: noProjectFolder), in: destination, premiereTemplate: master) } == .premiereFolderMissing("04_Project/Premiere Pro"))

        #expect(try files.contentsOfDirectory(atPath: destination.plainPath).isEmpty)
    }

    // MARK: Failures during the copy

    @Test func copyFailureCleansUpStagingAndKeepsTheMaster() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)
        let before = try snapshot(master)
        let service = ProjectCreationService(willWrite: { url in
            if url.pathExtension == "prproj" { throw InjectedFailure() }
        })

        let failure = await error { _ = try await service.create(try plan(in: destination), in: destination, premiereTemplate: master) }

        guard case .failed = failure else { Issue.record("expected .failed, got \(String(describing: failure))"); return }
        #expect(failure?.localizedDescription.contains("master template was not changed") == true)
        #expect(try files.contentsOfDirectory(atPath: destination.plainPath).isEmpty)
        #expect(try snapshot(master) == before)
    }

    @Test func copyRefusesCollisionsAndMissingFolders() throws {
        let folder = try makeFolder("Output"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: folder); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)

        let existing = folder.appending(path: "2026 - 11 - 12 Event Develon.prproj")
        try Data("someone else's edit".utf8).write(to: existing)
        #expect(throws: PremiereTemplateError.outputExists("2026 - 11 - 12 Event Develon.prproj")) {
            try PremiereTemplateService.copy(master, into: folder, generatedName: "2026 - 11 - 12 Event Develon")
        }
        #expect(try Data(contentsOf: existing) == Data("someone else's edit".utf8))

        #expect(throws: PremiereTemplateError.destinationFolderMissing("Nowhere")) {
            try PremiereTemplateService.copy(master, into: folder.appending(path: "Nowhere"), generatedName: "X")
        }

        let copy = try PremiereTemplateService.copy(master, into: folder, generatedName: "2026 - 11 - 12 Event Lễ hội (A&B)")
        #expect(copy.lastPathComponent == "2026 - 11 - 12 Event Lễ hội (A&B).prproj")
        #expect(files.contentsEqual(atPath: copy.plainPath, andPath: master.plainPath))
    }

    @Test func projectCollisionLeavesTheExistingPremiereProjectAlone() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = try makeMaster(in: work)
        let plan = try plan(in: destination)
        _ = try await ProjectCreationService().create(plan, in: destination, premiereTemplate: master)
        let edited = destination.appending(path: outputPath)
        try Data("edited in Premiere".utf8).write(to: edited)

        let failure = await error { _ = try await ProjectCreationService().create(plan, in: destination, premiereTemplate: master) }

        #expect(failure == .alreadyExists("2026 - 11 - 12 Event Develon"))
        #expect(try Data(contentsOf: edited) == Data("edited in Premiere".utf8))
    }

    // MARK: Template states, independent of the destination drive

    @Test func templateStatesAreReportedIndependentlyOfKIOXIA() throws {
        let system = FakeSystem()
        system.mount("KIOXIA", uuid: "KIOXIA-UUID", at: "/Volumes/KIOXIA")
        system.mount("WORK", uuid: "WORK-UUID", at: "/Volumes/WORK")
        let destination = URL(filePath: "/Volumes/KIOXIA/PROJECT VIDEO/EVENT")
        let master = URL(filePath: "/Volumes/WORK/Templates/Master.prproj")
        system.existingPaths = [destination.plainPath, master.plainPath]
        let app = AppState(directory: nil, fileAccess: FileAccessService(system: system))
        app.setDestination(destination)
        app.setPremiereTemplate(master)
        app.draft.projectName = "Develon"
        #expect(app.premiereTemplate.templateLabel == "Ready to copy")
        #expect(app.creationBlocker == nil)

        func templateAfterRefresh() -> String {
            app.refreshResources()
            return app.premiereTemplate.templateLabel
        }

        system.unreadablePaths = [master.plainPath]
        #expect(templateAfterRefresh() == "Permission denied")
        system.unreadablePaths = []
        system.deniedPaths = [master.plainPath]
        #expect(templateAfterRefresh() == "Permission denied")
        system.deniedPaths = []

        system.existingPaths.remove(master.plainPath)
        #expect(templateAfterRefresh() == "Template missing")
        system.existingPaths.insert(master.plainPath)

        system.unmount("WORK")
        #expect(templateAfterRefresh() == "WORK disconnected")
        #expect(app.destination.state == .authorized)
        #expect(app.creationBlocker?.text.contains("“WORK” is disconnected") == true)
        // Folders only stays possible while WORK is away, by the user's explicit choice.
        app.draft.createPremiere = false
        #expect(app.creationBlocker == nil)
        app.draft.createPremiere = true

        system.mount("WORK", uuid: "WORK-UUID", at: "/Volumes/WORK")
        system.unmount("KIOXIA")
        #expect(templateAfterRefresh() == "Ready to copy")
        #expect(app.destination.state == .disconnected)
        #expect(app.creationBlocker?.text.contains("“KIOXIA” is disconnected") == true)
        system.mount("KIOXIA", uuid: "KIOXIA-UUID", at: "/Volumes/KIOXIA")

        system.staleBookmarks = true
        system.canMakeBookmarks = false
        #expect(templateAfterRefresh() == "Bookmark stale")
    }

    @Test func aFolderNamedLikeATemplateIsInvalid() {
        let system = FakeSystem()
        system.mount("WORK", uuid: "WORK-UUID", at: "/Volumes/WORK")
        let bundle = URL(filePath: "/Volumes/WORK/Templates/Bundle.prproj", directoryHint: .isDirectory)
        system.existingPaths = [bundle.plainPath]
        system.directoryPaths = [bundle.plainPath]
        let service = FileAccessService(system: system)
        let grant = try? service.authorize(bundle, readOnly: true)
        let status = service.check(bookmark: grant?.bookmark, lastKnownURL: bundle, volume: grant?.volume, readOnly: true, fileExtension: "prproj").status
        #expect(status.templateLabel == "Invalid template file")
    }
}

import Foundation
import Testing
@testable import PKProjectCreator

/// Every test works inside its own temporary folder. Nothing here touches KIOXIA or WORK.
@MainActor
struct ProjectCreationTests {
    private struct InjectedFailure: Error {}

    private let files = FileManager.default

    private func makeDestination() throws -> URL {
        let url = files.temporaryDirectory.appending(path: "PKCreate-\(UUID().uuidString)", directoryHint: .isDirectory)
        try files.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    private func plan(
        in destination: URL, name: String = "Develon", folders: [FolderNode]? = nil,
        useYearFolder: Bool = true, premiere: Bool = false
    ) throws -> ProjectCreationPlan {
        let template = FolderTemplate.standardProduction()
        return ProjectCreationPlan(
            date: try date(2026, 11, 12), type: .event, projectName: name,
            templateID: template.id, templateName: template.name, folders: folders ?? template.nodes,
            destinationFolderURL: destination, useYearFolder: useYearFolder,
            createsPremiereProject: premiere, premiereFolder: ["04_Project", "Premiere Pro"]
        )
    }

    /// Every directory below `url`, as relative paths.
    private func directories(in url: URL) -> Set<String> {
        Set(files.enumerator(atPath: url.plainPath)?.compactMap { $0 as? String } ?? [])
    }

    private func error(_ body: () async throws -> Void) async -> ProjectCreationError? {
        do {
            try await body()
            return nil
        } catch {
            return error as? ProjectCreationError
        }
    }

    @Test func planDescribesNameLocationsAndStructure() throws {
        let destination = URL(filePath: "/Volumes/KIOXIA/PROJECT VIDEO/EVENT", directoryHint: .isDirectory)
        let plan = try plan(in: destination, premiere: true)
        #expect(plan.generatedName == "2026 - 11 - 12 Event Develon")
        #expect(plan.yearFolderURL.plainPath == "/Volumes/KIOXIA/PROJECT VIDEO/EVENT/2026")
        #expect(plan.projectURL.plainPath == "/Volumes/KIOXIA/PROJECT VIDEO/EVENT/2026/2026 - 11 - 12 Event Develon")
        #expect(plan.directoryCount == 19)
        #expect(plan.premiereOutputRelativePath == "04_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj")

        let custom = try self.plan(in: URL(filePath: "/Users/me/Jobs"), useYearFolder: false)
        #expect(custom.yearFolderName == nil)
        #expect(custom.projectURL.plainPath == "/Users/me/Jobs/2026 - 11 - 12 Event Develon")
        #expect(custom.premiereOutputRelativePath == nil)
    }

    @Test func createsExactlyTheStandardStructure() async throws {
        let destination = try makeDestination()
        defer { try? files.removeItem(at: destination) }
        let plan = try plan(in: destination)

        let project = try await ProjectCreationService().create(plan, in: destination)

        let root = destination.appending(path: "2026/2026 - 11 - 12 Event Develon")
        #expect(directories(in: root) == Set(FolderTemplate.standardProduction().nodes.allPaths.map { $0.joined(separator: "/") }))
        #expect(directories(in: root).count == 18)
        // The year folder holds the project and nothing else: no staging folder is left behind.
        #expect(try files.contentsOfDirectory(atPath: destination.appending(path: "2026").plainPath) == ["2026 - 11 - 12 Event Develon"])
        #expect(project.fullPath == root.plainPath + "/")
        #expect(project.directoryCount == 19)
        #expect(!project.hasPremiereProject)
        #expect(try JSONDecoder().decode(RecentProject.self, from: JSONEncoder().encode(project)) == project)
    }

    @Test func createsDeepNestingVietnameseNamesAndCustomDestination() async throws {
        let destination = try makeDestination()
        defer { try? files.removeItem(at: destination) }
        let deep = [FolderNode("Cấp 1", children: [FolderNode("Cấp 2 (A&B)", children: [FolderNode("Tom's", children: [FolderNode("Cấp 4 - cuối")])])])]
        let plan = try plan(in: destination, name: "Lễ hội Đà Lạt (Tom & Jerry's)", folders: deep, useYearFolder: false)

        _ = try await ProjectCreationService().create(plan, in: destination)

        let root = destination.appending(path: "2026 - 11 - 12 Event Lễ hội Đà Lạt (Tom & Jerry's)")
        var isDirectory: ObjCBool = false
        #expect(files.fileExists(atPath: root.appending(path: "Cấp 1/Cấp 2 (A&B)/Tom's/Cấp 4 - cuối").plainPath, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(directories(in: root).count == 4)
    }

    @Test func neverOverwritesOrMergesIntoAnExistingProject() async throws {
        let destination = try makeDestination()
        defer { try? files.removeItem(at: destination) }
        let plan = try plan(in: destination)
        _ = try await ProjectCreationService().create(plan, in: destination)
        let footage = plan.projectFolder(in: destination).appending(path: "01_Footages/Cam 01/clip.mov")
        try Data("footage".utf8).write(to: footage)
        try files.removeItem(at: plan.projectFolder(in: destination).appending(path: "07_Export"))

        let failure = await error { _ = try await ProjectCreationService().create(plan, in: destination) }

        #expect(failure == .alreadyExists("2026 - 11 - 12 Event Develon"))
        #expect(try Data(contentsOf: footage) == Data("footage".utf8))
        // Not merged: the folder the user deleted was not put back.
        #expect(!files.fileExists(atPath: plan.projectFolder(in: destination).appending(path: "07_Export").plainPath))
        #expect(try files.contentsOfDirectory(atPath: plan.parentFolder(in: destination).plainPath).count == 1)
    }

    @Test func failureCleansUpStagingAndKeepsOtherData() async throws {
        let destination = try makeDestination()
        defer { try? files.removeItem(at: destination) }
        let service = ProjectCreationService(willWrite: { folder in
            if folder.lastPathComponent == "04_Project" { throw InjectedFailure() }
        })

        // The year folder didn't exist before: it is removed again, so the destination is exactly as it was.
        let first = await error { _ = try await service.create(try plan(in: destination), in: destination) }
        guard case .failed = first else { Issue.record("expected .failed, got \(String(describing: first))"); return }
        #expect(try files.contentsOfDirectory(atPath: destination.plainPath).isEmpty)

        // The year folder already holds someone else's project: it and its contents stay untouched.
        let other = destination.appending(path: "2026/Other Project/notes.txt")
        try files.createDirectory(at: other.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: other)
        _ = await error { _ = try await service.create(try plan(in: destination), in: destination) }
        #expect(try files.contentsOfDirectory(atPath: destination.appending(path: "2026").plainPath) == ["Other Project"])
        #expect(try Data(contentsOf: other) == Data("keep".utf8))
    }

    @Test func cancellationLeavesNothingBehind() async throws {
        let destination = try makeDestination()
        defer { try? files.removeItem(at: destination) }
        let service = ProjectCreationService(willWrite: { folder in
            if folder.lastPathComponent == "03_SFX" { withUnsafeCurrentTask { $0?.cancel() } }
        })

        // Runs in its own task, so the hook cancels the creation and not the test itself.
        let plan = try plan(in: destination)
        let creation = Task { try await service.create(plan, in: destination) }
        let failure = await error { _ = try await creation.value }

        #expect(failure == .cancelled)
        #expect(try files.contentsOfDirectory(atPath: destination.plainPath).isEmpty)
    }

    @Test func refusesBeforeTouchingTheDisk() async throws {
        let destination = try makeDestination()
        defer { try? files.removeItem(at: destination) }
        let service = ProjectCreationService()

        for name in ["", "   ", "Gala / Day 2", "A:B", "A\nB"] {
            let failure = await error { _ = try await service.create(try plan(in: destination, name: name), in: destination) }
            guard case .invalidName = failure else { Issue.record("“\(name)” was not refused"); continue }
        }
        // A plan that wants a Premiere project but has no template is refused, never turned into folders only.
        #expect(await error { _ = try await service.create(try plan(in: destination, premiere: true), in: destination) } == .premiereTemplateUnavailable)
        #expect(await error { _ = try await service.create(try plan(in: destination, folders: []), in: destination) } == .templateNotConfigured("Standard Production"))
        #expect(try files.contentsOfDirectory(atPath: destination.plainPath).isEmpty)

        let missing = destination.appending(path: "Unplugged", directoryHint: .isDirectory)
        #expect(await error { _ = try await service.create(try plan(in: missing), in: missing) } == .destinationUnavailable(missing.plainPath))
    }

    @Test func appCreatesAProjectInAnAuthorizedFolder() async throws {
        let destination = try makeDestination()
        defer { try? files.removeItem(at: destination) }
        let app = AppState(directory: nil)
        app.settings.openFinderAfterCreation = false
        app.setDestination(destination)
        app.draft.date = try date(2026, 11, 12)
        app.draft.projectName = "Develon"

        // With Premiere on and no template chosen, creation is blocked.
        #expect(app.creationBlocker?.text.contains("Premiere template") == true)
        app.createProject()
        #expect(app.creationTask == nil)

        app.draft.createPremiere = false
        #expect(app.creationBlocker == nil)
        #expect(app.creationPlan.folders == app.selectedTemplate?.nodes)
        app.createProject()
        await app.creationTask?.value

        #expect(app.notice == nil)
        #expect(app.createdProject?.name == "2026 - 11 - 12 Event Develon")
        #expect(directories(in: destination.appending(path: "2026/2026 - 11 - 12 Event Develon")).count == 18)
        #expect(app.draft.projectName.isEmpty)

        // The same project again is refused and reported, not overwritten.
        app.createdProject = nil
        app.draft.projectName = "Develon"
        app.createProject()
        await app.creationTask?.value
        #expect(app.createdProject == nil)
        #expect(app.notice?.contains("already exists") == true)
    }

    @Test func appBlocksCreationWhileTheDestinationIsUnavailable() {
        let system = FakeSystem()
        system.mount("WORK", uuid: "WORK-UUID", at: "/Volumes/WORK")
        let app = AppState(directory: nil, fileAccess: FileAccessService(system: system))
        app.draft.projectName = "Develon"
        app.draft.createPremiere = false

        #expect(app.creationBlocker?.text.contains("“KIOXIA” is disconnected") == true)
        app.createProject()
        #expect(app.creationTask == nil)
    }
}

/// Phase 07 hardening: names, path safety, error wording, non-recursive deletes.
@MainActor
struct HardeningTests {
    private let files = FileManager.default

    private func makeFolder() throws -> URL {
        let url = files.temporaryDirectory.appending(path: "PKHardening-\(UUID().uuidString)", directoryHint: .isDirectory)
        try files.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func plan(_ name: String, in destination: URL, folders: [FolderNode] = FolderTemplate.standardProduction().nodes, premiere: Bool = false) throws -> ProjectCreationPlan {
        let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12)))
        return ProjectCreationPlan(
            date: date, type: .psc, projectName: name, templateID: UUID(), templateName: "Standard Production", folders: folders,
            destinationFolderURL: destination, useYearFolder: false, createsPremiereProject: premiere, premiereFolder: ["04_Project", "Premiere Pro"]
        )
    }

    @Test(arguments: ["Tùng & Thảo", "Lễ cưới (2) O'Neil - 12", "Café Đà Lạt 3"])
    func vietnameseAndPunctuationAreKeptExactly(name: String) async throws {
        let destination = try makeFolder(), work = try makeFolder()
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = work.appending(path: "Master.prproj")
        try Data("p".utf8).write(to: master)
        let plan = try plan(name, in: destination, premiere: true)
        #expect(plan.generatedName == "2026 - 11 - 12 PSC \(name)")

        _ = try await ProjectCreationService().create(plan, in: destination, premiereTemplate: master)

        let created = try files.contentsOfDirectory(atPath: destination.plainPath)
        #expect(created.map { $0.precomposedStringWithCanonicalMapping } == [plan.generatedName.precomposedStringWithCanonicalMapping])
        let premiere = try files.contentsOfDirectory(atPath: plan.projectFolder(in: destination).appending(path: "04_Project/Premiere Pro").plainPath)
        #expect(premiere.map { $0.precomposedStringWithCanonicalMapping } == ["\(plan.generatedName).prproj".precomposedStringWithCanonicalMapping])
    }

    @Test(arguments: ["..", "a/b", "", "x:y"])
    func aDamagedTemplateCantWriteOutsideTheProject(badName: String) async throws {
        let destination = try makeFolder()
        defer { try? files.removeItem(at: destination) }
        let folders = [FolderNode("01_Footages", children: [FolderNode(badName)])]
        await #expect(throws: ProjectCreationError.invalidFolderName("01_Footages/\(badName)")) {
            _ = try await ProjectCreationService().create(try plan("Safe", in: destination, folders: folders), in: destination)
        }
        #expect(try files.contentsOfDirectory(atPath: destination.plainPath).isEmpty)
        #expect(!files.fileExists(atPath: destination.deletingLastPathComponent().appending(path: "01_Footages").plainPath))
    }

    @Test func systemErrorsGetAPlainExplanation() {
        #expect(FileErrorText.describe(CocoaError(.fileWriteOutOfSpace)).contains("enough free space"))
        #expect(FileErrorText.describe(POSIXError(.ENOSPC)).contains("enough free space"))
        #expect(FileErrorText.describe(CocoaError(.fileWriteNoPermission)).contains("reauthorize"))
        #expect(FileErrorText.describe(POSIXError(.EROFS)).contains("read-only"))
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 512, userInfo: [NSUnderlyingErrorKey: POSIXError(.ENOENT) as NSError])
        #expect(FileErrorText.describe(wrapped).contains("disconnected"))
        #expect(FileErrorText.describe(CocoaError(.fileWriteUnknown)).hasPrefix("A disk operation failed ("))
        #expect(FileErrorText.describe(ProjectCreationError.cancelled) == ProjectCreationError.cancelled.localizedDescription)
    }

    @Test func emptyFolderRemovalIsNeverRecursive() throws {
        let root = try makeFolder()
        defer { try? files.removeItem(at: root) }
        let empty = root.appending(path: "Empty"), full = root.appending(path: "Full"), nested = root.appending(path: "Nested")
        for url in [empty, full, nested] { try files.createDirectory(at: url, withIntermediateDirectories: false) }
        try Data().write(to: empty.appending(path: ".DS_Store"))
        try Data("x".utf8).write(to: full.appending(path: "clip.mov"))
        try files.createDirectory(at: nested.appending(path: "Inside"), withIntermediateDirectories: false)

        try files.removeEmptyFolder(at: empty)
        #expect(!files.fileExists(atPath: empty.plainPath))
        #expect(throws: (any Error).self) { try files.removeEmptyFolder(at: full) }
        #expect(throws: (any Error).self) { try files.removeEmptyFolder(at: nested) }
        #expect(files.fileExists(atPath: full.appending(path: "clip.mov").plainPath))
        #expect(files.fileExists(atPath: nested.appending(path: "Inside").plainPath))
    }

    @Test func copyFailureWithAFullDriveIsExplainedAndRolledBack() async throws {
        let destination = try makeFolder(), work = try makeFolder()
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = work.appending(path: "Master.prproj")
        try Data("p".utf8).write(to: master)
        let before = try Data(contentsOf: master)
        let existing = destination.appending(path: "Older Project")
        try files.createDirectory(at: existing, withIntermediateDirectories: false)
        var service = ProjectCreationService()
        // The drive fills up (or disappears) just as the Premiere file is copied.
        service.willWrite = { url in if url.pathExtension == "prproj" { throw CocoaError(.fileWriteOutOfSpace) } }

        do {
            _ = try await service.create(try plan("Full Drive", in: destination, premiere: true), in: destination, premiereTemplate: master)
            Issue.record("Expected a failure")
        } catch let error as ProjectCreationError {
            #expect(error.localizedDescription.contains("enough free space"))
        }
        #expect(try files.contentsOfDirectory(atPath: destination.plainPath) == ["Older Project"])
        #expect(try Data(contentsOf: master) == before)
    }
}

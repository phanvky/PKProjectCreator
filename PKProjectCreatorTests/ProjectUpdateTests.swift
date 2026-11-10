import Foundation
import Testing
@testable import PKProjectCreator

/// Update Project on real temporary folders. Never KIOXIA, WORK or the real master template.
@MainActor
struct ProjectUpdateTests {
    private struct InjectedFailure: Error {}

    private let files = FileManager.default
    private let premiereFolder = ["04_Project", "Premiere Pro"]
    private let resolveFolder = ["04_Project", "DaVinci Resolve"]

    private func makeFolder(_ label: String) throws -> URL {
        let url = files.temporaryDirectory.appending(path: "PK\(label)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try files.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func mkdir(_ root: URL, _ path: String) throws {
        try files.createDirectory(at: root.appending(path: path, directoryHint: .isDirectory), withIntermediateDirectories: true)
    }

    private func write(_ root: URL, _ path: String) throws {
        try Data("footage".utf8).write(to: root.appending(path: path))
    }

    private func exists(_ root: URL, _ path: String) -> Bool {
        files.fileExists(atPath: root.appending(path: path).plainPath)
    }

    /// A small existing project: one folder with a file, empty folders, Finder metadata and a hidden folder.
    private func makeProject() throws -> URL {
        let root = try makeFolder("Project")
        try mkdir(root, "01_Footages/Cam 01")
        try write(root, "01_Footages/Cam 01/A001.mov")
        try mkdir(root, "01_Footages/Flycam")
        try write(root, "01_Footages/Flycam/.DS_Store")
        try mkdir(root, "02_Music")
        try mkdir(root, "04_Project/Premiere Pro")
        try mkdir(root, "04_Project/DaVinci Resolve")
        try mkdir(root, "04_Project/DaVinci Resolve/.gallery")
        try mkdir(root, "05_AI/a/b/c/d")
        return root
    }

    private func session(_ root: URL, project: RecentProject? = nil) async throws -> ProjectUpdateSession {
        let scan = try await ProjectUpdateService().scan(root: root, premiereFolder: premiereFolder, resolveFolder: resolveFolder)
        let record = project ?? RecentProject(
            projectName: "Develon", projectType: .event, projectDate: Date(), folderTemplateID: UUID(),
            folderTemplateName: "Standard Production", directoryCount: 10, destinationPath: root.deletingLastPathComponent().plainPath
        )
        return ProjectUpdateSession(project: record, scan: scan)
    }

    private func id(_ session: ProjectUpdateSession, _ path: [String]) throws -> UUID {
        try #require(session.scan.folders.first { $0.value.path == path }?.key)
    }

    // MARK: Scan

    @Test func scanReadsFoldersAndWhatIsInsideThem() async throws {
        let root = try makeProject()
        defer { try? files.removeItem(at: root) }
        let scan = try await session(root).scan

        #expect(scan.nodes.map(\.name) == ["01_Footages", "02_Music", "04_Project", "05_AI"])
        let byPath = Dictionary(uniqueKeysWithValues: scan.folders.values.map { ($0.path.joined(separator: "/"), $0) })
        #expect(byPath["01_Footages/Cam 01"]?.itemCount == 1)
        #expect(byPath["01_Footages/Flycam"]?.isEmpty == true) // .DS_Store doesn't count
        #expect(byPath["02_Music"]?.isEmpty == true)
        #expect(byPath["04_Project/DaVinci Resolve"]?.itemCount == 1) // the hidden .gallery counts as content…
        #expect(byPath["04_Project/DaVinci Resolve/.gallery"] == nil) // …but isn't shown
        #expect(byPath["05_AI/a/b/c"]?.hasDeeperFolders == true)
        #expect(byPath["05_AI/a/b/c/d"] == nil)
        #expect(!scan.premiereFileExists && !scan.resolveFileExists)
    }

    // MARK: Rules

    @Test func onlyEmptyFoldersCanBeRenamedOrDeleted() async throws {
        let root = try makeProject()
        defer { try? files.removeItem(at: root) }
        var form = try await session(root)
        let cam = try id(form, ["01_Footages", "Cam 01"]), music = try id(form, ["02_Music"])
        let footages = try id(form, ["01_Footages"])

        #expect(form.lockReason(cam) != nil)
        #expect(form.lockReason(footages) != nil)
        #expect(form.lockReason(music) == nil)
        try form.rename(cam, to: "Camera 1")
        form.delete(footages)
        #expect(form.plan(premiereFolder: premiereFolder, resolveFolder: resolveFolder).isEmpty)

        try form.rename(music, to: "02_Audio")
        #expect(throws: FolderEditIssue.duplicateName) { try form.rename(music, to: "04_project") }
        let added = form.addFolder(inParent: music)
        let flycam = try id(form, ["01_Footages", "Flycam"])
        form.delete(flycam)
        let plan = form.plan(premiereFolder: premiereFolder, resolveFolder: resolveFolder)
        #expect(plan.renames == [.init(from: ["02_Music"], to: ["02_Audio"])])
        #expect(plan.creates == [["02_Audio", added.name]])
        #expect(plan.deletes == [["01_Footages", "Flycam"]])
    }

    @Test func projectFilesAreOnlyAddedWhenMissing() async throws {
        let root = try makeProject()
        defer { try? files.removeItem(at: root) }
        try write(root, "04_Project/Premiere Pro/Old.prproj")
        var form = try await session(root)
        form.addPremiere = true
        form.addResolve = true
        #expect(!form.canAddPremiere && form.canAddResolve)
        let plan = form.plan(premiereFolder: premiereFolder, resolveFolder: resolveFolder)
        #expect(plan.premiereFolder == nil)
        #expect(plan.resolveFolder == resolveFolder)

        var recorded = form.project
        recorded.resolveProjectRelativePath = "04_Project/DaVinci Resolve/x.drp"
        #expect(!(try await session(root, project: recorded)).canAddResolve)
    }

    // MARK: Apply

    @Test func appliesRenamesNewFoldersFilesAndDeletes() async throws {
        let root = try makeProject(), work = try makeFolder("Work")
        defer { try? files.removeItem(at: root); try? files.removeItem(at: work) }
        let master = work.appending(path: "Master.prproj")
        try Data("premiere".utf8).write(to: master)
        var form = try await session(root)
        try form.rename(try id(form, ["02_Music"]), to: "02_Audio")
        let sub = form.addFolder(inParent: try id(form, ["02_Music"]))
        form.addFolder(inParent: nil)
        form.delete(try id(form, ["01_Footages", "Flycam"]))
        form.addPremiere = true

        let done = try await ProjectUpdateService().apply(
            form.plan(premiereFolder: premiereFolder, resolveFolder: resolveFolder), in: root, generatedName: "2026 - 11 - 12 Event Develon", premiereTemplate: master
        )

        #expect(done.count == 5)
        #expect(!exists(root, "02_Music") && exists(root, "02_Audio/\(sub.name)") && exists(root, "New Folder"))
        #expect(!exists(root, "01_Footages/Flycam"))
        #expect(try Data(contentsOf: root.appending(path: "04_Project/Premiere Pro/2026 - 11 - 12 Event Develon.prproj")) == Data("premiere".utf8))
        #expect(exists(root, "01_Footages/Cam 01/A001.mov"))
    }

    @Test func aFolderThatGotContentsIsNeverDeletedOrRenamed() async throws {
        let root = try makeProject()
        defer { try? files.removeItem(at: root) }
        var form = try await session(root)
        form.delete(try id(form, ["02_Music"]))
        try write(root, "02_Music/song.wav") // appears after Update Project opened

        await #expect(throws: ProjectUpdateError.self) {
            _ = try await ProjectUpdateService().apply(form.plan(premiereFolder: premiereFolder, resolveFolder: resolveFolder), in: root, generatedName: "x")
        }
        #expect(exists(root, "02_Music/song.wav"))

        var renaming = try await session(root.appending(path: "04_Project"))
        let premiere = try id(renaming, ["Premiere Pro"])
        try renaming.rename(premiere, to: "Premiere")
        try write(root, "04_Project/Premiere Pro/edit.prproj")
        await #expect(throws: ProjectUpdateError.self) {
            _ = try await ProjectUpdateService().apply(renaming.plan(premiereFolder: [], resolveFolder: []), in: root.appending(path: "04_Project"), generatedName: "x")
        }
        #expect(exists(root, "04_Project/Premiere Pro/edit.prproj"))
    }

    @Test func aFailurePartWayStopsAndReportsWhatWasDone() async throws {
        let root = try makeProject()
        defer { try? files.removeItem(at: root) }
        var form = try await session(root)
        form.addFolder(inParent: nil)
        form.addFolder(inParent: nil)
        form.delete(try id(form, ["02_Music"]))
        var service = ProjectUpdateService()
        service.willWrite = { url in if url.lastPathComponent == "New Folder 2" { throw InjectedFailure() } }

        do {
            _ = try await service.apply(form.plan(premiereFolder: premiereFolder, resolveFolder: resolveFolder), in: root, generatedName: "x")
            Issue.record("Expected the update to stop")
        } catch let ProjectUpdateError.stopped(_, done) {
            #expect(done == ["Added “New Folder”"])
        }
        #expect(exists(root, "New Folder") && !exists(root, "New Folder 2"))
        #expect(exists(root, "02_Music")) // later steps, including deletes, never ran
    }

    // MARK: App

    @Test func appUpdatesAProjectItCreatedAndRecordsIt() async throws {
        let destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { try? files.removeItem(at: destination); try? files.removeItem(at: work) }
        let master = work.appending(path: "Master.prproj")
        try Data("premiere".utf8).write(to: master)
        let app = AppState(directory: nil)
        app.settings.openFinderAfterCreation = false
        app.setDestination(destination)
        app.setPremiereTemplate(master)
        app.draft.createPremiere = false
        app.draft.projectName = "Develon"
        app.createProject()
        await app.creationTask?.value
        let project = try #require(app.recentProjects.first)
        #expect(!project.hasPremiereProject)
        #expect(app.canUpdate(project))

        app.beginUpdate(project)
        await app.projectUpdateTask?.value
        #expect(app.projectUpdate?.canAddPremiere == true)
        #expect(app.projectUpdateBlocker?.text == "No changes yet.")
        app.projectUpdate?.addFolder(inParent: nil)
        app.projectUpdate?.addPremiere = true
        #expect(app.projectUpdateBlocker == nil)
        app.applyProjectUpdate()
        await app.projectUpdateTask?.value

        #expect(app.projectUpdate == nil)
        #expect(app.notice?.contains("was updated") == true)
        let updated = try #require(app.recentProjects.first)
        #expect(updated.directoryCount == project.directoryCount + 1)
        #expect(updated.hasPremiereProject)
        #expect(app.recentStatuses[updated.id]?.premiereFileExists == true)
    }
}

import Foundation
import Testing
@testable import PKProjectCreator

/// Recent Projects and the shared JSON store. Real files only ever live in temporary folders.
@MainActor
struct RecentProjectsTests {
    private let files = FileManager.default

    private func makeFolder(_ label: String) throws -> URL {
        let url = files.temporaryDirectory.appending(path: "PK\(label)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try files.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    private func record(
        _ name: String, _ type: ProjectType = .event, date: Date = .now, createdAt: Date = .now,
        in folder: String = "/Volumes/KIOXIA/PROJECT VIDEO/EVENT/2026"
    ) -> RecentProject {
        RecentProject(
            projectName: name, projectType: type, projectDate: date, folderTemplateID: UUID(),
            folderTemplateName: "Standard Production", directoryCount: 19, destinationPath: folder, createdAt: createdAt
        )
    }

    /// Creates a real project with the Premiere copy through the app, in temporary folders.
    private func createProject(_ app: AppState, named name: String) async throws {
        app.draft.projectName = name
        app.createProject()
        await app.creationTask?.value
        #expect(app.notice == nil)
    }

    private func makeApp(directory: URL?, destination: URL, master: URL) -> AppState {
        let app = AppState(directory: directory)
        app.settings.openFinderAfterCreation = false
        app.settings.openPremiereAfterCreation = false
        app.setDestination(destination)
        app.setPremiereTemplate(master)
        return app
    }

    // MARK: Records from creation, removal, restart

    @Test func createdProjectsAreRecordedRemovedOnlyFromTheListAndSurviveARestart() async throws {
        let support = try makeFolder("Support"), destination = try makeFolder("Destination"), work = try makeFolder("Work")
        defer { for url in [support, destination, work] { try? files.removeItem(at: url) } }
        let master = work.appending(path: "Master.prproj")
        try Data("master".utf8).write(to: master)

        let app = makeApp(directory: support, destination: destination, master: master)
        #expect(app.recentProjects.isEmpty)
        try await createProject(app, named: "Develon")
        try await createProject(app, named: "Gala (A&B)")

        #expect(app.recentProjects.map(\.projectName) == ["Gala (A&B)", "Develon"])
        let develon = try #require(app.recentProjects.last)
        #expect(develon.projectRootBookmark != nil)
        #expect(develon.folderTemplateID == app.templates[0].id)
        #expect(develon.hasPremiereProject)
        #expect(app.recentStatuses[develon.id]?.location == .available)
        #expect(app.recentStatuses[develon.id]?.premiereFileExists == true)

        let restarted = AppState(directory: support)
        #expect(restarted.notice == nil)
        #expect(restarted.recentProjects == app.recentProjects)
        #expect(restarted.recentStatuses[develon.id]?.location == .available)

        restarted.removeRecentProject(develon.id)
        #expect(restarted.recentProjects.map(\.projectName) == ["Gala (A&B)"])
        // Only the entry went away: the folder and its Premiere project are still on disk.
        let prproj = develon.rootURL.appending(path: try #require(develon.premiereProjectRelativePath))
        #expect(files.fileExists(atPath: develon.rootURL.plainPath))
        #expect(try Data(contentsOf: prproj) == Data("master".utf8))
        #expect(AppState(directory: support).recentProjects.map(\.projectName) == ["Gala (A&B)"])
    }

    // MARK: Search, filter, sort

    @Test func searchFilterAndDateSort() throws {
        let projects = [
            record("Develon", .event, date: try date(2026, 11, 12)),
            record("Lễ hội Đà Lạt", .tour, date: try date(2026, 3, 1)),
            record("Develon Launch", .tvc, date: try date(2025, 12, 20)),
            record("Spring Cup", .golfTournament, date: try date(2026, 6, 5)),
        ]
        #expect(RecentProject.matching(projects, search: "develon", type: nil).map(\.projectName) == ["Develon", "Develon Launch"])
        #expect(RecentProject.matching(projects, search: "đà lạt", type: nil).map(\.projectName) == ["Lễ hội Đà Lạt"])
        #expect(RecentProject.matching(projects, search: "Develon", type: .tvc).map(\.projectName) == ["Develon Launch"])
        #expect(RecentProject.matching(projects, search: " ", type: .golfTournament).map(\.projectName) == ["Spring Cup"])
        #expect(RecentProject.matching(projects, search: "2026 - 11", type: nil).map(\.projectName) == ["Develon"])

        let newestFirst = projects.sorted(using: KeyPathComparator(\RecentProject.projectDate, order: .reverse))
        #expect(newestFirst.map(\.projectName) == ["Develon", "Spring Cup", "Lễ hội Đà Lạt", "Develon Launch"])
        let oldestFirst = projects.sorted(using: KeyPathComparator(\RecentProject.projectDate))
        #expect(oldestFirst.first?.projectName == "Develon Launch")
    }

    // MARK: Limit

    @Test func limitKeepsTheNewestAndDeletesNothingOnDisk() throws {
        let support = try makeFolder("Support"), disk = try makeFolder("Disk")
        defer { try? files.removeItem(at: support); try? files.removeItem(at: disk) }
        let app = AppState(directory: support)
        #expect(app.settings.maximumRecentProjects == 20)

        for index in 0..<12 {
            let project = record("Project \(index)", createdAt: Date(timeIntervalSince1970: Double(1_000 + index)), in: disk.plainPath)
            try files.createDirectory(at: project.rootURL, withIntermediateDirectories: true)
            app.addRecentProject(project)
        }
        #expect(app.recentProjects.count == 12)

        app.settings.maximumRecentProjects = 10
        #expect(app.recentProjects.map(\.projectName) == (2..<12).reversed().map { "Project \($0)" })
        #expect(try files.contentsOfDirectory(atPath: disk.plainPath).count == 12)

        let restarted = AppState(directory: support)
        #expect(restarted.settings.maximumRecentProjects == 10)
        #expect(restarted.recentProjects.count == 10)
        restarted.addRecentProject(record("Newest", createdAt: Date(timeIntervalSince1970: 5_000), in: disk.plainPath))
        #expect(restarted.recentProjects.count == 10)
        #expect(restarted.recentProjects.first?.projectName == "Newest")
        #expect(!restarted.recentProjects.contains { $0.projectName == "Project 2" })
    }

    // MARK: Drives and missing folders

    @Test func disconnectedAndMissingProjectsAreKept() throws {
        let system = FakeSystem()
        system.mount("KIOXIA", uuid: "KIOXIA-UUID", at: "/Volumes/KIOXIA")
        let project = record("Develon")
        let premiere = "04_Project/Premiere Pro/\(project.name).prproj"
        system.existingPaths = [project.rootURL.plainPath, project.rootURL.appending(path: premiere).plainPath]
        let service = FileAccessService(system: system)
        let grant = try service.authorize(project.rootURL, readOnly: false)
        var stored = project
        stored.projectRootBookmark = grant.bookmark
        stored.volume = grant.volume
        stored.premiereProjectRelativePath = premiere

        let app = AppState(directory: nil, fileAccess: service)
        app.addRecentProject(stored)
        #expect(app.recentStatuses[stored.id]?.location == .available)
        #expect(app.recentStatuses[stored.id]?.premiereFileExists == true)

        system.unmount("KIOXIA")
        app.refreshRecentProjects()
        let away = try #require(app.recentStatuses[stored.id])
        #expect(away.location == .volumeDisconnected)
        #expect(away.label == "KIOXIA disconnected")
        #expect(away.problem?.contains("not deleted") == true)
        #expect(app.recentProjects.map(\.id) == [stored.id])

        system.mount("KIOXIA", uuid: "KIOXIA-UUID", at: "/Volumes/KIOXIA")
        app.refreshRecentProjects()
        #expect(app.recentStatuses[stored.id]?.location == .available)

        system.existingPaths.remove(project.rootURL.appending(path: premiere).plainPath)
        app.refreshRecentProjects()
        #expect(app.recentStatuses[stored.id]?.premiereLabel(for: stored).text == "Missing")

        system.existingPaths = []
        app.refreshRecentProjects()
        #expect(app.recentStatuses[stored.id]?.location == .missing)
        #expect(app.recentProjects.map(\.id) == [stored.id])
    }

    // MARK: New Project Like This

    @Test func newProjectLikeThisPrefillsTypeAndTemplateOnly() throws {
        let app = AppState(directory: nil)
        let copyID = try #require(app.duplicateTemplate(app.templates[0].id))
        var project = record("Old Client", .tour, date: try date(2024, 5, 6))
        project.folderTemplateID = copyID
        app.screen = .recentProjects
        app.draft.projectName = "Something typed"

        app.startProject(like: project)

        #expect(app.screen == .newProject)
        #expect(app.draft.type == .tour)
        #expect(app.draft.templateID == copyID)
        #expect(app.draft.projectName.isEmpty)
        #expect(Calendar.current.isDateInToday(app.draft.date))

        // A template that no longer exists falls back to the type's default.
        project.folderTemplateID = UUID()
        app.startProject(like: project)
        #expect(app.draft.templateID == app.defaultTemplate(for: .tour)?.id)
    }

    // MARK: Persistence safety

    @Test func damagedRecentFileIsKeptAndTheBackupRestored() throws {
        let support = try makeFolder("Support")
        defer { try? files.removeItem(at: support) }
        let store = RecentProjectsStore(directory: support)
        let app = AppState(directory: support)
        app.addRecentProject(record("First"))
        app.addRecentProject(record("Second"))
        try Data("{ broken".utf8).write(to: store.fileURL)

        let recovered = AppState(directory: support)
        #expect(recovered.notice?.contains("recent projects were restored from the last backup") == true)
        #expect(recovered.recentProjects.map(\.projectName) == ["First"])
        #expect(try Data(contentsOf: store.damagedURL) == Data("{ broken".utf8))

        try Data(#"{"schemaVersion": 7, "projects": []}"#.utf8).write(to: store.fileURL)
        try files.removeItem(at: store.backupURL)
        let newer = store.load()
        #expect(newer.projects.isEmpty)
        #expect(newer.notice?.contains("newer version") == true)
        #expect(newer.notice?.contains("not touched") == true)
    }

    @Test func damagedSettingsAreRestoredFromBackupNotReset() throws {
        let support = try makeFolder("Support")
        defer { try? files.removeItem(at: support) }
        let app = AppState(directory: support)
        app.settings.defaultProjectType = .tvc
        app.settings.openPremiereAfterCreation = true
        app.settings.maximumRecentProjects = 50
        app.settings.useYearFolderFromProjectDate = false
        let store = SettingsStore(directory: support)
        try Data("garbage".utf8).write(to: store.fileURL)

        let restarted = AppState(directory: support)
        #expect(restarted.notice?.contains("settings were restored from the last backup") == true)
        // The backup is the version before the last change.
        #expect(restarted.settings.defaultProjectType == .tvc)
        #expect(restarted.settings.openPremiereAfterCreation)
        #expect(restarted.settings.maximumRecentProjects == 50)
        #expect(FileManager.default.fileExists(atPath: store.damagedURL.path))
    }

    @Test func olderSchemaGoesThroughMigration() throws {
        let support = try makeFolder("Support")
        defer { try? files.removeItem(at: support) }
        var store = JSONFileStore<[String]>(directory: support, baseName: "sample", key: "names", schemaVersion: 2)
        store.migrate = { version, data in
            #expect(version == 1)
            let old = try JSONDecoder().decode([String: [String: String]].self, from: Data(String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"schemaVersion\" : 1,", with: "").utf8))
            return old["names"]?.keys.sorted() ?? []
        }
        try Data(#"{"schemaVersion" : 1, "names": {"b": "", "a": ""}}"#.utf8).write(to: store.fileURL)
        #expect(store.load(label: "names", fallback: "empty").value == ["a", "b"])

        try store.save(["c"])
        #expect(store.load(label: "names", fallback: "empty").value == ["c"])
        #expect(try String(contentsOf: store.fileURL, encoding: .utf8).contains("\"schemaVersion\" : 2"))
    }

    @Test func recentProjectFileFormatIsReadable() throws {
        var project = record("Develon")
        project.premiereProjectRelativePath = "04_Project/Premiere Pro/x.prproj"
        let json = try #require(String(data: try JSONEncoder().encode(project), encoding: .utf8))
        for key in ["projectName", "projectType", "projectDate", "folderTemplateID", "destinationPath", "premiereProjectRelativePath", "createdAt", "\"hasPremiereProject\":true"] {
            #expect(json.contains(key))
        }
        #expect(try JSONDecoder().decode(RecentProject.self, from: Data(json.utf8)) == project)
    }
}

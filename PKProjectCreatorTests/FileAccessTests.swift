import Foundation
import Testing
@testable import PKProjectCreator

/// Stands in for macOS: which volumes are mounted, what bookmarks resolve to, and whether access is granted.
/// A bookmark here is just the item's path as UTF-8.
@MainActor
final class FakeSystem: ResourceAccess {
    var volumes: [MountedVolume] = []
    var existingPaths: Set<String> = []
    var deniedPaths: Set<String> = []
    /// Existing items that are folders rather than files.
    var directoryPaths: Set<String> = []
    /// Present, but the app may not read them (like a file with no read permission).
    var unreadablePaths: Set<String> = []
    var staleBookmarks = false
    var canMakeBookmarks = true
    private(set) var accessBalance = 0

    func mount(_ name: String, uuid: String?, at path: String) {
        volumes.append(MountedVolume(identity: VolumeIdentity(uuid: uuid, name: name), url: URL(filePath: path)))
    }

    func unmount(_ name: String) {
        volumes.removeAll { $0.identity.name == name }
    }

    func makeBookmark(for url: URL, readOnly: Bool) throws -> Data {
        guard canMakeBookmarks, volume(of: url) != nil else { throw CocoaError(.fileReadNoPermission) }
        return Data(url.plainPath.utf8)
    }

    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        let url = URL(filePath: String(decoding: data, as: UTF8.self))
        // Like macOS, a bookmark can't be resolved while its volume is away or after the item is deleted.
        guard volume(of: url) != nil, existingPaths.contains(url.plainPath) else { throw CocoaError(.fileNoSuchFile) }
        return (url, staleBookmarks)
    }

    func startAccessing(_ url: URL) -> Bool {
        guard !deniedPaths.contains(url.plainPath) else { return false }
        accessBalance += 1
        return true
    }

    func stopAccessing(_ url: URL) { accessBalance -= 1 }
    func isReachable(_ url: URL) -> Bool { existingPaths.contains(url.plainPath) }
    func isRegularFile(_ url: URL) -> Bool { existingPaths.contains(url.plainPath) && !directoryPaths.contains(url.plainPath) }
    func isReadable(_ url: URL) -> Bool { !unreadablePaths.contains(url.plainPath) }
    func volume(of url: URL) -> VolumeIdentity? { volumes.first { $0.contains(url) }?.identity }
    func mountedVolumes() -> [MountedVolume] { volumes }
}

@MainActor
struct FileAccessTests {
    private let destination = URL(filePath: "/Volumes/KIOXIA/PROJECT VIDEO/EVENT")
    private let template = URL(filePath: "/Volumes/WORK/Templates/Master.prproj")

    /// Both drives connected, both items present.
    private func makeSystem() -> FakeSystem {
        let system = FakeSystem()
        system.mount("Macintosh HD", uuid: "MAC", at: "/")
        system.mount("KIOXIA", uuid: "KIOXIA-UUID", at: "/Volumes/KIOXIA")
        system.mount("WORK", uuid: "WORK-UUID", at: "/Volumes/WORK")
        system.existingPaths = [destination.plainPath, template.plainPath]
        return system
    }

    private func state(_ service: FileAccessService, _ grant: FileAccessService.Grant, _ url: URL) -> ResourceState {
        service.check(bookmark: grant.bookmark, lastKnownURL: url, volume: grant.volume, readOnly: false).status.state
    }

    @Test func realBookmarkIsCreatedResolvedAndNoticedWhenTheFolderDisappears() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "PKAccess-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let service = FileAccessService()

        let grant = try service.authorize(folder, readOnly: false)
        let check = service.check(bookmark: grant.bookmark, lastKnownURL: folder, volume: grant.volume, readOnly: false)
        #expect(check.status.state == .authorized)
        #expect(check.status.hasBookmark)
        #expect(check.status.url?.lastPathComponent == folder.lastPathComponent)

        try FileManager.default.removeItem(at: folder)
        #expect(state(service, grant, folder) == .missing)
    }

    @Test func suggestedPathIsNeverReportedAsReady() {
        let system = makeSystem()
        let service = FileAccessService(system: system)

        // The drive is plugged in and the path exists, but the user never chose it.
        let connected = service.check(bookmark: nil, lastKnownURL: destination, volume: nil, readOnly: false).status
        #expect(connected.state == .permissionUnavailable)
        #expect(!connected.hasBookmark)
        #expect(connected.locationKind == "Suggested location")
        #expect(connected.volumeName == "KIOXIA")

        system.unmount("KIOXIA")
        #expect(service.check(bookmark: nil, lastKnownURL: destination, volume: nil, readOnly: false).status.state == .disconnected)
        #expect(service.check(bookmark: nil, lastKnownURL: nil, volume: nil, readOnly: true).status.state == .notSelected)
    }

    @Test func authorizedMissingDeniedAndDisconnected() throws {
        let system = makeSystem()
        let service = FileAccessService(system: system)
        let grant = try service.authorize(destination, readOnly: false)
        #expect(grant.volume == VolumeIdentity(uuid: "KIOXIA-UUID", name: "KIOXIA"))
        #expect(state(service, grant, destination) == .authorized)

        system.deniedPaths = [destination.plainPath]
        #expect(state(service, grant, destination) == .permissionUnavailable)
        system.deniedPaths = []

        system.existingPaths.remove(destination.plainPath)
        #expect(state(service, grant, destination) == .missing)
        system.existingPaths.insert(destination.plainPath)

        system.unmount("KIOXIA")
        #expect(state(service, grant, destination) == .disconnected)

        // Every access that was started was stopped again.
        #expect(system.accessBalance == 0)
    }

    @Test func staleBookmarkIsRenewedOrReported() throws {
        let system = makeSystem()
        let service = FileAccessService(system: system)
        let grant = try service.authorize(destination, readOnly: false)
        system.staleBookmarks = true

        let renewed = service.check(bookmark: grant.bookmark, lastKnownURL: destination, volume: grant.volume, readOnly: false)
        #expect(renewed.status.state == .authorized)
        #expect(renewed.renewedBookmark != nil)

        system.canMakeBookmarks = false
        #expect(state(service, grant, destination) == .stale)
    }

    @Test func driveIsRecognizedByIdentifierNotByName() throws {
        let system = makeSystem()
        let service = FileAccessService(system: system)
        let grant = try service.authorize(destination, readOnly: false)
        system.existingPaths.remove(destination.plainPath)

        // Renamed and mounted somewhere else: same identifier, so the drive is connected and the folder is missing.
        system.unmount("KIOXIA")
        system.mount("KIOXIA 2TB", uuid: "KIOXIA-UUID", at: "/Volumes/KIOXIA 2TB")
        #expect(state(service, grant, destination) == .missing)

        // A different drive that happens to carry the old name is not our drive.
        system.unmount("KIOXIA 2TB")
        system.mount("KIOXIA", uuid: "SOMETHING-ELSE", at: "/Volumes/KIOXIA")
        #expect(state(service, grant, destination) == .disconnected)
    }

    @Test func drivesAreTrackedIndependently() {
        let system = makeSystem()
        let app = AppState(directory: nil, fileAccess: FileAccessService(system: system))
        app.setDestination(destination)
        app.setPremiereTemplate(template)
        #expect(app.destination.state == .authorized)
        #expect(app.premiereTemplate.state == .authorized)
        #expect(app.drives.map(\.name) == ["KIOXIA", "WORK"])

        system.unmount("KIOXIA")
        app.refreshResources()
        #expect(app.destination.state == .disconnected)
        #expect(app.premiereTemplate.state == .authorized)

        system.mount("KIOXIA", uuid: "KIOXIA-UUID", at: "/Volumes/KIOXIA")
        system.unmount("WORK")
        app.refreshResources()
        #expect(app.destination.state == .authorized)
        #expect(app.premiereTemplate.state == .disconnected)
        app.draft.projectName = "Develon"
        #expect(app.creationStatus.text.contains("“WORK” is disconnected"))
    }

    @Test func replacingAndClearingResources() {
        let system = makeSystem()
        let app = AppState(directory: nil, fileAccess: FileAccessService(system: system))
        app.setDestination(destination)
        let firstBookmark = app.settings.destinationBookmarkData

        let other = URL(filePath: "/Volumes/WORK/Projects")
        system.existingPaths.insert(other.plainPath)
        app.setDestination(other)
        #expect(app.settings.destinationBookmarkData != firstBookmark)
        #expect(app.settings.destinationVolume?.uuid == "WORK-UUID")
        #expect(app.destination.url?.plainPath == other.plainPath)
        #expect(app.destinationFolder.hasPrefix("/Volumes/WORK/Projects/"))

        // Only .prproj files are accepted as the template.
        app.setPremiereTemplate(URL(filePath: "/Volumes/WORK/Templates/Notes.txt"))
        #expect(app.settings.premiereTemplateBookmarkData == nil)
        #expect(app.notice?.contains(".prproj") == true)

        app.setPremiereTemplate(template)
        #expect(app.premiereTemplate.state == .authorized)
        app.clearPremiereTemplate()
        #expect(app.premiereTemplate.state == .notSelected)
        #expect(app.settings.premiereTemplateURL == nil)
        #expect(app.settings.premiereTemplateBookmarkData == nil)
    }

    @Test func permissionFailureWhileChoosingIsReported() {
        let system = makeSystem()
        system.canMakeBookmarks = false
        let app = AppState(directory: nil, fileAccess: FileAccessService(system: system))
        app.setDestination(destination)
        #expect(app.settings.destinationBookmarkData == nil)
        #expect(app.destination.state == .permissionUnavailable)
        #expect(app.notice?.contains("couldn’t keep permission") == true)
    }
}

@MainActor
struct SettingsStoreTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "PKSettings-\(UUID().uuidString)")
    }

    @Test func defaultsAreSafe() {
        let settings = AppSettings()
        #expect(settings.defaultDestinationURL.plainPath == "/Volumes/KIOXIA/PROJECT VIDEO/EVENT")
        #expect(settings.premiereTemplateURL?.plainPath == "/Volumes/WORK/TÀI NGUYÊN /PREMIERE PRO/PROJECT MODEL/Project/Year - Month - Day - Name 2026.prproj")
        #expect(settings.destinationBookmarkData == nil)
        #expect(settings.premiereTemplateBookmarkData == nil)
        #expect(settings.useYearFolderFromProjectDate)
    }

    @Test func settingsAndPermissionsSurviveARestart() {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let system = FakeSystem()
        system.mount("KIOXIA", uuid: "KIOXIA-UUID", at: "/Volumes/KIOXIA")
        system.existingPaths = ["/Volumes/KIOXIA/Jobs"]

        let app = AppState(directory: directory, fileAccess: FileAccessService(system: system))
        app.setDestination(URL(filePath: "/Volumes/KIOXIA/Jobs"))
        app.settings.defaultProjectType = .tvc
        app.settings.useYearFolderFromProjectDate = false
        app.settings.maximumRecentProjects = 50
        app.clearPremiereTemplate()

        let relaunched = AppState(directory: directory, fileAccess: FileAccessService(system: system))
        #expect(relaunched.notice == nil)
        #expect(relaunched.settings == app.settings)
        #expect(relaunched.destination.state == .authorized)
        #expect(relaunched.destinationFolder == "/Volumes/KIOXIA/Jobs")
        #expect(relaunched.premiereTemplate.state == .notSelected)
        #expect(relaunched.draft.type == .tvc)
    }

    @Test func missingKeysUseDefaultsAndDamagedFileIsKept() throws {
        let store = SettingsStore(directory: makeDirectory())
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)

        try Data(#"{"schemaVersion": 1, "settings": {"defaultProjectType": "Golf Tournament", "maximumRecentProjects": 7}}"#.utf8).write(to: store.fileURL)
        let partial = store.load()
        #expect(partial.notice == nil)
        #expect(partial.settings.defaultProjectType == .golfTournament)
        #expect(partial.settings.maximumRecentProjects == 20)
        #expect(partial.settings.defaultDestinationURL == AppSettings.suggestedDestinationURL)

        try Data("not json".utf8).write(to: store.fileURL)
        let damaged = store.load()
        #expect(damaged.settings == AppSettings())
        #expect(damaged.notice != nil)
        #expect(FileManager.default.fileExists(atPath: store.damagedURL.path))
    }
}

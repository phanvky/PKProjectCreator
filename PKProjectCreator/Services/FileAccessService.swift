import AppKit
import UniformTypeIdentifiers

// Permission model: the app is sandboxed and only ever reaches the one folder and the one file the user picks
// in a system file dialog. Each pick is remembered as an app-scoped security-scoped bookmark. No Full Disk
// Access, and no access to whole drives.

struct MountedVolume {
    var identity: VolumeIdentity
    var url: URL

    /// True when `url` lives on this volume. The startup disk never claims paths under /Volumes, so an
    /// unplugged drive's path is not mistaken for a folder on the Mac.
    func contains(_ other: URL) -> Bool {
        let root = url.plainPath, path = other.plainPath
        if root == "/" { return !path.hasPrefix("/Volumes/") }
        return path == root || path.hasPrefix(root + "/")
    }
}

/// The macOS calls the service depends on, behind a protocol so tests can stand in for drives and permissions.
protocol ResourceAccess {
    func makeBookmark(for url: URL, readOnly: Bool) throws -> Data
    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool)
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
    func isReachable(_ url: URL) -> Bool
    func isRegularFile(_ url: URL) -> Bool
    func isReadable(_ url: URL) -> Bool
    func volume(of url: URL) -> VolumeIdentity?
    func mountedVolumes() -> [MountedVolume]
}

struct SystemResourceAccess: ResourceAccess {
    func makeBookmark(for url: URL, readOnly: Bool) throws -> Data {
        let options: URL.BookmarkCreationOptions = readOnly ? [.withSecurityScope, .securityScopeAllowOnlyReadAccess] : .withSecurityScope
        return try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &isStale)
        return (url, isStale)
    }

    func startAccessing(_ url: URL) -> Bool { url.startAccessingSecurityScopedResource() }
    func stopAccessing(_ url: URL) { url.stopAccessingSecurityScopedResource() }
    func isReachable(_ url: URL) -> Bool { (try? url.checkResourceIsReachable()) == true }
    func isRegularFile(_ url: URL) -> Bool { (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true }
    func isReadable(_ url: URL) -> Bool { FileManager.default.isReadableFile(atPath: url.plainPath) }

    func volume(of url: URL) -> VolumeIdentity? {
        guard let values = try? url.resourceValues(forKeys: [.volumeUUIDStringKey, .volumeNameKey]), let name = values.volumeName else { return nil }
        return VolumeIdentity(uuid: values.volumeUUIDString, name: name)
    }

    func mountedVolumes() -> [MountedVolume] {
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeUUIDStringKey, .volumeNameKey], options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in volume(of: url).map { MountedVolume(identity: $0, url: url) } }
    }
}

enum FileAccessError: LocalizedError {
    case cannotResolve
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .cannotResolve: "A saved location can’t be found. Check that its drive is connected, or choose it again."
        case .permissionDenied: "macOS didn’t allow access to a saved location. Choose it again to reauthorize it."
        }
    }
}

/// The one place that creates, resolves and uses security-scoped bookmarks.
struct FileAccessService {
    struct Grant {
        var bookmark: Data
        var volume: VolumeIdentity?
    }

    struct Check {
        var status: ResourceStatus
        /// Set when a stale bookmark was renewed and must be saved again.
        var renewedBookmark: Data?
        var volume: VolumeIdentity?
    }

    var system: ResourceAccess = SystemResourceAccess()

    /// Remembers a location the user just picked in a file dialog.
    func authorize(_ url: URL, readOnly: Bool) throws -> Grant {
        Grant(bookmark: try system.makeBookmark(for: url, readOnly: readOnly), volume: system.volume(of: url))
    }

    /// Resolves a bookmark, starts security-scoped access, runs `body`, and always stops access afterwards.
    func withAccess<T>(to bookmark: Data, _ body: (_ url: URL, _ isStale: Bool) throws -> T) throws -> T {
        guard let resolved = try? system.resolveBookmark(bookmark) else { throw FileAccessError.cannotResolve }
        guard system.startAccessing(resolved.url) else { throw FileAccessError.permissionDenied }
        defer { system.stopAccessing(resolved.url) }
        return try body(resolved.url, resolved.isStale)
    }

    /// The same for work that runs off the main actor: access stays open until `body` has finished.
    func withAccess<T: Sendable>(to bookmark: Data, _ body: (_ url: URL, _ isStale: Bool) async throws -> T) async throws -> T {
        guard let resolved = try? system.resolveBookmark(bookmark) else { throw FileAccessError.cannotResolve }
        guard system.startAccessing(resolved.url) else { throw FileAccessError.permissionDenied }
        defer { system.stopAccessing(resolved.url) }
        return try await body(resolved.url, resolved.isStale)
    }

    /// The current state of one resource. A path that merely looks right is never reported as ready:
    /// only a bookmark that resolves, grants access and points at something that exists is `.authorized`.
    /// With `fileExtension`, the resource must be a regular, readable file with that extension.
    func check(bookmark: Data?, lastKnownURL: URL?, volume: VolumeIdentity?, readOnly: Bool, fileExtension: String? = nil) -> Check {
        var status = ResourceStatus(
            url: lastKnownURL,
            volumeName: volume?.name ?? lastKnownURL?.plainPath.volumeName ?? "This Mac",
            hasBookmark: bookmark != nil
        )
        var isOnMountedVolume: Bool {
            system.mountedVolumes().contains { mounted in
                volume.map(mounted.identity.matches) ?? lastKnownURL.map(mounted.contains) ?? false
            }
        }

        guard let bookmark else {
            guard lastKnownURL != nil else { return Check(status: ResourceStatus()) }
            status.state = isOnMountedVolume ? .permissionUnavailable : .disconnected
            return Check(status: status, volume: volume)
        }
        do {
            return try withAccess(to: bookmark) { url, isStale in
                let currentVolume = system.volume(of: url) ?? volume
                status.url = url
                status.volumeName = currentVolume?.name ?? status.volumeName
                guard system.isReachable(url) else {
                    status.state = .missing
                    return Check(status: status, volume: currentVolume)
                }
                if let fileExtension {
                    guard url.pathExtension.lowercased() == fileExtension, system.isRegularFile(url) else {
                        status.state = .invalid
                        return Check(status: status, volume: currentVolume)
                    }
                    guard system.isReadable(url) else {
                        status.state = .permissionUnavailable
                        return Check(status: status, volume: currentVolume)
                    }
                }
                let renewed = isStale ? try? system.makeBookmark(for: url, readOnly: readOnly) : nil
                status.state = isStale && renewed == nil ? .stale : .authorized
                return Check(status: status, renewedBookmark: renewed, volume: currentVolume)
            }
        } catch FileAccessError.permissionDenied {
            status.state = .permissionUnavailable
        } catch {
            status.state = isOnMountedVolume ? .missing : .disconnected
        }
        return Check(status: status, volume: volume)
    }
}

/// The system file dialogs. Picking something here is what grants the app access to it.
enum OpenPanels {
    static func chooseFolder(message: String, startingAt url: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        return run(panel, message: message, startingAt: url)
    }

    static func chooseFile(message: String, fileExtension: String, startingAt url: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = UTType(filenameExtension: fileExtension).map { [$0] } ?? []
        return run(panel, message: message, startingAt: url)
    }

    private static func run(_ panel: NSOpenPanel, message: String, startingAt url: URL?) -> URL? {
        panel.allowsMultipleSelection = false
        panel.message = message
        panel.prompt = "Choose"
        panel.directoryURL = url
        return panel.runModal() == .OK ? panel.url : nil
    }
}

import Foundation

/// A volume remembered by its identifier, so a renamed drive or a changed mount path is still recognized.
/// The name is only used for display, and as a fallback for volumes that report no identifier.
struct VolumeIdentity: Codable, Equatable {
    var uuid: String?
    var name: String

    func matches(_ other: VolumeIdentity) -> Bool {
        if let uuid, let otherUUID = other.uuid { return uuid == otherUUID }
        return name == other.name
    }
}

/// Where one external resource (the destination folder or the Premiere template file) stands right now.
enum ResourceState: Equatable {
    /// Nothing chosen, e.g. after the template is cleared.
    case notSelected
    case authorized
    /// The volume is there, but the app has no usable permission (never chosen, or access was refused).
    case permissionUnavailable
    case disconnected
    /// The saved permission expired and couldn't be renewed.
    case stale
    /// The volume is there, but the folder or file is gone.
    case missing
    /// The file is there but isn't the right kind (wrong extension, or a folder).
    case invalid

    var label: String {
        switch self {
        case .notSelected: "Not selected"
        case .authorized: "Connected and authorized"
        case .permissionUnavailable: "Connected, permission needed"
        case .disconnected: "Disconnected"
        case .stale: "Permission expired"
        case .missing: "Not found"
        case .invalid: "Not a valid file"
        }
    }

    var kind: StatusKind {
        switch self {
        case .notSelected: .neutral
        case .authorized: .success
        case .permissionUnavailable, .stale: .warning
        case .disconnected, .missing, .invalid: .danger
        }
    }
}

struct ResourceStatus: Equatable {
    var state = ResourceState.notSelected
    /// The real location when authorized; otherwise the last known or suggested one.
    var url: URL?
    var volumeName = "No drive"
    /// False while the location is only a suggestion the user hasn't chosen in a file dialog.
    var hasBookmark = false

    var isReady: Bool { state == .authorized }

    /// "Suggested location" until the user has chosen it in a file dialog.
    var locationKind: String { hasBookmark ? "Authorized location" : "Suggested location" }

    var chooseTitle: String {
        guard hasBookmark else { return "Choose…" }
        return [.permissionUnavailable, .stale].contains(state) ? "Reauthorize…" : "Choose Another…"
    }

    /// What is wrong and what to do about it; nil when the resource is ready. `item` is e.g. "destination folder".
    func problem(item: String) -> String? {
        switch state {
        case .authorized: nil
        case .notSelected: "No \(item) is selected."
        case .permissionUnavailable:
            hasBookmark
                ? "PKProjectCreator no longer has permission for the \(item). Choose it again to reauthorize."
                : "The \(item) is only a suggested location. Choose it once to authorize it."
        case .disconnected: "“\(volumeName)” is disconnected, so the \(item) is unavailable."
        case .stale: "The saved permission for the \(item) has expired. Choose it again to reauthorize."
        case .missing: "The \(item) can’t be found on “\(volumeName)”."
        case .invalid: "The \(item) isn’t a valid file. Choose another one."
        }
    }

    /// The wording for the Premiere master template, e.g. "Ready to copy" or "WORK disconnected".
    var templateLabel: String {
        switch state {
        case .notSelected: "Not selected"
        case .authorized: "Ready to copy"
        case .permissionUnavailable: hasBookmark ? "Permission denied" : "Permission needed"
        case .disconnected: "\(volumeName) disconnected"
        case .stale: "Bookmark stale"
        case .missing: "Template missing"
        case .invalid: "Invalid template file"
        }
    }
}

/// One row of the drive status card.
struct DriveInfo: Identifiable {
    let name: String
    let role: String
    let state: ResourceState

    var id: String { role }
}

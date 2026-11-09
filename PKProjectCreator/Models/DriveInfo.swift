import Foundation

enum DriveStatus {
    /// Phase 01 never checks volumes, so every drive starts here.
    case unknown
    case connected
    case notConnected

    var label: String {
        switch self {
        case .unknown: "Not checked"
        case .connected: "Connected"
        case .notConnected: "Not connected"
        }
    }

    var kind: StatusKind {
        switch self {
        case .unknown: .neutral
        case .connected: .success
        case .notConnected: .danger
        }
    }
}

struct DriveInfo: Identifiable {
    let name: String
    let role: String
    var status: DriveStatus = .unknown

    var id: String { name }

    /// Projects live on KIOXIA, templates on WORK; the two are handled independently.
    static let known = [
        DriveInfo(name: "KIOXIA", role: "Projects"),
        DriveInfo(name: "WORK", role: "Templates"),
    ]
}

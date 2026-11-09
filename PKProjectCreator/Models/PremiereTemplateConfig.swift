import Foundation

enum PremiereTemplateStatus {
    case unknown
    case found
    case missing

    var label: String {
        switch self {
        case .unknown: "Not checked"
        case .found: "Template found"
        case .missing: "Template missing"
        }
    }

    var kind: StatusKind {
        switch self {
        case .unknown: .neutral
        case .found: .success
        case .missing: .warning
        }
    }
}

struct PremiereTemplateConfig {
    var sourcePath = "/Volumes/WORK/TÀI NGUYÊN /PREMIERE PRO/PROJECT MODEL/Project/Year - Month - Day - Name 2026.prproj"
    /// Folder inside the new project that receives the copy.
    var destinationFolder = ["04_Project", "Premiere Pro"]
    var copyOnCreate = true
    /// Phase 01 never touches the file, so this stays `.unknown` until the filesystem phase.
    var status: PremiereTemplateStatus = .unknown

    var sourceFilename: String { (sourcePath as NSString).lastPathComponent }
    var sourceFolder: String { (sourcePath as NSString).deletingLastPathComponent + "/" }
    var volumeName: String? { sourcePath.volumeName }
}

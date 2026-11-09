import Foundation

/// In-memory preferences for Phase 01; persistence (UserDefaults) arrives later.
struct AppSettings {
    var defaultProjectType: ProjectType = .event
    var recentProjectsLimit = 20
    var revealInFinderAfterCreate = true
    var openPremiereAfterCreate = false
    var clearNameAfterCreate = true
    /// Year folder is appended from the project date when enabled on New Project.
    var destinationBase = "/Volumes/KIOXIA/PROJECT VIDEO/EVENT"

    static let recentLimitOptions = [10, 20, 50, 100]
}

import Foundation

/// `recent-projects.json`: the projects this app created. It holds metadata only, never media, and is never
/// filled by scanning drives.
struct RecentProjectsStore {
    let file: JSONFileStore<[RecentProject]>
    var directory: URL { file.directory }
    var fileURL: URL { file.fileURL }
    var backupURL: URL { file.backupURL }
    var damagedURL: URL { file.damagedURL }

    init(directory: URL = .appSupportFolder) {
        file = JSONFileStore(directory: directory, baseName: "recent-projects", key: "projects")
    }

    func load() -> (projects: [RecentProject], notice: String?) {
        let (projects, notice) = file.load(label: "recent projects", fallback: "the list starts empty. Your projects on disk were not touched")
        return (projects ?? [], notice)
    }

    func save(_ projects: [RecentProject]) throws {
        try file.save(projects)
    }
}

import Foundation

/// `folder-templates.json`. Only AppState uses this; views never touch the disk.
struct FolderTemplateStore {
    struct LoadResult {
        var templates: [FolderTemplate]
        /// A problem the user should be told about; nil on a normal load.
        var notice: String?
    }

    let file: JSONFileStore<[FolderTemplate]>
    var directory: URL { file.directory }
    var fileURL: URL { file.fileURL }
    var backupURL: URL { file.backupURL }
    var damagedURL: URL { file.damagedURL }

    init(directory: URL = .appSupportFolder) {
        file = JSONFileStore(directory: directory, baseName: "folder-templates", key: "templates")
    }

    /// The built-in templates are written only when there is neither a file nor a backup (first launch).
    func load() -> LoadResult {
        var (templates, notice) = file.load(label: "folder templates", fallback: "the default templates were loaded")
        if templates == nil {
            templates = FolderTemplate.builtIn()
            do {
                try file.write(templates!)
            } catch {
                notice = (notice.map { $0 + " " } ?? "") + "Template changes can’t be saved: \(error.localizedDescription)"
            }
        }
        return LoadResult(templates: FolderTemplate.normalized(templates!), notice: notice)
    }

    func save(_ templates: [FolderTemplate]) throws {
        try file.save(templates)
    }
}

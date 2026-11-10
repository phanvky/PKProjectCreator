import Foundation

/// Reads and writes `folder-templates.json`. Only AppState uses this; views never touch the disk.
struct FolderTemplateStore {
    static let schemaVersion = 1

    struct LoadResult {
        var templates: [FolderTemplate]
        /// A problem the user should be told about; nil on a normal load.
        var notice: String?
    }

    private struct File: Codable {
        var schemaVersion: Int
        var templates: [FolderTemplate]
    }

    private struct NewerSchemaError: LocalizedError {
        var errorDescription: String? { "It was saved by a newer version of PKProjectCreator." }
    }

    let directory: URL
    var fileURL: URL { directory.appending(path: "folder-templates.json") }
    /// The last valid file, copied here before every save.
    var backupURL: URL { directory.appending(path: "folder-templates.backup.json") }
    /// An unreadable file is moved here instead of being deleted.
    var damagedURL: URL { directory.appending(path: "folder-templates.damaged.json") }

    /// Defaults to Application Support/PKProjectCreator (inside the app's sandbox container).
    init(directory: URL = .appSupportFolder) {
        self.directory = directory
    }

    /// Existing file → its templates. No file → the backup, or the built-in templates on first launch.
    /// Unreadable file → kept aside as `damagedURL`, then the backup or the built-in templates.
    func load() -> LoadResult {
        let files = FileManager.default
        var notice: String?
        if files.fileExists(atPath: fileURL.path) {
            do {
                return LoadResult(templates: try read(fileURL), notice: nil)
            } catch {
                try? files.removeItem(at: damagedURL)
                try? files.moveItem(at: fileURL, to: damagedURL)
                notice = "The folder templates file couldn’t be read. \(error.localizedDescription) It was kept as “\(damagedURL.lastPathComponent)”."
            }
        }

        let templates: [FolderTemplate]
        if let backup = try? read(backupURL) {
            templates = backup
            notice = (notice ?? "The folder templates file was missing.") + " Your templates were restored from the last backup."
        } else {
            templates = FolderTemplate.builtIn()
            if notice != nil { notice! += " No backup was available, so the default templates were loaded." }
        }
        do {
            try write(templates)
        } catch {
            notice = (notice.map { $0 + " " } ?? "") + "Template changes can’t be saved: \(error.localizedDescription)"
        }
        return LoadResult(templates: templates, notice: notice)
    }

    func save(_ templates: [FolderTemplate]) throws {
        let files = FileManager.default
        if (try? read(fileURL)) != nil {
            try? files.removeItem(at: backupURL)
            try files.copyItem(at: fileURL, to: backupURL)
        }
        try write(templates)
    }

    private func write(_ templates: [FolderTemplate]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(File(schemaVersion: Self.schemaVersion, templates: templates))
        try data.write(to: fileURL, options: .atomic)
    }

    private func read(_ url: URL) throws -> [FolderTemplate] {
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        guard file.schemaVersion <= Self.schemaVersion else { throw NewerSchemaError() }
        return FolderTemplate.normalized(file.templates)
    }
}

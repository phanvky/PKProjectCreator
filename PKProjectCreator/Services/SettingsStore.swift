import Foundation

extension URL {
    /// Application Support/PKProjectCreator (inside the app's sandbox container).
    static var appSupportFolder: URL { URL.applicationSupportDirectory.appending(path: "PKProjectCreator") }
}

/// Reads and writes `settings.json`. Only AppState uses this.
struct SettingsStore {
    static let schemaVersion = 1

    private struct File: Codable {
        var schemaVersion: Int
        var settings: AppSettings
    }

    let directory: URL
    var fileURL: URL { directory.appending(path: "settings.json") }
    /// An unreadable file is moved here instead of being deleted.
    var damagedURL: URL { directory.appending(path: "settings.damaged.json") }

    init(directory: URL = .appSupportFolder) {
        self.directory = directory
    }

    /// No file → defaults. Unreadable file → kept aside as `damagedURL`, defaults, and a notice for the user.
    func load() -> (settings: AppSettings, notice: String?) {
        let files = FileManager.default
        guard files.fileExists(atPath: fileURL.path) else { return (AppSettings(), nil) }
        if let file = try? JSONDecoder().decode(File.self, from: Data(contentsOf: fileURL)), file.schemaVersion <= Self.schemaVersion {
            return (file.settings, nil)
        }
        try? files.removeItem(at: damagedURL)
        try? files.moveItem(at: fileURL, to: damagedURL)
        return (AppSettings(), "The settings file couldn’t be read, so settings were reset. It was kept as “\(damagedURL.lastPathComponent)”. Choose your destination folder and Premiere template again.")
    }

    func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(File(schemaVersion: Self.schemaVersion, settings: settings)).write(to: fileURL, options: .atomic)
    }
}

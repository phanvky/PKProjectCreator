import Foundation

/// `settings.json`. Only AppState uses this.
struct SettingsStore {
    let file: JSONFileStore<AppSettings>
    var directory: URL { file.directory }
    var fileURL: URL { file.fileURL }
    var backupURL: URL { file.backupURL }
    var damagedURL: URL { file.damagedURL }

    init(directory: URL = .appSupportFolder) {
        file = JSONFileStore(directory: directory, baseName: "settings", key: "settings")
    }

    /// A damaged file is recovered from the backup; defaults are used only when there is no backup either.
    func load() -> (settings: AppSettings, notice: String?) {
        let (settings, notice) = file.load(
            label: "settings",
            fallback: "settings were reset. Choose your destination folder and Premiere template again"
        )
        return (settings ?? AppSettings(), notice)
    }

    func save(_ settings: AppSettings) throws {
        try file.save(settings)
    }
}

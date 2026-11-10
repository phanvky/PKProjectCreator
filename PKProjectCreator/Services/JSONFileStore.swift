import Foundation

extension URL {
    /// Application Support/PKProjectCreator (inside the app's sandbox container).
    static var appSupportFolder: URL { URL.applicationSupportDirectory.appending(path: "PKProjectCreator") }
}

/// One JSON file in Application Support: `{ "schemaVersion": n, "<key>": value }`, written atomically, with a
/// backup of the last valid file and recovery from a damaged one. Settings, templates and recent projects use it.
///
/// Migration strategy: a file at `schemaVersion` decodes directly. An older file is handed to `migrate` (add a
/// case there whenever a format changes, then bump `schemaVersion`). A newer file is treated like a damaged one:
/// kept aside, never overwritten, so an older app can't destroy data it doesn't understand.
struct JSONFileStore<Value: Codable> {
    let directory: URL
    /// e.g. "settings" → settings.json, settings.backup.json, settings.damaged.json
    let baseName: String
    /// The JSON key that holds the value, e.g. "settings".
    let key: String
    var schemaVersion = 1
    var migrate: ((_ fromVersion: Int, _ data: Data) throws -> Value)?

    var fileURL: URL { directory.appending(path: "\(baseName).json") }
    /// The last valid file, copied here before every save.
    var backupURL: URL { directory.appending(path: "\(baseName).backup.json") }
    /// An unreadable file is moved here instead of being deleted.
    var damagedURL: URL { directory.appending(path: "\(baseName).damaged.json") }

    /// Existing file → its value. No file → the backup, or nil (first launch). Unreadable file → kept aside as
    /// `damagedURL`, then the backup or nil, with a notice. `label` is plural, e.g. "folder templates".
    func load(label: String, fallback: String) -> (value: Value?, notice: String?) {
        let files = FileManager.default
        var notice: String?
        if files.fileExists(atPath: fileURL.path) {
            do {
                return (try read(fileURL), nil)
            } catch {
                try? files.removeItem(at: damagedURL)
                try? files.moveItem(at: fileURL, to: damagedURL)
                notice = "The \(label) file couldn’t be read. \(error.localizedDescription) It was kept as “\(damagedURL.lastPathComponent)”."
            }
        }
        if let backup = try? read(backupURL) {
            notice = (notice ?? "The \(label) file was missing.") + " Your \(label) were restored from the last backup."
            do {
                try write(backup)
            } catch {
                notice! += " They can’t be saved: \(error.localizedDescription)"
            }
            return (backup, notice)
        }
        if notice != nil { notice! += " No backup was available, so \(fallback)." }
        return (nil, notice)
    }

    func save(_ value: Value) throws {
        let files = FileManager.default
        if (try? read(fileURL)) != nil {
            try? files.removeItem(at: backupURL)
            try files.copyItem(at: fileURL, to: backupURL)
        }
        try write(value)
    }

    func write(_ value: Value) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.userInfo[Self.keyInfo] = key
        try encoder.encode(Envelope(schemaVersion: schemaVersion, value: value)).write(to: fileURL, options: .atomic)
    }

    private func read(_ url: URL) throws -> Value {
        let data = try Data(contentsOf: url)
        let version = try JSONDecoder().decode(Header.self, from: data).schemaVersion
        if version > schemaVersion { throw NewerSchemaError() }
        if version < schemaVersion, let migrate { return try migrate(version, data) }
        let decoder = JSONDecoder()
        decoder.userInfo[Self.keyInfo] = key
        return try decoder.decode(Envelope.self, from: data).value
    }

    // MARK: File format

    private static var keyInfo: CodingUserInfoKey { CodingUserInfoKey(rawValue: "PKProjectCreator.valueKey")! }

    private struct Header: Decodable {
        var schemaVersion: Int
    }

    private struct NewerSchemaError: LocalizedError {
        var errorDescription: String? { "It was saved by a newer version of PKProjectCreator." }
    }

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    private struct Envelope: Codable {
        var schemaVersion: Int
        var value: Value

        init(schemaVersion: Int, value: Value) {
            self.schemaVersion = schemaVersion
            self.value = value
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: AnyKey.self)
            schemaVersion = try values.decode(Int.self, forKey: AnyKey("schemaVersion"))
            value = try values.decode(Value.self, forKey: AnyKey(decoder.userInfo[JSONFileStore.keyInfo] as? String ?? "value"))
        }

        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: AnyKey.self)
            try values.encode(schemaVersion, forKey: AnyKey("schemaVersion"))
            try values.encode(value, forKey: AnyKey(encoder.userInfo[JSONFileStore.keyInfo] as? String ?? "value"))
        }
    }
}

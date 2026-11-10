import Foundation

nonisolated extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var nilIfEmpty: String? { isEmpty ? nil : self }

    /// "KIOXIA" for "/Volumes/KIOXIA/…", nil for paths on the startup disk.
    var volumeName: String? {
        let parts = split(separator: "/")
        guard parts.count > 1, parts[0] == "Volumes" else { return nil }
        return String(parts[1])
    }
}

nonisolated extension URL {
    /// File path as typed, without percent-encoding or a trailing slash.
    var plainPath: String {
        let path = path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}

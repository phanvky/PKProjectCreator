import Foundation

nonisolated extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// "KIOXIA" for "/Volumes/KIOXIA/…", nil for paths on the startup disk.
    var volumeName: String? {
        let parts = split(separator: "/")
        guard parts.count > 1, parts[0] == "Volumes" else { return nil }
        return String(parts[1])
    }
}

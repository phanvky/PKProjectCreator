import Foundation

nonisolated enum ProjectNameIssue: Equatable {
    case empty
    case forbiddenCharacter
    case controlCharacter
    case tooLong

    var message: String {
        switch self {
        case .empty: "Enter a project name to continue."
        case .forbiddenCharacter: "Names can’t contain “/” or “:” on macOS."
        case .controlCharacter: "Names can’t contain line breaks or control characters."
        case .tooLong: "This name is too long for a macOS file name (255 bytes max)."
        }
    }
}

/// The PHANKY FILM naming rule: `yyyy - MM - dd` + Project Type + Project Name.
nonisolated enum ProjectNaming {
    static let datePattern = "yyyy - MM - dd"
    static let namePlaceholder = "[Project Name]"

    /// Gregorian components in the current time zone, so digits never follow the user's locale or calendar.
    private static func components(of date: Date) -> DateComponents {
        Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
    }

    static func datePrefix(for date: Date) -> String {
        let parts = components(of: date)
        return String(format: "%04d - %02d - %02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func year(for date: Date) -> String {
        String(format: "%04d", components(of: date).year ?? 0)
    }

    /// The user's text is used exactly as typed; it is validated, never rewritten.
    static func generatedName(date: Date, type: ProjectType, projectName: String) -> String {
        "\(datePrefix(for: date)) \(type.rawValue) \(projectName)"
    }

    /// Same as `generatedName`, with a placeholder while the name is still empty.
    static func displayName(date: Date, type: ProjectType, projectName: String) -> String {
        generatedName(date: date, type: type, projectName: projectName.isBlank ? namePlaceholder : projectName)
    }

    static func destinationFolder(base: String, date: Date, useYearFolder: Bool) -> String {
        useYearFolder ? "\(base)/\(year(for: date))" : base
    }

    /// macOS filename rules for the user part, plus the length limit of the final `.prproj` name.
    static func issue(forProjectName name: String, generatedName: String) -> ProjectNameIssue? {
        if name.isBlank { return .empty }
        if name.contains(where: { $0 == "/" || $0 == ":" }) { return .forbiddenCharacter }
        if name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) { return .controlCharacter }
        if "\(generatedName).prproj".utf8.count > 255 { return .tooLong }
        return nil
    }
}

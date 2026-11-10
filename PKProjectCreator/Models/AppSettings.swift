import Foundation

/// Preferences saved in `settings.json`. Nothing confidential is stored: the bookmarks are macOS permission
/// tokens that only this app can use.
struct AppSettings: Codable, Equatable {
    /// Shown before the user has authorized anything. These are suggestions, not permissions.
    static let suggestedDestinationURL = URL(filePath: "/Volumes/KIOXIA/PROJECT VIDEO/EVENT", directoryHint: .isDirectory)
    static let suggestedPremiereTemplateURL = URL(
        filePath: "/Volumes/WORK/TÀI NGUYÊN /PREMIERE PRO/PROJECT MODEL/Project/Year - Month - Day - Name 2026.prproj",
        directoryHint: .notDirectory
    )
    static let suggestedResolveTemplateURL = URL(
        filePath: "/Volumes/WORK/TÀI NGUYÊN /DAVINCI RESOLVE/PROJECT MODEL/Project Template.drp",
        directoryHint: .notDirectory
    )
    static let recentLimitOptions = [10, 20, 50, 100]

    var defaultProjectType: ProjectType = .event

    /// The suggested folder until the user chooses one; afterwards the last place the bookmark resolved to.
    var defaultDestinationURL = suggestedDestinationURL
    /// Present only once the user has chosen the folder in a file dialog.
    var destinationBookmarkData: Data?
    var destinationVolume: VolumeIdentity?
    /// Appends the year of the project date to the destination, e.g. `…/EVENT/2026`.
    var useYearFolderFromProjectDate = true

    /// nil after the user clears the template.
    var premiereTemplateURL: URL? = suggestedPremiereTemplateURL
    var premiereTemplateBookmarkData: Data?
    var premiereTemplateVolume: VolumeIdentity?
    var createPremiereProjectByDefault = true

    /// The DaVinci Resolve master project (.drp); nil after the user clears it.
    var resolveTemplateURL: URL? = suggestedResolveTemplateURL
    var resolveTemplateBookmarkData: Data?
    var resolveTemplateVolume: VolumeIdentity?
    var createResolveProjectByDefault = false

    var openFinderAfterCreation = true
    var openPremiereAfterCreation = false
    var clearProjectNameAfterCreation = true
    var maximumRecentProjects = 20

    init() {}

    /// Missing or unreadable values keep their safe default, so older and hand-edited files still load.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? values.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        defaultProjectType = read(.defaultProjectType, defaultProjectType)
        defaultDestinationURL = read(.defaultDestinationURL, defaultDestinationURL)
        destinationBookmarkData = try? values.decodeIfPresent(Data.self, forKey: .destinationBookmarkData)
        destinationVolume = try? values.decodeIfPresent(VolumeIdentity.self, forKey: .destinationVolume)
        useYearFolderFromProjectDate = read(.useYearFolderFromProjectDate, useYearFolderFromProjectDate)
        // A saved file with no template URL means the user cleared it.
        premiereTemplateURL = try? values.decodeIfPresent(URL.self, forKey: .premiereTemplateURL)
        premiereTemplateBookmarkData = try? values.decodeIfPresent(Data.self, forKey: .premiereTemplateBookmarkData)
        premiereTemplateVolume = try? values.decodeIfPresent(VolumeIdentity.self, forKey: .premiereTemplateVolume)
        createPremiereProjectByDefault = read(.createPremiereProjectByDefault, createPremiereProjectByDefault)
        // Files saved before DaVinci Resolve support have no Resolve keys: keep the suggested template there.
        if values.contains(.createResolveProjectByDefault) {
            resolveTemplateURL = try? values.decodeIfPresent(URL.self, forKey: .resolveTemplateURL)
        }
        resolveTemplateBookmarkData = try? values.decodeIfPresent(Data.self, forKey: .resolveTemplateBookmarkData)
        resolveTemplateVolume = try? values.decodeIfPresent(VolumeIdentity.self, forKey: .resolveTemplateVolume)
        createResolveProjectByDefault = read(.createResolveProjectByDefault, createResolveProjectByDefault)
        openFinderAfterCreation = read(.openFinderAfterCreation, openFinderAfterCreation)
        openPremiereAfterCreation = read(.openPremiereAfterCreation, openPremiereAfterCreation)
        clearProjectNameAfterCreation = read(.clearProjectNameAfterCreation, clearProjectNameAfterCreation)
        let limit = read(.maximumRecentProjects, maximumRecentProjects)
        maximumRecentProjects = Self.recentLimitOptions.contains(limit) ? limit : 20
    }
}

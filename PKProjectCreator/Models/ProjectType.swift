import Foundation

/// A project type, e.g. "Event". The list is the user's own (`AppSettings.projectTypes`); it is saved as plain
/// text, so files written when the list was fixed load unchanged.
nonisolated struct ProjectType: RawRepresentable, Identifiable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(_ name: String) { rawValue = name }

    var id: String { rawValue }

    static let event = ProjectType("Event")
    static let psc = ProjectType("PSC")
    static let psh = ProjectType("PSH")
    static let tour = ProjectType("Tour")
    static let golfTournament = ProjectType("Golf Tournament")
    static let tvc = ProjectType("TVC")
    static let reels = ProjectType("Reels")

    /// The PHANKY FILM list the app starts with.
    static let builtIn: [ProjectType] = [.event, .psc, .psh, .tour, .golfTournament, .tvc, .reels]
}

import Foundation

/// The fixed list of PHANKY FILM project types, in display order.
nonisolated enum ProjectType: String, CaseIterable, Identifiable, Hashable {
    case event = "Event"
    case psc = "PSC"
    case psh = "PSH"
    case tour = "Tour"
    case golfTournament = "Golf Tournament"
    case tvc = "TVC"
    case reels = "Reels"

    var id: String { rawValue }
}

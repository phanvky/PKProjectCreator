import Foundation

/// Where the Premiere and DaVinci Resolve copies go inside a new project. Saved in `settings.json`; the source
/// files themselves are in `AppSettings` too.
struct PremiereTemplateConfig: Codable, Equatable {
    /// Folder inside the new project that receives the copy.
    var destinationFolder = ["07_Project", "Premiere Pro"]
    /// Folder inside the new project that receives the DaVinci Resolve `.drp` copy.
    var resolveFolder = ["07_Project", "DaVinci Resolve"]
}

import Foundation

/// Where the Premiere and DaVinci Resolve copies go inside a new project. The source files themselves live in `AppSettings`.
struct PremiereTemplateConfig {
    /// Folder inside the new project that receives the copy.
    var destinationFolder = ["04_Project", "Premiere Pro"]
    /// Folder inside the new project that receives the DaVinci Resolve `.drp` copy.
    var resolveFolder = ["04_Project", "DaVinci Resolve"]
}

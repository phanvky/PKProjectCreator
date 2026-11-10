import Foundation

enum AppScreen: Hashable, CaseIterable {
    case newProject
    case recentProjects
    case folderTemplates
    case premiereTemplate
    case resolveTemplate
    case settings

    var title: String {
        switch self {
        case .newProject: "New Project"
        case .recentProjects: "Recent Projects"
        case .folderTemplates: "Folder Templates"
        case .premiereTemplate: "Premiere Template"
        case .resolveTemplate: "Resolve Template"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .newProject: "folder.badge.plus"
        case .recentProjects: "clock"
        case .folderTemplates: "list.bullet.indent"
        case .premiereTemplate: "doc.text"
        case .resolveTemplate: "doc.text"
        case .settings: "slider.horizontal.3"
        }
    }
}

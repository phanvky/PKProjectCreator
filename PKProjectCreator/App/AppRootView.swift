import SwiftUI

struct AppRootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            switch app.screen {
            case .newProject: NewProjectView()
            case .recentProjects: RecentProjectsView()
            case .folderTemplates: FolderTemplatesView()
            case .premiereTemplate: PremiereTemplateView()
            case .settings: SettingsView()
            }
        }
    }
}

#Preview {
    AppRootView()
        .environment(AppState())
        .frame(width: 1440, height: 960)
        .preferredColorScheme(.dark)
}

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
        .alert(
            "Folder Templates",
            isPresented: Binding(get: { app.storageNotice != nil }, set: { if !$0 { app.storageNotice = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(app.storageNotice ?? "")
        }
    }
}

#Preview {
    AppRootView()
        .environment(AppState(templateStore: nil))
        .frame(width: 1440, height: 960)
        .preferredColorScheme(.dark)
}

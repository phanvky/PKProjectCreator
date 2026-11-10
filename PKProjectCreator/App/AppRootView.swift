import Combine
import SwiftUI

struct AppRootView: View {
    @Environment(AppState.self) private var app

    private static let resourceChanges = Publishers.MergeMany(
        [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification]
            .map { NSWorkspace.shared.notificationCenter.publisher(for: $0) }
            + [NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)]
    )

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
        // Either drive can come or go at any time; each change re-checks both resources.
        .onReceive(Self.resourceChanges) { _ in
            app.refreshResources()
            // A renamed or just-mounted volume can be announced a moment before its files are reachable.
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                app.refreshResources()
            }
        }
        .alert(
            "PKProjectCreator",
            isPresented: Binding(get: { app.notice != nil }, set: { if !$0 { app.notice = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(app.notice ?? "")
        }
    }
}

#Preview {
    AppRootView()
        .environment(AppState(directory: nil))
        .frame(width: 1440, height: 960)
        .preferredColorScheme(.dark)
}

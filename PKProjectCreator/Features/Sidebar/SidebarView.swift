import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        List(selection: listSelection) {
            Section("Projects") {
                SidebarRow(screen: .newProject, shortcut: "⌘N")
                    .tag(AppScreen.newProject)
                SidebarRow(screen: .recentProjects)
                    .badge(app.recentProjects.count)
                    .tag(AppScreen.recentProjects)
            }
            Section("Templates") {
                SidebarRow(screen: .folderTemplates)
                    .tag(AppScreen.folderTemplates)
                SidebarRow(screen: .premiereTemplate) {
                    StatusDot(kind: app.premiere.status.kind)
                }
                .tag(AppScreen.premiereTemplate)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                DriveStatusCard(drives: app.drives)
                settingsButton
            }
            .padding(10)
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
    }

    /// Settings sits outside the List, so the List shows no selection while it is open.
    private var listSelection: Binding<AppScreen?> {
        Binding(
            get: { app.screen == .settings ? nil : app.screen },
            set: { if let screen = $0 { app.screen = screen } }
        )
    }

    private var settingsButton: some View {
        let isSelected = app.screen == .settings
        return Button {
            app.screen = .settings
        } label: {
            SidebarRow(screen: .settings, shortcut: "⌘,")
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Color.accentColor : Color.clear, in: .rect(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SidebarRow<Accessory: View>: View {
    let screen: AppScreen
    var shortcut: String?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        Label {
            HStack {
                Text(screen.title)
                Spacer(minLength: 4)
                accessory
                if let shortcut {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        } icon: {
            Image(systemName: screen.systemImage)
        }
    }
}

extension SidebarRow where Accessory == EmptyView {
    init(screen: AppScreen, shortcut: String? = nil) {
        self.init(screen: screen, shortcut: shortcut) { EmptyView() }
    }
}

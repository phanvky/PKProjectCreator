import SwiftUI

@main
struct PKProjectCreatorApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        Window("PKProjectCreator", id: "main") {
            AppRootView()
                .environment(appState)
                .frame(minWidth: 1120, minHeight: 760)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1440, height: 960)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") { appState.screen = .newProject }
                    .keyboardShortcut("n")
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { appState.screen = .settings }
                    .keyboardShortcut(",")
            }
        }
    }
}

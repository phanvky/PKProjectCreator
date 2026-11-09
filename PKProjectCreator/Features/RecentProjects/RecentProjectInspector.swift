import SwiftUI

struct RecentProjectInspector: View {
    let project: RecentProject?
    let onNewProjectLikeThis: (RecentProject) -> Void
    let onRemove: (RecentProject) -> Void

    var body: some View {
        if let project {
            ScrollView {
                VStack(spacing: 14) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.folderTint)
                        .accessibilityHidden(true)
                    Text(project.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                    TagLabel(text: project.type.rawValue)

                    FormCard {
                        VStack(spacing: 0) {
                            InfoRow(label: "Date", value: project.date.formatted(.dateTime.weekday().day().month(.abbreviated).year()), labelWidth: 70)
                            InfoRow(label: "Template", value: project.templateName, labelWidth: 70)
                            InfoRow(label: "Folders", value: "\(project.directoryCount) directories (root + \(project.directoryCount - 1))", labelWidth: 70)
                            InfoRow(label: "Premiere", value: project.premiere == .linked ? project.premiereFilename : "Missing", labelWidth: 70)
                            InfoRow(label: "Location", value: project.fullPath, monospaced: true, labelWidth: 70)
                        }
                        .padding(.vertical, 4)
                    }

                    VStack(spacing: 8) {
                        Button {} label: { Text("Reveal in Finder").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                            .disabled(true)
                        Button {} label: { Text("Open in Premiere Pro").frame(maxWidth: .infinity) }
                            .disabled(true)
                        Button { onNewProjectLikeThis(project) } label: { Text("New Project Like This…").frame(maxWidth: .infinity) }
                    }
                    .controlSize(.large)
                    .help("Finder and Premiere actions arrive in a later phase.")

                    Button("Remove from List", role: .destructive) { onRemove(project) }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)

                    Text("Sample project — Finder and Premiere actions arrive in a later phase.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
        } else {
            ContentUnavailableView("No Selection", systemImage: "folder", description: Text("Select a project to see its details."))
        }
    }
}

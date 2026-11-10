import SwiftUI

struct RecentProjectInspector: View {
    @Environment(AppState.self) private var app
    let project: RecentProject?
    @State private var isConfirmingRemove = false

    var body: some View {
        if let project {
            details(project, status: app.recentStatuses[project.id] ?? RecentProjectStatus())
        } else {
            ContentUnavailableView("No Selection", systemImage: "folder", description: Text("Select a project to see its details."))
        }
    }

    private func details(_ project: RecentProject, status: RecentProjectStatus) -> some View {
        let premiere = status.premiereLabel(for: project)

        return ScrollView {
            VStack(spacing: 14) {
                Image(systemName: status.location == .missing ? "folder.badge.questionmark" : "folder.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(status.isAvailable ? Theme.folderTint : status.kind.color)
                    .accessibilityHidden(true)
                Text(project.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    TagLabel(text: project.projectType.rawValue)
                    StatusLabel(text: status.label, kind: status.kind)
                }

                if let problem = status.problem {
                    VStack(alignment: .leading, spacing: 8) {
                        ValidationMessage(text: problem, kind: status.kind)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Retry") { app.refreshRecentProjects() }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(status.kind.color.opacity(0.1), in: .rect(cornerRadius: Theme.cornerRadius))
                }

                FormCard {
                    VStack(spacing: 0) {
                        InfoRow(label: "Date", value: project.projectDate.formatted(.dateTime.weekday().day().month(.abbreviated).year()), labelWidth: 70)
                        InfoRow(label: "Created", value: project.createdAt.formatted(date: .abbreviated, time: .shortened), labelWidth: 70)
                        InfoRow(label: "Template", value: project.folderTemplateName, labelWidth: 70)
                        InfoRow(label: "Folders", value: "\(project.directoryCount) directories (root + \(project.directoryCount - 1))", labelWidth: 70)
                        InfoRow(label: "Premiere", value: project.premiereFilename.map { "\($0) · \(premiere.text)" } ?? premiere.text, labelWidth: 70)
                        InfoRow(label: "Location", value: app.path(of: project), monospaced: true, labelWidth: 70, singleLine: true)
                    }
                    .padding(.vertical, 4)
                }

                VStack(spacing: 8) {
                    Button { app.revealInFinder(project) } label: { Text("Reveal in Finder").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!status.isAvailable)
                    if project.hasPremiereProject {
                        Button { app.openInPremiere(project) } label: { Text("Open in Premiere Pro").frame(maxWidth: .infinity) }
                            .disabled(status.premiereFileExists != true)
                    }
                    Button { app.beginUpdate(project) } label: {
                        HStack {
                            if app.projectUpdateTask != nil { ProgressView().controlSize(.small) }
                            Text("Update Project…")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!app.canUpdate(project) || app.projectUpdateTask != nil)
                    .help(app.canUpdate(project)
                        ? "Add folders, delete empty folders, or add a missing Premiere / DaVinci Resolve project."
                        : "The project folder must be reachable to update it.")
                    Button { app.copyPath(of: project) } label: { Text("Copy Path").frame(maxWidth: .infinity) }
                    Button { app.startProject(like: project) } label: { Text("New Project Like This…").frame(maxWidth: .infinity) }
                        .help("Same project type and folder template, today’s date, empty name. Nothing is copied.")
                }
                .controlSize(.large)

                Button("Remove from List", role: .destructive) { isConfirmingRemove = true }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
            }
            .padding(16)
        }
        .confirmationDialog("Remove “\(project.name)” from Recent Projects?", isPresented: $isConfirmingRemove) {
            Button("Remove from List", role: .destructive) { app.removeRecentProject(project.id) }
        } message: {
            Text("Only the entry in this list is removed. The project folder and its Premiere project stay on disk.")
        }
    }
}

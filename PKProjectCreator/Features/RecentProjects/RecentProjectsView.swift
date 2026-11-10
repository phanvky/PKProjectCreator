import SwiftUI

/// Projects this app created (from `recent-projects.json`). Drives are never scanned.
struct RecentProjectsView: View {
    @Environment(AppState.self) private var app
    @State private var searchText = ""
    @State private var typeFilter: ProjectType?
    @State private var selection: RecentProject.ID?
    @State private var sortOrder = [KeyPathComparator(\RecentProject.projectDate, order: .reverse)]

    private var visibleProjects: [RecentProject] {
        RecentProject.matching(app.recentProjects, search: searchText, type: typeFilter).sorted(using: sortOrder)
    }

    var body: some View {
        let projects = visibleProjects

        Table(projects, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { project in
                Label {
                    Text(project.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(project.name)
                } icon: {
                    Image(systemName: "folder.fill").foregroundStyle(Theme.folderTint)
                }
            }
            .width(min: 200, ideal: 300)
            TableColumn("Type", value: \.projectType.rawValue) { project in
                TagLabel(text: project.projectType.rawValue)
            }
            .width(min: 70, ideal: 120)
            TableColumn("Date", value: \.projectDate) { project in
                Text(project.projectDate, format: .dateTime.day().month(.abbreviated).year())
            }
            .width(min: 90, ideal: 110)
            TableColumn("Location") { project in
                let status = app.recentStatuses[project.id] ?? RecentProjectStatus()
                if status.isAvailable {
                    Text(project.locationSummary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(app.path(of: project))
                } else {
                    StatusLabel(text: status.label, kind: status.kind)
                        .lineLimit(1)
                        .help(app.path(of: project))
                }
            }
            .width(min: 120, ideal: 220)
            TableColumn("Premiere") { project in
                let premiere = (app.recentStatuses[project.id] ?? RecentProjectStatus()).premiereLabel(for: project)
                StatusLabel(text: premiere.text, kind: premiere.kind)
            }
            .width(min: 80, ideal: 100)
        }
        .alternatingRowBackgrounds(.disabled)
        .overlay {
            if projects.isEmpty {
                if app.recentProjects.isEmpty {
                    ContentUnavailableView(
                        "No Recent Projects",
                        systemImage: "clock",
                        description: Text("Projects you create with PKProjectCreator appear here. Your drives are not scanned.")
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text("\(projects.count) of \(app.recentProjects.count) projects · keeps the newest \(app.settings.maximumRecentProjects) (change in Settings)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
        }
        .inspector(isPresented: .constant(true)) {
            RecentProjectInspector(project: app.recentProjects.first { $0.id == selection })
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search project names")
        .toolbar {
            ToolbarItem {
                Picker("Project Type", selection: $typeFilter) {
                    Text("All Types").tag(ProjectType?.none)
                    Divider()
                    ForEach(ProjectType.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationTitle("Recent Projects")
        .navigationSubtitle("\(app.recentProjects.count) \(app.recentProjects.count == 1 ? "project" : "projects") created with PKProjectCreator")
        .onAppear {
            app.refreshRecentProjects()
            if selection == nil { selection = projects.first?.id }
        }
    }
}

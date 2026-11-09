import SwiftUI

struct RecentProjectsView: View {
    @Environment(AppState.self) private var app
    @State private var searchText = ""
    @State private var typeFilter: ProjectType?
    @State private var selection: RecentProject.ID?
    @State private var sortOrder = [KeyPathComparator(\RecentProject.date, order: .reverse)]

    private var visibleProjects: [RecentProject] {
        app.recentProjects
            .filter { project in
                (typeFilter == nil || project.type == typeFilter)
                    && (searchText.isEmpty || project.name.localizedStandardContains(searchText))
            }
            .sorted(using: sortOrder)
    }

    var body: some View {
        let projects = visibleProjects

        Table(projects, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { project in
                Label {
                    Text(project.name).lineLimit(1)
                } icon: {
                    Image(systemName: "folder.fill").foregroundStyle(Theme.folderTint)
                }
            }
            .width(min: 200, ideal: 300)
            TableColumn("Type", value: \.type.rawValue) { project in
                TagLabel(text: project.type.rawValue)
            }
            .width(min: 70, ideal: 120)
            TableColumn("Date", value: \.date) { project in
                Text(project.date, format: .dateTime.day().month(.abbreviated).year())
            }
            .width(min: 90, ideal: 110)
            TableColumn("Location") { project in
                Text(project.locationSummary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: 120, ideal: 220)
            TableColumn("Premiere", value: \.premiere.rawValue) { project in
                StatusLabel(text: project.premiere.rawValue, kind: project.premiere == .linked ? .success : .warning)
            }
            .width(min: 80, ideal: 90)
        }
        .alternatingRowBackgrounds(.disabled)
        .overlay {
            if projects.isEmpty {
                if app.recentProjects.isEmpty {
                    ContentUnavailableView("No Recent Projects", systemImage: "clock", description: Text("Projects you create will appear here."))
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ValidationMessage(text: "Sample data for design review — these are not your real projects. Nothing on disk is scanned yet.", kind: .neutral)
                .font(.caption)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)
                .overlay(alignment: .bottom) { Divider() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text("\(projects.count) of \(app.recentProjects.count) sample projects")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
        }
        .inspector(isPresented: .constant(true)) {
            RecentProjectInspector(
                project: app.recentProjects.first { $0.id == selection },
                onNewProjectLikeThis: { app.startProject(like: $0) },
                onRemove: { project in
                    app.recentProjects.removeAll { $0.id == project.id }
                    selection = nil
                }
            )
            .inspectorColumnWidth(min: 260, ideal: 300, max: 380)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
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
        .navigationSubtitle("\(app.recentProjects.count) sample projects")
        .onAppear {
            if selection == nil { selection = projects.first?.id }
        }
    }
}

import SwiftUI

struct SettingsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case locations = "Locations"
        case naming = "Naming"

        var id: Self { self }
    }

    @Environment(AppState.self) private var app
    @State private var tab = Tab.general

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                Picker("Settings Section", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .frame(maxWidth: .infinity)

                switch tab {
                case .general: general
                case .locations: locations
                case .naming: naming
                }

                Text("Settings are saved automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }
            .frame(maxWidth: 680)
            .padding(Theme.pagePadding)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Settings")
        .navigationSubtitle("Defaults for new projects")
    }

    // MARK: General

    @ViewBuilder
    private var general: some View {
        @Bindable var app = app

        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("New Projects")
            FormCard {
                FormRow("Default project type") {
                    Picker("Default project type", selection: $app.settings.defaultProjectType) {
                        ForEach(ProjectType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .buttonSizing(.flexible)
                    .frame(width: 220)
                }
                FormRow("Recent projects to keep") {
                    Picker("Recent projects to keep", selection: $app.settings.maximumRecentProjects) {
                        ForEach(AppSettings.recentLimitOptions, id: \.self) { Text("\($0) projects").tag($0) }
                    }
                    .labelsHidden()
                    .buttonSizing(.flexible)
                    .frame(width: 220)
                }
            }
            Text("When the list is full, the oldest entries leave the list. Projects on disk are never deleted.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("After Creating a Project")
            FormCard {
                ToggleRow("Reveal the new folder in Finder", isOn: $app.settings.openFinderAfterCreation)
                ToggleRow("Open the Premiere project", isOn: $app.settings.openPremiereAfterCreation)
                ToggleRow("Clear the project name for the next project", isOn: $app.settings.clearProjectNameAfterCreation)
            }
        }
    }

    // MARK: Locations

    @ViewBuilder
    private var locations: some View {
        let yearSuffix = app.settings.useYearFolderFromProjectDate ? "/{yyyy}" : ""

        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Locations")
            FormCard {
                locationRow(
                    "Default project destination", item: "destination folder", resource: app.destination,
                    path: (app.destination.url?.plainPath ?? "") + yearSuffix
                ) { app.chooseDestination() }
                locationRow(
                    "Premiere Pro master template", item: "Premiere template", resource: app.premiereTemplate,
                    path: app.premiereTemplate.url?.plainPath ?? "No template selected"
                ) { app.choosePremiereTemplate() }
            }
            Text("PKProjectCreator can only use a folder or file after you choose it here. A suggested location is just the expected path.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("External Volumes")
            FormCard {
                ForEach(app.drives) { drive in
                    HStack(spacing: 10) {
                        Image(systemName: "externaldrive").foregroundStyle(.secondary)
                        Text(drive.name).bold()
                        Text(drive.role).foregroundStyle(.secondary)
                        Spacer()
                        StatusLabel(text: drive.state.label, kind: drive.state.kind)
                    }
                    .padding(Theme.rowPadding)
                }
            }
            Text("Each drive is watched separately and updates when it is connected or disconnected.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
    }

    private func locationRow(
        _ title: String, item: String, resource: ResourceStatus, path: String, choose: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(path)
                    .font(Theme.mono)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                StatusLabel(text: "\(resource.locationKind) · \(resource.state.label)", kind: resource.state.kind)
                if let problem = resource.problem(item: item) {
                    Text(problem)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Button("Reveal in Finder") { app.revealInFinder(resource) }
                .disabled(!resource.isReady)
            Button(resource.chooseTitle, action: choose)
        }
        .padding(Theme.rowPadding)
    }

    // MARK: Naming

    private var naming: some View {
        // Live: follows the New Project form, or a sample name while it is empty.
        let draft = app.draft
        let sample = ProjectNameGenerator.generatedName(
            date: draft.date, type: draft.type, projectName: draft.projectName.isBlank ? "Develon" : draft.projectName
        )

        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Naming")
            FormCard {
                FormRow("Date format") {
                    Text(ProjectNameGenerator.datePattern).font(Theme.mono)
                }
                FormRow("Project type placement") {
                    Text("After the date").foregroundStyle(.secondary)
                }
                FormRow("Project name placement") {
                    Text("After the project type").foregroundStyle(.secondary)
                }
                FormRow("Generated name preview") {
                    Text(sample).font(Theme.mono).textSelection(.enabled)
                }
            }
            Text("The PHANKY FILM naming format is fixed: yyyy - MM - dd + Project Type + Project Name.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
    }
}

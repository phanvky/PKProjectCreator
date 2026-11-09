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

                Text("Settings are kept in memory and reset when the app quits. Saving arrives in a later phase.")
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
                    Picker("Recent projects to keep", selection: $app.settings.recentProjectsLimit) {
                        ForEach(AppSettings.recentLimitOptions, id: \.self) { Text("\($0) projects").tag($0) }
                    }
                    .labelsHidden()
                    .buttonSizing(.flexible)
                    .frame(width: 220)
                }
            }
        }
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("After Creating a Project")
            FormCard {
                ToggleRow("Reveal the new folder in Finder", isOn: $app.settings.revealInFinderAfterCreate)
                ToggleRow("Open the Premiere project", isOn: $app.settings.openPremiereAfterCreate)
                ToggleRow("Clear the project name for the next project", isOn: $app.settings.clearNameAfterCreate)
            }
        }
    }

    // MARK: Locations

    @ViewBuilder
    private var locations: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Locations")
            FormCard {
                locationRow("Default project destination", path: "\(app.settings.destinationBase)/{yyyy}")
                locationRow("Premiere Pro master template", path: app.premiere.sourcePath)
            }
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
                        StatusLabel(text: drive.status.label, kind: drive.status.kind)
                    }
                    .padding(Theme.rowPadding)
                }
            }
            Text("Volume checks and remembered drive permissions arrive in a later phase.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
    }

    private func locationRow(_ title: String, path: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(path)
                    .font(Theme.mono)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            Button("Choose…") {}
                .disabled(true)
                .help("Choosing locations arrives in a later phase.")
        }
        .padding(Theme.rowPadding)
    }

    // MARK: Naming

    private var naming: some View {
        let sample = ProjectNaming.generatedName(date: .now, type: app.settings.defaultProjectType, projectName: "Develon")

        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Naming")
            FormCard {
                FormRow("Date format") {
                    Text(ProjectNaming.datePattern).font(Theme.mono)
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

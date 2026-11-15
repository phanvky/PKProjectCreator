import SwiftUI

/// Settings › General: the user's own list of project types.
struct ProjectTypesSection: View {
    @Environment(AppState.self) private var app
    @State private var renaming: ProjectType?
    @State private var renameText = ""
    @State private var deleting: ProjectType?

    var body: some View {
        let types = app.settings.projectTypes

        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Project Types") {
                Text("\(types.count) \(types.count == 1 ? "type" : "types")")
            }
            FormCard {
                ForEach(Array(types.enumerated()), id: \.element) { index, type in
                    HStack(spacing: 12) {
                        Text(type.rawValue)
                        if type == app.settings.defaultProjectType {
                            StatusBadge(text: "Default", kind: .neutral)
                        }
                        Spacer(minLength: 12)
                        Button("Move Up", systemImage: "arrow.up") { app.moveProjectType(type, by: -1) }
                            .disabled(index == 0)
                        Button("Move Down", systemImage: "arrow.down") { app.moveProjectType(type, by: 1) }
                            .disabled(index == types.count - 1)
                        Button("Rename", systemImage: "pencil") { startRename(type) }
                        Button("Delete", systemImage: "trash", role: .destructive) { deleting = type }
                            .disabled(types.count == 1)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .padding(Theme.rowPadding)
                }
                HStack {
                    Button("Add Type", systemImage: "plus") { startRename(app.addProjectType()) }
                        .buttonStyle(.borderless)
                    Spacer()
                }
                .padding(Theme.rowPadding)
            }
            Text("The type is part of every new project’s name. Renaming or deleting a type doesn’t change projects already created.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
        .alert("Rename Project Type", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Type name", text: $renameText)
            Button("Rename") {
                if let renaming { app.renameProjectType(renaming, to: renameText) }
            }
            .disabled(app.projectTypeNameIssue(renameText.trimmingCharacters(in: .whitespaces), for: renaming) != nil)
            Button("Cancel", role: .cancel) {}
        } message: {
            // The text of an open alert doesn't refresh while typing, so the rules are spelled out up front.
            Text("Names can’t be empty, contain “/” or “:”, or repeat another type. Folder templates using this type follow the new name.")
        }
        .confirmationDialog(
            "Delete the type “\(deleting?.rawValue ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete Type", role: .destructive) {
                if let deleting { app.removeProjectType(deleting) }
            }
        } message: {
            Text("It is removed from New Project and from folder templates. Projects already created keep their names and stay in Recent Projects.")
        }
    }

    private func startRename(_ type: ProjectType) {
        renameText = type.rawValue
        renaming = type
    }
}

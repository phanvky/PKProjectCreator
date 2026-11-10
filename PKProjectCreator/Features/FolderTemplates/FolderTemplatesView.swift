import SwiftUI

struct FolderTemplatesView: View {
    @Environment(AppState.self) private var app
    @State private var selectedID: FolderTemplate.ID?
    @State private var isConfirmingDelete = false

    private var selected: FolderTemplate? {
        app.templates.first { $0.id == selectedID }
    }

    var body: some View {
        HStack(spacing: 0) {
            templateList
                .frame(width: 270)
            Divider()
            if let selected {
                FolderTemplateEditor(template: selected)
                    .id(selected.id)
            } else {
                ContentUnavailableView("No Template Selected", systemImage: "list.bullet.indent", description: Text("Select a template to edit it."))
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Duplicate Template", systemImage: "plus") {
                    if let id = selectedID { selectedID = app.duplicateTemplate(id) }
                }
                .labelStyle(.titleAndIcon)
                .disabled(selected == nil)
            }
        }
        .navigationTitle("Folder Templates")
        .navigationSubtitle("\(app.templates.count) templates · changes are saved automatically")
        .onAppear {
            if selectedID == nil { selectedID = app.templates.first?.id }
        }
        .confirmationDialog("Delete the template “\(selected?.name ?? "")”?", isPresented: $isConfirmingDelete) {
            Button("Delete Template", role: .destructive) {
                if let id = selectedID {
                    app.removeTemplate(id)
                    selectedID = app.templates.first?.id
                }
            }
        } message: {
            Text("Its folder structure is deleted with it. Projects already created are not affected. This can’t be undone.")
        }
    }

    private var templateList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(app.templates) { template in
                    TemplateListRow(template: template)
                        .tag(template.id)
                }
            }
            Divider()
            HStack(spacing: 12) {
                Button("Add Template", systemImage: "plus") {
                    selectedID = app.addTemplate()
                }
                let canRemove = selectedID.map(app.canRemoveTemplate) ?? false
                Button("Remove Template", systemImage: "minus") { isConfirmingDelete = true }
                    .disabled(!canRemove)
                    .help(canRemove || selected == nil ? "Delete the selected template" : "The last configured template can’t be deleted")
                Spacer()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(10)
        }
    }
}

private struct TemplateListRow: View {
    let template: FolderTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(template.name).font(.headline)
            Text(template.isConfigured ? "\(template.folderCount) folders · \(template.folderCount + 1) with root" : "Needs configuration")
                .font(.callout)
            Text(defaultsText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private var defaultsText: String {
        let types = template.defaultTypesList
        return types.isEmpty ? "Not a default" : "Default for " + types.map(\.rawValue).joined(separator: ", ")
    }
}

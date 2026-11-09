import SwiftUI

struct FolderTemplatesView: View {
    @Environment(AppState.self) private var app
    @State private var selectedID: FolderTemplate.ID?

    private var selectedIndex: Int? {
        app.templates.firstIndex { $0.id == selectedID }
    }

    var body: some View {
        @Bindable var app = app

        HStack(spacing: 0) {
            templateList
                .frame(width: 270)
            Divider()
            if let index = selectedIndex {
                FolderTemplateEditor(template: $app.templates[index]) { type in
                    app.assign(type, toTemplate: app.templates[index].id)
                }
                .id(app.templates[index].id)
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
                .disabled(selectedIndex == nil)
            }
        }
        .navigationTitle("Folder Templates")
        .navigationSubtitle("\(app.templates.count) templates · changes are not saved yet")
        .onAppear {
            if selectedID == nil { selectedID = app.templates.first?.id }
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
                Button("Remove Template", systemImage: "minus") {
                    if let id = selectedID {
                        app.removeTemplate(id)
                        selectedID = app.templates.first?.id
                    }
                }
                .disabled(app.templates.count <= 1 || selectedIndex == nil)
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
            Text("\(template.folderCount) folders · \(template.folderCount + 1) with root")
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

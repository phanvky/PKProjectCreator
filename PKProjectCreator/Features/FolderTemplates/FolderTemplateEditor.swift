import SwiftUI

/// Editor for one template. Every change goes through AppState, which saves it.
struct FolderTemplateEditor: View {
    private static let rootID = UUID()
    @Environment(AppState.self) private var app
    let template: FolderTemplate

    @State private var nameText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Template Name")
                    TextField("Template Name", text: $nameText)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .labelsHidden()
                        .frame(maxWidth: 440)
                        .onAppear { nameText = template.name }
                        // A valid name is applied as it is typed; an invalid one leaves the saved name unchanged.
                        .onChange(of: nameText) { app.renameTemplate(template.id, to: nameText) }
                    if let issue = app.templateNameIssue(nameText, for: template.id) {
                        ValidationMessage(text: issue)
                            .padding(.horizontal, 6)
                    }
                    if !template.description.isEmpty {
                        Text(template.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Structure") {
                        Text("\(template.folderCount) folders + root · drag a folder onto another to move it inside")
                    }
                    FolderStructureEditor(
                        nodes: template.nodes,
                        root: FolderTreeItem.projectPreview(rootID: Self.rootID, rootName: "[Generated Project Name]", folders: template.nodes, files: []),
                        apply: { change in try app.updateTemplate(template.id) { try change(&$0.nodes) } },
                        emptyMessage: "Add folders below. This template can’t be used for new projects until it has at least one folder.",
                        deleteIssue: { id in
                            template.nodes.map(\.id) == [id] && !app.canRemoveTemplate(template.id)
                                ? "This is the last folder of the only configured template, so it can’t be deleted." : nil
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader("Default for Project Types")
                    FormCard {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(app.settings.projectTypes) { type in
                                    let isOn = template.defaultProjectTypes.contains(type)
                                    Button(type.rawValue) {
                                        app.setDefault(type, isOn: !isOn, forTemplate: template.id)
                                    }
                                    .buttonStyle(ChipButtonStyle(isOn: isOn))
                                }
                            }
                            .padding(12)
                        }
                        .scrollIndicators(.never)
                    }
                    .disabled(!template.isConfigured)
                    Text(
                        template.isConfigured
                            ? "A type uses one template. Turning a type on here moves it from its current template; a type with no template uses the first configured one."
                            : "Add at least one folder before making this template a default."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                }
            }
            .padding(Theme.pagePadding)
        }
    }
}

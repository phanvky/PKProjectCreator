import SwiftUI

struct PremiereTemplateView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: Theme.pagePadding) {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    sourceSection
                    copyIntoSection
                    outputSection
                    behaviorSection
                }
                .frame(minWidth: 460, maxWidth: .infinity)

                statusSection
                    .frame(minWidth: 280, maxWidth: 400)
            }
            .padding(Theme.pagePadding)
        }
        .navigationTitle("Premiere Template")
        .navigationSubtitle(subtitle)
    }

    private var template: ResourceStatus { app.premiereTemplate }

    private var subtitle: String {
        template.state == .notSelected ? "No template selected" : "Template on \(template.volumeName) · \(template.templateLabel)"
    }

    // MARK: Source

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Source Template") {
                if template.url != nil { Text(template.locationKind) }
            }
            FormCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.fileTint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.url?.lastPathComponent ?? "No template selected").font(.headline)
                        if let url = template.url {
                            Text(url.deletingLastPathComponent().plainPath + "/")
                                .font(Theme.mono)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        if template.url != nil, let problem = template.problem(item: "Premiere template") {
                            Text(problem)
                                .font(.callout)
                                .foregroundStyle(template.state.kind.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 12)
                    StatusBadge(text: template.templateLabel, kind: template.state.kind)
                }
                .padding(16)

                HStack {
                    if template.url != nil {
                        Label("Volume \(template.volumeName)", systemImage: "externaldrive")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reveal in Finder") { app.revealInFinder(template) }
                        .disabled(!template.isReady)
                    Button("Clear") { app.clearPremiereTemplate() }
                        .disabled(template.url == nil)
                        .help("Forget this template. The file itself is not changed.")
                    Button(template.chooseTitle) { app.choosePremiereTemplate() }
                }
                .padding(Theme.rowPadding)
            }
        }
    }

    // MARK: Copy into

    private var copyIntoSection: some View {
        @Bindable var app = app
        let current = app.premiere.destinationFolder
        let paths = app.selectedTemplate?.nodes.allPaths ?? []
        let options = paths.contains(current) ? paths : [current] + paths

        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Copy Into")
            FormCard {
                FormRow("Folder inside project") {
                    Picker("Folder inside project", selection: $app.premiere.destinationFolder) {
                        ForEach(options, id: \.self) { path in
                            Text(path.joined(separator: " › ")).tag(path)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 300)
                }
                InfoRow(label: "Path", value: "[Project]/\(current.joined(separator: "/"))/", monospaced: true, labelWidth: 40)
                    .padding(.vertical, 2)
            }
        }
    }

    // MARK: Output

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Output Filename")
            FormCard {
                HStack(spacing: 8) {
                    TokenChip(text: "Date · \(ProjectNameGenerator.datePattern)")
                    TokenChip(text: "Project Type")
                    TokenChip(text: "Project Name")
                    Text(".prproj")
                        .font(Theme.mono)
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.rowPadding)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Pattern: date, project type, project name, dot prproj")

                InfoRow(label: "Preview", value: "\(app.displayName).prproj", monospaced: true, labelWidth: 56)
                    .padding(.vertical, 2)
            }
        }
    }

    // MARK: Behavior

    private var behaviorSection: some View {
        @Bindable var app = app

        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Behavior")
            FormCard {
                ToggleRow("Copy template when creating a project", isOn: $app.settings.createPremiereProjectByDefault)
                ToggleRow("Open in Premiere Pro after creating", isOn: $app.settings.openPremiereAfterCreation)
                FormRow("If the template is missing") {
                    Text("Block project creation").foregroundStyle(.secondary)
                }
            }
            Text("To create folders only, turn off “Create Premiere project from template” on New Project. Incomplete projects are never created silently.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
        }
    }

    // MARK: Status

    private var statusSection: some View {
        let folderTemplate = app.selectedTemplate
        let destinationExists = folderTemplate?.nodes.allPaths.contains(app.premiere.destinationFolder) ?? false
        let destination = app.premiere.destinationFolder.joined(separator: "/")

        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Template Status")
            FormCard {
                if template.url != nil {
                    StatusCheckRow(
                        title: "\(template.volumeName) drive",
                        detail: template.state == .disconnected ? "Disconnected — template source" : "Connected — template source",
                        kind: template.state == .disconnected ? .danger : .success
                    )
                }
                StatusCheckRow(
                    title: "Template file",
                    detail: template.isReady ? "Template found · ready to copy" : "\(template.templateLabel). \(template.problem(item: "Premiere template") ?? "")",
                    kind: template.state.kind
                )
                StatusCheckRow(
                    title: "Destination folder",
                    detail: destinationExists
                        ? "\(destination) exists in “\(folderTemplate?.name ?? "")”"
                        : "\(destination) isn’t in “\(folderTemplate?.name ?? "")”",
                    kind: destinationExists ? .success : .warning
                )
                outputCheck
                Text("The source file is copied, never modified. The copy is renamed to the generated project name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(Theme.rowPadding)
            }
        }
    }

    private var outputCheck: StatusCheckRow {
        switch app.nameIssue {
        case .none:
            StatusCheckRow(title: "Output filename", detail: "\(app.generatedName).prproj", kind: .success)
        case .empty:
            StatusCheckRow(title: "Output filename", detail: "Waiting for a project name", kind: .neutral)
        case .some(let issue):
            StatusCheckRow(title: "Output filename", detail: issue.message, kind: .danger)
        }
    }
}

private struct StatusCheckRow: View {
    let title: String
    let detail: String
    let kind: StatusKind

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.title3)
                .foregroundStyle(kind.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct TokenChip: View {
    let text: String

    var body: some View {
        Text(text)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.15), in: .rect(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.accentColor.opacity(0.5)))
    }
}

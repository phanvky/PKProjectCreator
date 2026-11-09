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

    private var volume: String { app.premiere.volumeName ?? "this Mac" }

    private var subtitle: String {
        switch app.premiere.status {
        case .unknown: "Template on \(volume) · not checked yet"
        case .found: "Template ready on \(volume)"
        case .missing: "Template missing on \(volume)"
        }
    }

    // MARK: Source

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Source Template")
            FormCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.fileTint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.premiere.sourceFilename).font(.headline)
                        Text(app.premiere.sourceFolder)
                            .font(Theme.mono)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer(minLength: 12)
                    StatusBadge(text: app.premiere.status.label, kind: app.premiere.status.kind)
                }
                .padding(16)

                HStack {
                    Label("Volume \(volume)", systemImage: "externaldrive")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Group {
                        Button("Reveal in Finder") {}
                        Button("Choose Another…") {}
                    }
                    .disabled(true)
                    .help("File access arrives in a later phase.")
                }
                .padding(Theme.rowPadding)
            }
        }
    }

    // MARK: Copy into

    private var copyIntoSection: some View {
        @Bindable var app = app
        let current = app.premiere.destinationFolder
        let paths = app.selectedTemplate?.folders.allPaths ?? []
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
                    TokenChip(text: "Date · \(ProjectNaming.datePattern)")
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
                ToggleRow("Copy template when creating a project", isOn: $app.premiere.copyOnCreate)
                ToggleRow("Open in Premiere Pro after creating", isOn: $app.settings.openPremiereAfterCreate)
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
        let drive = app.premiere.volumeName.flatMap { app.drive(forPath: "/Volumes/\($0)") }
        let template = app.selectedTemplate
        let destinationExists = template?.folders.allPaths.contains(app.premiere.destinationFolder) ?? false
        let destination = app.premiere.destinationFolder.joined(separator: "/")

        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Template Status")
            FormCard {
                StatusCheckRow(
                    title: "\(volume) drive",
                    detail: "\(drive?.status.label ?? "Unknown volume") — template source",
                    kind: drive?.status.kind ?? .neutral
                )
                StatusCheckRow(title: "Template file", detail: app.premiere.status.label, kind: app.premiere.status.kind)
                StatusCheckRow(
                    title: "Destination folder",
                    detail: destinationExists
                        ? "\(destination) exists in “\(template?.name ?? "")”"
                        : "\(destination) isn’t in “\(template?.name ?? "")”",
                    kind: destinationExists ? .success : .warning
                )
                outputCheck
                Text("The source file is copied, never modified. The copy is renamed to the generated project name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(Theme.rowPadding)
            }
            Text("Drive and file checks run in a later phase.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
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

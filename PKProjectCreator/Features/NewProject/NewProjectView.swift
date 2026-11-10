import SwiftUI

struct NewProjectView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app

        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    ProjectInfoSection()
                    GeneratedNameSection()
                    DestinationSection()
                    PremiereSection()
                    ResolveSection()
                }
                .padding(Theme.pagePadding)
            }
            .frame(minWidth: 480, maxWidth: .infinity)

            FolderPreviewPanel()
                .frame(minWidth: 300, maxWidth: 520)
                .padding([.top, .bottom, .trailing], Theme.pagePadding)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomActionBar(message: app.creationStatus) {
                if app.creationTask != nil {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { app.cancelCreation() }
                } else {
                    Button("Reset") { app.resetDraft() }
                }
                Button("Create Project") { app.createProject() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(app.creationBlocker != nil || app.creationTask != nil)
            }
        }
        .sheet(item: $app.createdProject) { project in
            ProjectCreatedDialog(
                projectName: project.name,
                directoryCount: project.directoryCount,
                premiereFilename: project.premiereFilename,
                location: project.fullPath,
                onRevealInFinder: { app.revealInFinder(project) },
                onOpenInPremiere: { app.openInPremiere(project) },
                onDone: { app.createdProject = nil }
            )
        }
        .navigationTitle("New Project")
        .navigationSubtitle(subtitle)
    }

    private var subtitle: String {
        guard let template = app.selectedTemplate else { return "" }
        return "\(template.name) · \(template.folderCount) folders"
    }
}

// MARK: - Project

private struct ProjectInfoSection: View {
    @Environment(AppState.self) private var app
    @State private var showsCalendar = false

    var body: some View {
        @Bindable var app = app
        let issue = app.nameIssue
        let showsError = issue != nil && issue != .empty

        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Project")
            FormCard {
                FormRow("Date") {
                    HStack(spacing: 6) {
                        Button {
                            showsCalendar.toggle()
                        } label: {
                            Label("Show Calendar", systemImage: "calendar").labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .popover(isPresented: $showsCalendar, arrowEdge: .bottom) {
                            DatePicker("Date", selection: $app.draft.date, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .padding()
                        }
                        DatePicker("Date", selection: $app.draft.date, displayedComponents: .date)
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                    }
                }
                FormRow("Project Type") {
                    Picker("Project Type", selection: $app.draft.type) {
                        ForEach(ProjectType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .buttonSizing(.flexible)
                    .frame(width: 240)
                }
                FormRow("Project Name") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Project Name", text: $app.draft.projectName, prompt: Text("Client or event, e.g. Develon"))
                            .textFieldStyle(.roundedBorder)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.red, lineWidth: showsError ? 1.5 : 0)
                            )
                            .labelsHidden()
                        if showsError, let issue {
                            ValidationMessage(text: issue.message)
                        }
                    }
                    .frame(maxWidth: 360)
                }
                FormRow("Folder Template") {
                    HStack(spacing: 12) {
                        if let template = app.selectedTemplate {
                            Text("\(template.folderCount) folders")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                        Picker("Folder Template", selection: $app.draft.templateID) {
                            ForEach(app.templates) { Text($0.name).tag(Optional($0.id)) }
                        }
                        .labelsHidden()
                        .buttonSizing(.flexible)
                        .frame(width: 240)
                    }
                }
            }
        }
        .onChange(of: app.draft.type) { _, newType in
            app.draft.templateID = app.defaultTemplate(for: newType)?.id
        }
    }
}

// MARK: - Generated name

private struct GeneratedNameSection: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Generated Name")
            FormCard {
                HStack(spacing: 14) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.folderTint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        nameText
                            .font(.title2.weight(.semibold))
                            .lineLimit(2)
                            .textSelection(.enabled)
                        Text("yyyy - MM - dd + Project Type + Project Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Button("Copy", systemImage: "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(app.generatedName, forType: .string)
                    }
                    .disabled(app.draft.projectName.isBlank)
                    .help("Copy the generated name")
                }
                .padding(16)
            }
        }
    }

    private var nameText: Text {
        let date = Text(ProjectNameGenerator.datePrefix(for: app.draft.date))
        let type = Text(app.draft.type.rawValue).foregroundStyle(Color.accentColor)
        let name = app.draft.projectName.isBlank
            ? Text(ProjectNameGenerator.namePlaceholder).italic().foregroundStyle(.secondary)
            : Text(app.draft.projectName)
        return Text("\(date) \(type) \(name)")
    }
}

// MARK: - Destination

private struct DestinationSection: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        let destination = app.destination

        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Destination") {
                Text(destination.locationKind)
            }
            FormCard {
                HStack(spacing: 10) {
                    PathBreadcrumb(path: app.destinationFolder, isInvalid: destination.state.kind == .danger)
                    Button(destination.chooseTitle) { app.chooseDestination() }
                        .help("Choose the folder where new projects are created")
                }
                .padding(Theme.rowPadding)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Creates")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(app.projectPath)
                        .font(Theme.mono)
                        .textSelection(.enabled)
                }
                .padding(Theme.rowPadding)

                HStack {
                    Toggle("Use year folder from project date", isOn: $app.settings.useYearFolderFromProjectDate)
                    Spacer(minLength: 12)
                    StatusLabel(text: "\(destination.volumeName) · \(destination.state.label)", kind: destination.state.kind)
                }
                .padding(Theme.rowPadding)
            }
        }
    }
}

// MARK: - Premiere Pro

private struct PremiereSection: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        let template = app.premiereTemplate
        let isMissing = !template.isReady

        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Premiere Pro")
            FormCard {
                HStack {
                    Toggle("Create Premiere project from template", isOn: $app.draft.createPremiere)
                    Spacer(minLength: 12)
                    StatusBadge(text: template.templateLabel, kind: template.state.kind)
                }
                .padding(Theme.rowPadding)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Source")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    Image(systemName: "doc.fill").foregroundStyle(Theme.fileTint)
                    Text(template.url?.lastPathComponent ?? "No template selected")
                        .strikethrough(isMissing)
                        .foregroundStyle(isMissing ? StatusKind.warning.color : Color.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 12)
                    Button("Manage…") { app.screen = .premiereTemplate }
                        .buttonStyle(.link)
                }
                .padding(Theme.rowPadding)
                .opacity(app.draft.createPremiere ? 1 : 0.45)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Output")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    Text(app.premiereOutputPath)
                        .font(Theme.mono)
                        .textSelection(.enabled)
                }
                .padding(Theme.rowPadding)
                .opacity(app.draft.createPremiere ? 1 : 0.45)

                ToggleRow("Open in Premiere Pro after creating", isOn: $app.settings.openPremiereAfterCreation)
                    .disabled(!app.draft.createPremiere)
            }
        }
    }
}

// MARK: - DaVinci Resolve

private struct ResolveSection: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        let template = app.resolveTemplate
        let isMissing = !template.isReady

        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("DaVinci Resolve")
            FormCard {
                HStack {
                    Toggle("Create DaVinci Resolve project from template", isOn: $app.draft.createResolve)
                    Spacer(minLength: 12)
                    StatusBadge(text: template.templateLabel, kind: template.state.kind)
                }
                .padding(Theme.rowPadding)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Source")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    Image(systemName: "doc.fill").foregroundStyle(Theme.fileTint)
                    Text(template.url?.lastPathComponent ?? "No template selected")
                        .strikethrough(isMissing)
                        .foregroundStyle(isMissing ? StatusKind.warning.color : Color.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 12)
                    Button("Manage…") { app.screen = .resolveTemplate }
                        .buttonStyle(.link)
                }
                .padding(Theme.rowPadding)
                .opacity(app.draft.createResolve ? 1 : 0.45)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Output")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    Text(app.resolveOutputPath)
                        .font(Theme.mono)
                        .textSelection(.enabled)
                }
                .padding(Theme.rowPadding)
                .opacity(app.draft.createResolve ? 1 : 0.45)
            }
        }
    }
}

import AppKit
import Observation

/// Single source of truth. Settings and folder templates are saved to disk through their stores; the rest is in memory.
@Observable
final class AppState {
    var screen: AppScreen = .newProject
    /// Saved after every change.
    var settings: AppSettings {
        didSet { if settings != oldValue { saveSettings() } }
    }
    var templates: [FolderTemplate]
    /// A problem to show the user (loading, saving, permissions); nil when everything is fine.
    var notice: String?
    var premiere = PremiereTemplateConfig()
    /// The project destination folder (on KIOXIA by default). Tracked independently of the template.
    private(set) var destination = ResourceStatus()
    /// The Premiere master project file (on WORK by default).
    private(set) var premiereTemplate = ResourceStatus()
    /// Sample rows only (see `RecentProject.samples`); real history arrives with persistence.
    var recentProjects = RecentProject.samples
    var draft = NewProjectDraft(type: .event, createPremiere: true)
    /// Running while a project is being created; nil otherwise.
    private(set) var creationTask: Task<Void, Never>?
    /// The project that was just created, shown in the success dialog.
    var createdProject: RecentProject?

    private let templateStore: FolderTemplateStore?
    private let settingsStore: SettingsStore?
    private let fileAccess: FileAccessService
    private let creationService: ProjectCreationService

    /// `directory` is where settings and templates are saved; pass `nil` to keep everything in memory (previews).
    init(
        directory: URL? = .appSupportFolder, fileAccess: FileAccessService = FileAccessService(),
        creationService: ProjectCreationService = ProjectCreationService()
    ) {
        templateStore = directory.map(FolderTemplateStore.init)
        settingsStore = directory.map(SettingsStore.init)
        self.fileAccess = fileAccess
        self.creationService = creationService

        let loadedSettings = settingsStore?.load()
        settings = loadedSettings?.settings ?? AppSettings()
        let loadedTemplates = templateStore?.load()
        templates = loadedTemplates?.templates ?? FolderTemplate.builtIn()
        notice = [loadedSettings?.notice, loadedTemplates?.notice].compactMap(\.self).joined(separator: "\n\n").nilIfEmpty

        refreshResources()
        resetDraft()
    }

    // MARK: New project

    func resetDraft() {
        let type = settings.defaultProjectType
        draft = NewProjectDraft(type: type, templateID: defaultTemplate(for: type)?.id, createPremiere: settings.createPremiereProjectByDefault)
    }

    func startProject(like project: RecentProject) {
        resetDraft()
        draft.type = project.type
        draft.projectName = project.projectName
        draft.templateID = templates.first { $0.name == project.templateName }?.id ?? defaultTemplate(for: project.type)?.id
        screen = .newProject
    }

    /// Creates the project described by `creationPlan`. The disk work runs off the main actor, inside the
    /// access macOS granted for the destination folder.
    func createProject() {
        guard creationTask == nil, creationBlocker == nil, let bookmark = settings.destinationBookmarkData else { return }
        let plan = creationPlan
        creationTask = Task {
            defer { creationTask = nil }
            do {
                let project = try await fileAccess.withAccess(to: bookmark) { url, _ in
                    try await creationService.create(plan, in: url)
                }
                createdProject = project
                if settings.clearProjectNameAfterCreation { draft.projectName = "" }
                if settings.openFinderAfterCreation { revealInFinder(project) }
            } catch {
                notice = error.localizedDescription
                refreshResources()
            }
        }
    }

    func cancelCreation() {
        creationTask?.cancel()
    }

    func revealInFinder(_ project: RecentProject) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: project.fullPath, directoryHint: .isDirectory)])
    }

    // MARK: Templates

    /// The template a type uses: its assigned default, otherwise the first configured template.
    func defaultTemplate(for type: ProjectType) -> FolderTemplate? {
        let usable = templates.filter(\.isConfigured)
        return usable.first { $0.defaultProjectTypes.contains(type) } ?? usable.first
    }

    /// The one place template edits go through: applies `body`, then saves.
    @discardableResult
    func updateTemplate<T>(_ id: FolderTemplate.ID, _ body: (inout FolderTemplate) throws -> T) rethrows -> T? {
        guard let index = templates.firstIndex(where: { $0.id == id }) else { return nil }
        let result = try body(&templates[index])
        saveTemplates()
        return result
    }

    /// Turns a type's default on or off for a template. A type has at most one template, so turning it on
    /// here removes it from the others. Templates that still need configuration can't be defaults.
    func setDefault(_ type: ProjectType, isOn: Bool, forTemplate id: FolderTemplate.ID) {
        guard templates.first(where: { $0.id == id })?.isConfigured == true else { return }
        for index in templates.indices {
            templates[index].defaultProjectTypes.removeAll { $0 == type }
            if isOn, templates[index].id == id { templates[index].defaultProjectTypes.append(type) }
        }
        saveTemplates()
    }

    func templateNameIssue(_ name: String, for id: FolderTemplate.ID) -> String? {
        if name.isBlank { return "Enter a template name." }
        if templates.contains(where: { $0.id != id && FolderNaming.sameName($0.name, name) }) {
            return "Another template already uses this name."
        }
        return nil
    }

    func renameTemplate(_ id: FolderTemplate.ID, to name: String) {
        guard templateNameIssue(name, for: id) == nil, templates.first(where: { $0.id == id })?.name != name else { return }
        updateTemplate(id) { $0.name = name }
    }

    @discardableResult
    func addTemplate() -> FolderTemplate.ID {
        let template = FolderTemplate(name: uniqueTemplateName("Untitled Template"))
        templates.append(template)
        saveTemplates()
        return template.id
    }

    @discardableResult
    func duplicateTemplate(_ id: FolderTemplate.ID) -> FolderTemplate.ID? {
        guard let source = templates.first(where: { $0.id == id }) else { return nil }
        let copy = source.duplicated(named: uniqueTemplateName("\(source.name) Copy"))
        templates.append(copy)
        saveTemplates()
        return copy.id
    }

    /// The last configured template can't be deleted, so there is always one to create projects from.
    func canRemoveTemplate(_ id: FolderTemplate.ID) -> Bool {
        guard let template = templates.first(where: { $0.id == id }) else { return false }
        return !template.isConfigured || templates.filter(\.isConfigured).count > 1
    }

    /// Types that defaulted to the removed template fall back to the first configured one.
    func removeTemplate(_ id: FolderTemplate.ID) {
        guard canRemoveTemplate(id) else { return }
        templates.removeAll { $0.id == id }
        if draft.templateID == id {
            draft.templateID = defaultTemplate(for: draft.type)?.id
        }
        saveTemplates()
    }

    private func uniqueTemplateName(_ base: String) -> String {
        FolderNaming.uniqueName(base, among: templates.map(\.name))
    }

    private func saveTemplates() {
        guard let templateStore else { return }
        do {
            try templateStore.save(templates)
        } catch {
            notice = "Your template changes couldn’t be saved: \(error.localizedDescription)"
        }
    }

    private func saveSettings() {
        guard let settingsStore else { return }
        do {
            try settingsStore.save(settings)
        } catch {
            notice = "Your settings couldn’t be saved: \(error.localizedDescription)"
        }
    }

    // MARK: Destination and Premiere template

    /// Rows for the drive status card: one per resource, each with its own state.
    var drives: [DriveInfo] {
        [
            DriveInfo(name: destination.volumeName, role: "Projects", state: destination.state),
            DriveInfo(name: premiereTemplate.volumeName, role: "Templates", state: premiereTemplate.state),
        ]
    }

    /// Re-checks both resources. Called at launch, after a choice, when a volume mounts, unmounts or is renamed,
    /// and when the app becomes active.
    func refreshResources() {
        var updated = settings

        let destinationCheck = fileAccess.check(
            bookmark: updated.destinationBookmarkData, lastKnownURL: updated.defaultDestinationURL,
            volume: updated.destinationVolume, readOnly: false
        )
        if destination != destinationCheck.status { destination = destinationCheck.status }
        updated.destinationBookmarkData = destinationCheck.renewedBookmark ?? updated.destinationBookmarkData
        updated.destinationVolume = destinationCheck.volume
        if destinationCheck.status.isReady, let url = destinationCheck.status.url { updated.defaultDestinationURL = url }

        let templateCheck = fileAccess.check(
            bookmark: updated.premiereTemplateBookmarkData, lastKnownURL: updated.premiereTemplateURL,
            volume: updated.premiereTemplateVolume, readOnly: true
        )
        if premiereTemplate != templateCheck.status { premiereTemplate = templateCheck.status }
        updated.premiereTemplateBookmarkData = templateCheck.renewedBookmark ?? updated.premiereTemplateBookmarkData
        updated.premiereTemplateVolume = templateCheck.volume
        if templateCheck.status.isReady, let url = templateCheck.status.url { updated.premiereTemplateURL = url }

        settings = updated
    }

    func chooseDestination() {
        let message = "Choose the folder where new projects are created. This gives PKProjectCreator access to that folder only."
        if let url = OpenPanels.chooseFolder(message: message, startingAt: destination.url) { setDestination(url) }
    }

    func choosePremiereTemplate() {
        let message = "Choose the Premiere Pro master project (.prproj). It is only ever read, never changed."
        let folder = premiereTemplate.url?.deletingLastPathComponent()
        if let url = OpenPanels.chooseFile(message: message, fileExtension: "prproj", startingAt: folder) { setPremiereTemplate(url) }
    }

    /// Remembers a folder the user picked as the project destination, replacing the previous one.
    func setDestination(_ url: URL) {
        do {
            let grant = try fileAccess.authorize(url, readOnly: false)
            var updated = settings
            updated.defaultDestinationURL = url
            updated.destinationBookmarkData = grant.bookmark
            updated.destinationVolume = grant.volume
            settings = updated
            refreshResources()
        } catch {
            notice = "PKProjectCreator couldn’t keep permission for “\(url.lastPathComponent)”: \(error.localizedDescription)"
        }
    }

    /// Remembers a `.prproj` file the user picked as the master template, replacing the previous one.
    func setPremiereTemplate(_ url: URL) {
        guard url.pathExtension.lowercased() == "prproj" else {
            notice = "“\(url.lastPathComponent)” isn’t a Premiere Pro project. Choose a file ending in .prproj."
            return
        }
        do {
            let grant = try fileAccess.authorize(url, readOnly: true)
            var updated = settings
            updated.premiereTemplateURL = url
            updated.premiereTemplateBookmarkData = grant.bookmark
            updated.premiereTemplateVolume = grant.volume
            settings = updated
            refreshResources()
        } catch {
            notice = "PKProjectCreator couldn’t keep permission for “\(url.lastPathComponent)”: \(error.localizedDescription)"
        }
    }

    /// Forgets the template and its permission. The file itself is not touched.
    func clearPremiereTemplate() {
        var updated = settings
        updated.premiereTemplateURL = nil
        updated.premiereTemplateBookmarkData = nil
        updated.premiereTemplateVolume = nil
        settings = updated
        refreshResources()
    }

    func revealInFinder(_ resource: ResourceStatus) {
        if let url = resource.url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
}

import AppKit
import Observation

/// Single source of truth. Settings, folder templates and recent projects are saved to disk through their stores.
@Observable
final class AppState {
    var screen: AppScreen = .newProject
    /// Saved after every change.
    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            saveSettings()
            if settings.maximumRecentProjects != oldValue.maximumRecentProjects { saveRecentProjects() }
        }
    }
    var templates: [FolderTemplate]
    /// A problem to show the user (loading, saving, permissions); nil when everything is fine.
    var notice: String?
    var premiere = PremiereTemplateConfig()
    /// The project destination folder (on KIOXIA by default). Tracked independently of the template.
    private(set) var destination = ResourceStatus()
    /// The Premiere master project file (on WORK by default).
    private(set) var premiereTemplate = ResourceStatus()
    /// Projects this app created, newest first, at most `settings.maximumRecentProjects`. Never filled by scanning drives.
    private(set) var recentProjects: [RecentProject]
    /// Where each recent project stands right now (available, drive disconnected, missing…).
    private(set) var recentStatuses: [RecentProject.ID: RecentProjectStatus] = [:]
    var draft = NewProjectDraft(type: .event, createPremiere: true)
    /// Running while a project is being created; nil otherwise.
    private(set) var creationTask: Task<Void, Never>?
    /// The project that was just created, shown in the success dialog.
    var createdProject: RecentProject?

    private let templateStore: FolderTemplateStore?
    private let settingsStore: SettingsStore?
    private let recentStore: RecentProjectsStore?
    private let fileAccess: FileAccessService
    private let creationService: ProjectCreationService

    /// `directory` is where settings, templates and recent projects are saved; pass `nil` to keep everything in
    /// memory (previews and tests).
    init(
        directory: URL? = .appSupportFolder, fileAccess: FileAccessService = FileAccessService(),
        creationService: ProjectCreationService = ProjectCreationService()
    ) {
        templateStore = directory.map(FolderTemplateStore.init)
        settingsStore = directory.map(SettingsStore.init)
        recentStore = directory.map(RecentProjectsStore.init)
        self.fileAccess = fileAccess
        self.creationService = creationService

        let loadedSettings = settingsStore?.load()
        let initialSettings = loadedSettings?.settings ?? AppSettings()
        settings = initialSettings
        let loadedTemplates = templateStore?.load()
        templates = loadedTemplates?.templates ?? FolderTemplate.builtIn()
        let loadedRecent = recentStore?.load()
        recentProjects = Self.newest(loadedRecent?.projects ?? [], limit: initialSettings.maximumRecentProjects)
        notice = [loadedSettings?.notice, loadedTemplates?.notice, loadedRecent?.notice]
            .compactMap(\.self).joined(separator: "\n\n").nilIfEmpty

        refreshResources()
        resetDraft()
    }

    // MARK: New project

    func resetDraft() {
        let type = settings.defaultProjectType
        draft = NewProjectDraft(type: type, templateID: defaultTemplate(for: type)?.id, createPremiere: settings.createPremiereProjectByDefault)
    }

    /// A fresh form with the same type and folder template as `project`: today's date, an empty name, and the
    /// saved destination. Nothing on disk is read, copied or changed.
    func startProject(like project: RecentProject) {
        createdProject = nil
        resetDraft()
        draft.type = project.projectType
        let sameTemplate = templates.first { $0.id == project.folderTemplateID && $0.isConfigured }
        draft.templateID = sameTemplate?.id ?? defaultTemplate(for: project.projectType)?.id
        screen = .newProject
    }

    /// Creates the project described by `creationPlan`. The disk work runs off the main actor, inside the
    /// access macOS granted for the destination folder.
    func createProject() {
        guard creationTask == nil, creationBlocker == nil, let destinationBookmark = settings.destinationBookmarkData else { return }
        let plan = creationPlan
        let templateBookmark = plan.createsPremiereProject ? settings.premiereTemplateBookmarkData : nil
        guard !plan.createsPremiereProject || templateBookmark != nil else { return }

        creationTask = Task {
            defer { creationTask = nil }
            do {
                // KIOXIA and WORK are separate permissions; both stay open until the creation has finished.
                let project = try await fileAccess.withAccess(to: destinationBookmark) { destination, _ in
                    var project = if let templateBookmark {
                        try await fileAccess.withAccess(to: templateBookmark) { template, _ in
                            try await creationService.create(plan, in: destination, premiereTemplate: template)
                        }
                    } else {
                        try await creationService.create(plan, in: destination)
                    }
                    // Remember the new folder itself, so Recent Projects can reach it even if the destination changes.
                    if let grant = try? fileAccess.authorize(project.rootURL, readOnly: false) {
                        project.projectRootBookmark = grant.bookmark
                        project.volume = grant.volume
                    }
                    return project
                }
                addRecentProject(project)
                createdProject = project
                if settings.clearProjectNameAfterCreation { draft.projectName = "" }
                if settings.openFinderAfterCreation { revealInFinder(project) }
                if settings.openPremiereAfterCreation { openInPremiere(project) }
            } catch {
                notice = error.localizedDescription
                refreshResources()
            }
        }
    }

    /// Opens the project's `.prproj` with the app macOS has registered for it. A failure here is only
    /// reported: the project itself stays as it is.
    func openInPremiere(_ project: RecentProject) {
        guard let relativePath = project.premiereProjectRelativePath,
              let bookmark = project.projectRootBookmark ?? settings.destinationBookmarkData else { return }
        let usesRootBookmark = project.projectRootBookmark != nil
        let kept = "The project has not been changed."
        Task {
            var file = project.rootURL.appending(path: relativePath, directoryHint: .notDirectory)
            do {
                try await fileAccess.withAccess(to: bookmark) { url, _ in
                    // The folder may have been renamed or moved since; its bookmark knows where it is now.
                    if usesRootBookmark { file = url.appending(path: relativePath, directoryHint: .notDirectory) }
                    guard let app = NSWorkspace.shared.urlForApplication(toOpen: file) else {
                        notice = "No app on this Mac is set to open .prproj files, so “\(file.lastPathComponent)” wasn’t opened. Install Adobe Premiere Pro, or open the file from Finder. \(kept)"
                        return
                    }
                    do {
                        _ = try await NSWorkspace.shared.open([file], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
                    } catch {
                        let name = FileManager.default.displayName(atPath: app.path(percentEncoded: false))
                        notice = "“\(file.lastPathComponent)” couldn’t be opened in \(name): \(error.localizedDescription) \(kept)"
                    }
                }
            } catch {
                notice = "“\(file.lastPathComponent)” couldn’t be opened: \(error.localizedDescription) \(kept)"
            }
        }
    }

    func cancelCreation() {
        creationTask?.cancel()
    }

    func revealInFinder(_ project: RecentProject) {
        NSWorkspace.shared.activateFileViewerSelecting([recentStatuses[project.id]?.url ?? project.rootURL])
    }

    // MARK: Recent projects

    /// Records a project this app just created. The list keeps the newest `maximumRecentProjects` entries.
    func addRecentProject(_ project: RecentProject) {
        recentProjects.insert(project, at: 0)
        saveRecentProjects()
        recentStatuses[project.id] = status(of: project).status
    }

    /// Removes the entry from the list only. The project folder and its Premiere file are not touched.
    func removeRecentProject(_ id: RecentProject.ID) {
        recentProjects.removeAll { $0.id == id }
        recentStatuses[id] = nil
        saveRecentProjects()
    }

    /// The path of the project folder: where it really is when reachable, otherwise where it was created.
    func path(of project: RecentProject) -> String {
        (recentStatuses[project.id]?.url ?? project.rootURL).plainPath
    }

    func copyPath(of project: RecentProject) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path(of: project), forType: .string)
    }

    /// Re-checks every entry. Records are never removed or changed here, except to renew an expired permission.
    func refreshRecentProjects() {
        var renewedAny = false
        for index in recentProjects.indices {
            let (status, renewed) = status(of: recentProjects[index])
            if recentStatuses[recentProjects[index].id] != status { recentStatuses[recentProjects[index].id] = status }
            if let renewed {
                recentProjects[index].projectRootBookmark = renewed
                renewedAny = true
            }
        }
        if renewedAny { saveRecentProjects() }
    }

    private func status(of project: RecentProject) -> (status: RecentProjectStatus, renewed: Data?) {
        let check = fileAccess.check(
            bookmark: project.projectRootBookmark, lastKnownURL: project.rootURL, volume: project.volume, readOnly: false
        )
        var status = RecentProjectStatus(volumeName: check.status.volumeName)
        switch check.status.state {
        case .authorized:
            status.location = .available
            status.url = check.status.url
            if let relativePath = project.premiereProjectRelativePath, let bookmark = check.renewedBookmark ?? project.projectRootBookmark {
                status.premiereFileExists = (try? fileAccess.withAccess(to: bookmark) { url, _ in
                    fileAccess.system.isReachable(url.appending(path: relativePath, directoryHint: .notDirectory))
                }) ?? false
            }
        case .disconnected: status.location = .volumeDisconnected
        case .missing: status.location = .missing
        case .permissionUnavailable, .stale, .invalid, .notSelected: status.location = .permissionNeeded
        }
        return (status, check.renewedBookmark)
    }

    private static func newest(_ projects: [RecentProject], limit: Int) -> [RecentProject] {
        Array(projects.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    /// Trims to the limit (metadata only; nothing on disk is deleted) and saves.
    private func saveRecentProjects() {
        recentProjects = Self.newest(recentProjects, limit: settings.maximumRecentProjects)
        guard let recentStore else { return }
        do {
            try recentStore.save(recentProjects)
        } catch {
            notice = "The recent projects list couldn’t be saved: \(error.localizedDescription)"
        }
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
            volume: updated.premiereTemplateVolume, readOnly: true,
            fileExtension: PremiereTemplateService.fileExtension
        )
        if premiereTemplate != templateCheck.status { premiereTemplate = templateCheck.status }
        updated.premiereTemplateBookmarkData = templateCheck.renewedBookmark ?? updated.premiereTemplateBookmarkData
        updated.premiereTemplateVolume = templateCheck.volume
        if templateCheck.status.isReady, let url = templateCheck.status.url { updated.premiereTemplateURL = url }

        settings = updated
        refreshRecentProjects()
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

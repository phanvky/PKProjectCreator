import Foundation
import Observation

/// Single source of truth. Folder templates are saved to disk through `FolderTemplateStore`; everything else is in memory.
@Observable
final class AppState {
    var screen: AppScreen = .newProject
    var settings = AppSettings()
    var templates: [FolderTemplate]
    /// A load or save problem to show the user; nil when everything is fine.
    var storageNotice: String?
    var premiere = PremiereTemplateConfig()
    var drives = DriveInfo.known
    /// Sample rows only (see `RecentProject.samples`); real history arrives with persistence.
    var recentProjects = RecentProject.samples
    var draft = NewProjectDraft(type: .event, createPremiere: true)

    private let templateStore: FolderTemplateStore?

    /// Pass `nil` to keep templates in memory only (previews).
    init(templateStore: FolderTemplateStore? = FolderTemplateStore()) {
        self.templateStore = templateStore
        let loaded = templateStore?.load()
        templates = loaded?.templates ?? FolderTemplate.builtIn()
        storageNotice = loaded?.notice
        resetDraft()
    }

    // MARK: New project

    func resetDraft() {
        let type = settings.defaultProjectType
        draft = NewProjectDraft(type: type, templateID: defaultTemplate(for: type)?.id, createPremiere: premiere.copyOnCreate)
    }

    func startProject(like project: RecentProject) {
        resetDraft()
        draft.type = project.type
        draft.projectName = project.projectName
        draft.templateID = templates.first { $0.name == project.templateName }?.id ?? defaultTemplate(for: project.type)?.id
        screen = .newProject
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
            storageNotice = "Your template changes couldn’t be saved: \(error.localizedDescription)"
        }
    }

    // MARK: Drives

    func drive(forPath path: String) -> DriveInfo? {
        guard let name = path.volumeName else { return nil }
        return drives.first { $0.name == name }
    }
}

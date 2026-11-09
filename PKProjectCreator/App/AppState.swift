import Foundation
import Observation

/// Single source of truth for Phase 01. Everything here is in memory; nothing touches the disk.
@Observable
final class AppState {
    var screen: AppScreen = .newProject
    var settings = AppSettings()
    var templates = FolderTemplate.builtIn()
    var premiere = PremiereTemplateConfig()
    var drives = DriveInfo.known
    /// Sample rows only (see `RecentProject.samples`); real history arrives with persistence.
    var recentProjects = RecentProject.samples
    var draft = NewProjectDraft(type: .event, createPremiere: true)

    init() {
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

    func defaultTemplate(for type: ProjectType) -> FolderTemplate? {
        templates.first { $0.defaultTypes.contains(type) } ?? templates.first
    }

    /// A type belongs to exactly one template, so assigning it here removes it from the others.
    func assign(_ type: ProjectType, toTemplate id: FolderTemplate.ID) {
        for index in templates.indices {
            if templates[index].id == id {
                templates[index].defaultTypes.insert(type)
            } else {
                templates[index].defaultTypes.remove(type)
            }
        }
    }

    @discardableResult
    func duplicateTemplate(_ id: FolderTemplate.ID) -> FolderTemplate.ID? {
        guard let source = templates.first(where: { $0.id == id }) else { return nil }
        let copy = FolderTemplate(
            name: "\(source.name) Copy", summary: source.summary, folders: source.folders,
            defaultTypes: [], specifiedFolderCount: source.specifiedFolderCount
        )
        templates.append(copy)
        return copy.id
    }

    func addTemplate() -> FolderTemplate.ID {
        let template = FolderTemplate(name: "Untitled Template", summary: "", folders: [], defaultTypes: [])
        templates.append(template)
        return template.id
    }

    /// Keeps at least one template; orphaned default types move to the first remaining one.
    func removeTemplate(_ id: FolderTemplate.ID) {
        guard templates.count > 1, let index = templates.firstIndex(where: { $0.id == id }) else { return }
        let removed = templates.remove(at: index)
        templates[0].defaultTypes.formUnion(removed.defaultTypes)
        if draft.templateID == id {
            draft.templateID = defaultTemplate(for: draft.type)?.id
        }
    }

    // MARK: Drives

    func drive(forPath path: String) -> DriveInfo? {
        guard let name = path.volumeName else { return nil }
        return drives.first { $0.name == name }
    }
}

import Foundation

/// The form state of the New Project screen.
struct NewProjectDraft {
    var date = Date()
    var type: ProjectType
    var projectName = ""
    var templateID: FolderTemplate.ID?
    /// Turning this off is the explicit "folders only" choice.
    var createPremiere: Bool
}

extension AppState {
    var selectedTemplate: FolderTemplate? {
        templates.first { $0.id == draft.templateID } ?? templates.first
    }

    var generatedName: String {
        ProjectNaming.generatedName(date: draft.date, type: draft.type, projectName: draft.projectName)
    }

    /// Generated name, or the "[Project Name]" placeholder while the name is empty.
    var displayName: String {
        ProjectNaming.displayName(date: draft.date, type: draft.type, projectName: draft.projectName)
    }

    var nameIssue: ProjectNameIssue? {
        ProjectNaming.issue(forProjectName: draft.projectName, generatedName: generatedName)
    }

    var destinationFolder: String {
        ProjectNaming.destinationFolder(
            base: (destination.url ?? settings.defaultDestinationURL).plainPath,
            date: draft.date, useYearFolder: settings.useYearFolderFromProjectDate
        )
    }

    var projectPath: String { "\(destinationFolder)/\(displayName)/" }

    var premiereOutputPath: String {
        (premiere.destinationFolder + ["\(displayName).prproj"]).joined(separator: "/")
    }

    /// What the bottom bar says. Creation itself is not implemented yet.
    var creationStatus: StatusMessage {
        if let issue = nameIssue {
            return StatusMessage(text: issue.message, kind: issue == .empty ? .neutral : .danger)
        }
        if let template = selectedTemplate, !template.isConfigured {
            return StatusMessage(text: "“\(template.name)” needs configuration: add its folders in Folder Templates.", kind: .warning)
        }
        if let problem = destination.problem(item: "destination folder") {
            return StatusMessage(text: problem, kind: .warning)
        }
        if draft.createPremiere, let problem = premiereTemplate.problem(item: "Premiere template") {
            return StatusMessage(text: "\(problem) Or turn off “Create Premiere project from template”.", kind: .warning)
        }
        return StatusMessage(text: "Project creation will be enabled in a later phase.", kind: .neutral)
    }
}

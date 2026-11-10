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

    /// The one description of what Create Project will do. The preview and the creation both read it.
    var creationPlan: ProjectCreationPlan {
        let template = selectedTemplate
        return ProjectCreationPlan(
            date: draft.date, type: draft.type, projectName: draft.projectName,
            templateID: template?.id, templateName: template?.name ?? "", folders: template?.nodes ?? [],
            destinationFolderURL: destination.url ?? settings.defaultDestinationURL,
            useYearFolder: settings.useYearFolderFromProjectDate,
            createsPremiereProject: draft.createPremiere, premiereFolder: premiere.destinationFolder
        )
    }

    var generatedName: String { creationPlan.generatedName }

    /// Generated name, or the "[Project Name]" placeholder while the name is empty.
    var displayName: String {
        ProjectNameGenerator.displayName(date: draft.date, type: draft.type, projectName: draft.projectName)
    }

    var nameIssue: ProjectNameIssue? {
        ProjectNameGenerator.issue(forProjectName: draft.projectName, generatedName: generatedName)
    }

    var destinationFolder: String { creationPlan.yearFolderURL.plainPath }

    var projectPath: String { "\(destinationFolder)/\(displayName)/" }

    var premiereOutputPath: String {
        (premiere.destinationFolder + ["\(displayName).prproj"]).joined(separator: "/")
    }

    /// Why Create Project is unavailable right now, or nil when it can run.
    var creationBlocker: StatusMessage? {
        if let issue = nameIssue {
            return StatusMessage(text: issue.message, kind: issue == .empty ? .neutral : .danger)
        }
        if let template = selectedTemplate, !template.isConfigured {
            return StatusMessage(text: "“\(template.name)” needs configuration: add its folders in Folder Templates.", kind: .warning)
        }
        if let problem = destination.problem(item: "destination folder") {
            return StatusMessage(text: problem, kind: .warning)
        }
        if draft.createPremiere {
            if let problem = premiereTemplate.problem(item: "Premiere template") {
                return StatusMessage(text: "\(problem) Or turn off “Create Premiere project from template”.", kind: .warning)
            }
            // Phase gate: remove once the Premiere template copy exists (Phase 05).
            return StatusMessage(
                text: "Creating the Premiere project isn’t available yet. Turn off “Create Premiere project from template” to create the folders only.",
                kind: .warning
            )
        }
        return nil
    }

    /// What the bottom bar says.
    var creationStatus: StatusMessage {
        if creationTask != nil { return StatusMessage(text: "Creating “\(generatedName)”…", kind: .neutral) }
        let plan = creationPlan
        return creationBlocker ?? StatusMessage(
            text: "Ready to create \(plan.directoryCount) folders in \(plan.yearFolderURL.lastPathComponent).", kind: .success
        )
    }
}

# Architecture

Native SwiftUI app, Swift 6, macOS 26+, no third-party dependencies. The Xcode project uses **file-system synchronized groups**: any `.swift` file placed under `PKProjectCreator/` or `PKProjectCreatorTests/` is compiled automatically — no `project.pbxproj` edits needed.

Build settings of note: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (everything is main-actor unless marked `nonisolated`), App Sandbox on, user-selected files read-only (must become read-write in the filesystem phase). Saving templates needs no entitlement change: Application Support resolves inside the app's own sandbox container.

## Folder map
```
PKProjectCreator/
  App/            App entry (single Window, ⌘N / ⌘, commands), AppState, AppScreen, AppRootView
  DesignSystem/   Theme.swift (tokens, StatusKind) + Components/ (FormCard, FormRow, ToggleRow, InfoRow,
                  SectionHeader, StatusDot/Label/Badge, ValidationMessage, TagLabel, ChipButtonStyle,
                  BottomActionBar, PathBreadcrumb)
  Models/         ProjectType, FolderNode (+ tree editing and moves), FolderTemplate (+ validated folder edits,
                  built-in templates), RecentProject (+ sample data), DriveInfo, PremiereTemplateConfig, AppSettings
  Services/       FolderTemplateStore (folder-templates.json: load, save, backup, recovery)
  Shared/
    Components/   FolderTreeView (used by New Project preview and the template editor)
    Utilities/    ProjectNaming (name format + validation + destination), FolderNaming (folder-name rules,
                  FolderEditIssue), String+Path
  Features/
    Sidebar/          SidebarView, DriveStatusCard
    NewProject/       NewProjectView, NewProjectDraft (+ derived values on AppState), FolderPreviewPanel,
                      CreationResultDialogs (design-only previews)
    RecentProjects/   RecentProjectsView (Table + inspector), RecentProjectInspector
    FolderTemplates/  FolderTemplatesView, FolderTemplateEditor
    PremiereTemplate/ PremiereTemplateView
    Settings/         SettingsView
PKProjectCreatorTests/   Swift Testing unit tests
Documentation/           Specs, plan, DesignReferences/
```

## State
- One `@Observable AppState` injected with `.environment`. Holds navigation (`screen`), the New Project `draft`, templates, Premiere config, drives, settings and recent projects.
- Templates are the only saved data so far. `AppState.init` loads them through `FolderTemplateStore`; every template change goes through `AppState.updateTemplate` (or the add / duplicate / remove / `setDefault` methods), which saves right after. Load and save problems land in `AppState.storageNotice`, shown as an alert by `AppRootView`. `AppState(templateStore: nil)` keeps everything in memory (previews and most tests).
- Template rules live in the models, not the views: `FolderTemplate.nodes` keeps `isConfigured` in step with "has at least one folder" and drops defaults when it becomes false; `FolderTemplate.normalized` repairs loaded data.
- The Folder Templates editor and the New Project preview both render `FolderTemplate.nodes` through `FolderTreeView` — there is no second copy of any hierarchy.
- Derived values (generated name, validation issue, paths, bottom-bar status) are computed properties in `NewProjectDraft.swift` — no duplicated state.
- Pure value logic (`ProjectNaming`, `ProjectType`, `RecentProject`, `String` helpers) is `nonisolated` so it can be used from any context and in `Table` sort comparators.

## Rules for new code
- New screens go in `Features/<Name>/`; reusable visual pieces in `DesignSystem/Components/`; domain-aware reusable views in `Shared/Components/`.
- Filesystem work goes in `Services/`, called from AppState — views never touch `FileManager`.
- Reuse `FormCard` / `FormRow` / `StatusKind` instead of new styling.

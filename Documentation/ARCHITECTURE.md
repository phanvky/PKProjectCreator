# Architecture

Native SwiftUI app, Swift 6, macOS 26+, no third-party dependencies. The Xcode project uses **file-system synchronized groups**: any `.swift` file placed under `PKProjectCreator/` or `PKProjectCreatorTests/` is compiled automatically — no `project.pbxproj` edits needed.

Build settings of note: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (everything is main-actor unless marked `nonisolated`), App Sandbox on, user-selected files read-only (must become read-write in the filesystem phase).

## Folder map
```
PKProjectCreator/
  App/            App entry (single Window, ⌘N / ⌘, commands), AppState, AppScreen, AppRootView
  DesignSystem/   Theme.swift (tokens, StatusKind) + Components/ (FormCard, FormRow, ToggleRow, InfoRow,
                  SectionHeader, StatusDot/Label/Badge, ValidationMessage, TagLabel, ChipButtonStyle,
                  BottomActionBar, PathBreadcrumb)
  Models/         ProjectType, FolderNode (+ tree editing), FolderTemplate, RecentProject (+ sample data),
                  DriveInfo, PremiereTemplateConfig, AppSettings
  Shared/
    Components/   FolderTreeView (used by New Project preview and the template editor)
    Utilities/    ProjectNaming (name format + validation + destination), String+Path
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
- Derived values (generated name, validation issue, paths, bottom-bar status) are computed properties in `NewProjectDraft.swift` — no duplicated state.
- Pure value logic (`ProjectNaming`, `ProjectType`, `RecentProject`, `String` helpers) is `nonisolated` so it can be used from any context and in `Table` sort comparators.

## Rules for new code
- New screens go in `Features/<Name>/`; reusable visual pieces in `DesignSystem/Components/`; domain-aware reusable views in `Shared/Components/`.
- Filesystem work (Phase 02+) goes in a new `Services/` folder, called from AppState — views never touch `FileManager`.
- Reuse `FormCard` / `FormRow` / `StatusKind` instead of new styling.

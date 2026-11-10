# Architecture

Native SwiftUI app, Swift 6, macOS 26+, no third-party dependencies. The Xcode project uses **file-system synchronized groups**: any `.swift` file placed under `PKProjectCreator/` or `PKProjectCreatorTests/` is compiled automatically — no `project.pbxproj` edits needed.

Build settings of note: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (everything is main-actor unless marked `nonisolated`), App Sandbox on, hardened runtime on.

## Permission model
- The app stays sandboxed. Its only file entitlement is `com.apple.security.files.user-selected.read-write` (build setting `ENABLE_USER_SELECTED_FILES = readwrite`, changed from `readonly` in Phase 03 because the destination folder must be writable). There is no entitlements file; Xcode generates it from build settings.
- The app can reach exactly two things outside its container: the destination folder and the Premiere template file, each picked by the user in `NSOpenPanel`. No Full Disk Access, no whole-drive access, no temporary exceptions.
- Each pick is stored as an app-scoped security-scoped bookmark (`.withSecurityScope`; the template adds `.securityScopeAllowOnlyReadAccess`). Bookmarks are resolved with `[.withSecurityScope, .withoutMounting]`. Checked on macOS 26: this works without `com.apple.security.files.bookmarks.app-scope`.
- All of it goes through `FileAccessService`. `withAccess(to:)` resolves the bookmark, starts security-scoped access, runs the work and stops access in a `defer`. Future file operations (project creation, template copy) must use it.
- Settings and templates need no permission: Application Support resolves inside the app's own container.

## Folder map
```
PKProjectCreator/
  App/            App entry (single Window, ⌘N / ⌘, commands), AppState, AppScreen, AppRootView
  DesignSystem/   Theme.swift (tokens, StatusKind) + Components/ (FormCard, FormRow, ToggleRow, InfoRow,
                  SectionHeader, StatusDot/Label/Badge, ValidationMessage, TagLabel, ChipButtonStyle,
                  BottomActionBar, PathBreadcrumb)
  Models/         ProjectType, FolderNode (+ tree editing and moves), FolderTemplate (+ validated folder edits,
                  built-in templates), RecentProject (+ sample data), AppSettings (saved preferences),
                  ResourceStatus (VolumeIdentity, ResourceState, ResourceStatus, DriveInfo), PremiereTemplateConfig,
                  ProjectCreationPlan (what one creation will do)
  Services/       FolderTemplateStore (folder-templates.json: load, save, backup, recovery),
                  SettingsStore (settings.json), FileAccessService (bookmarks, access, resource checks;
                  ResourceAccess protocol + SystemResourceAccess; OpenPanels),
                  ProjectCreationService (staging folder → rename; ProjectCreationError),
                  PremiereTemplateService (validate, copy and verify the master; PremiereTemplateError)
  Shared/
    Components/   FolderTreeView (used by New Project preview and the template editor)
    Utilities/    ProjectNameGenerator (name format + validation + destination), FolderNaming (folder-name rules,
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
- Saved data: settings (`SettingsStore`) and templates (`FolderTemplateStore`). `AppState.settings` saves itself in `didSet`. `AppState(directory: nil)` keeps everything in memory (previews and most tests).
- `AppState.destination` and `AppState.premiereTemplate` are `ResourceStatus` values produced by `FileAccessService.check`. `refreshResources()` recomputes both; `AppRootView` calls it on volume mount / unmount / rename and when the app becomes active. Views read these two values and never decide readiness from a path string.
- Tests replace macOS with a fake `ResourceAccess` (volumes, permissions, stale bookmarks), so they never need the real drives.
- `AppState.init` loads templates through `FolderTemplateStore`; every template change goes through `AppState.updateTemplate` (or the add / duplicate / remove / `setDefault` methods), which saves right after. Load, save and permission problems land in `AppState.notice`, shown as an alert by `AppRootView`.
- Template rules live in the models, not the views: `FolderTemplate.nodes` keeps `isConfigured` in step with "has at least one folder" and drops defaults when it becomes false; `FolderTemplate.normalized` repairs loaded data.
- The Folder Templates editor and the New Project preview both render `FolderTemplate.nodes` through `FolderTreeView` — there is no second copy of any hierarchy.
- Derived values (generated name, validation issue, paths, bottom-bar status) are computed properties in `NewProjectDraft.swift` — no duplicated state.
- Pure value logic (`ProjectNameGenerator`, `ProjectType`, `RecentProject`, `String` helpers) is `nonisolated` so it can be used from any context and in `Table` sort comparators.

## Project creation
- `AppState.creationPlan` builds one immutable `ProjectCreationPlan` from the draft, settings, selected template and destination. `FolderPreviewPanel`, the paths on New Project and `ProjectCreationService` all read that plan; no view computes a folder structure of its own.
- `AppState.creationBlocker` is the single list of reasons Create Project is disabled (bad name, unconfigured template, destination not ready, Premiere template not ready or its Copy Into folder missing from the folder template). The service repeats the checks that matter before touching the disk.
- `AppState.createProject()` runs `FileAccessService.withAccess(to:)` (async form) on the main actor, which keeps security-scoped access open while `ProjectCreationService.create` — `nonisolated`, `@concurrent` — does the disk work off the main actor. Cancelling the task makes the service stop, clean up and throw `.cancelled`.
- With Premiere on, `createProject()` nests a second `withAccess` for the template bookmark inside the destination one, so both permissions stay open for the whole creation. `ProjectCreationService` validates the master before writing anything, then calls `PremiereTemplateService.copy` into the staging tree after the folders and before the final rename.
- The output name comes from `PremiereTemplateService.outputFilename(for: plan.generatedName)`; `ProjectCreationPlan.premiereOutputRelativePath` uses the same function, so preview and result can't differ.
- `FileAccessService.check(..., fileExtension:)` adds the file checks (extension, regular file, readable) for the template; `ResourceStatus.templateLabel` gives the Premiere wording.
- `AppState.openInPremiere` reopens the destination's security scope, asks `NSWorkspace.urlForApplication(toOpen:)` for the registered app and opens the file with it. Errors only set `notice`.
- The service receives the URL macOS resolved from the bookmark and places the plan's relative parts (year folder, project name) under it; it never rebuilds a path from saved text.
- `FolderNode`, `ProjectCreationPlan`, `RecentProject` and the name / folder rules are `nonisolated` and `Sendable` so they can cross to the background.

## Rules for new code
- New screens go in `Features/<Name>/`; reusable visual pieces in `DesignSystem/Components/`; domain-aware reusable views in `Shared/Components/`.
- Filesystem work goes in `Services/`, called from AppState — views never touch `FileManager`.
- Reuse `FormCard` / `FormRow` / `StatusKind` instead of new styling.

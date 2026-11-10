# Development Plan

## Phase 01 — UI foundation ✅
All five screens, sidebar, design system, live name preview + validation, static folder preview, in-memory template editing, sample recent projects, design-only success / drive-not-connected dialogs.
Not done on purpose: no disk access, no persistence, Create Project stays disabled, drive/template status shows "Not checked".

## Phase 02 — Folder template engine ✅
Codable `FolderNode` / `FolderTemplate` with stable IDs and unlimited nesting; folder-name validation; add / rename / delete / reorder / drag-to-move folders; create / duplicate / rename / delete templates; project-type defaults; templates saved to `folder-templates.json` (schema version, atomic write, backup, damaged-file recovery); Folder Templates screen and New Project preview read the same saved data.
Not done on purpose: template description can't be edited in the app; drag and drop moves a folder *into* another folder or to the top level, while ordering among siblings uses the Move Up / Move Down buttons; no undo.

## Phase 03 — Settings storage & external drive access ✅
`AppSettings` saved to `settings.json` (schema version, atomic write, safe defaults); destination folder and Premiere template chosen through `NSOpenPanel` and remembered as security-scoped bookmarks; one `FileAccessService` for all bookmark work; independent live status for the destination drive and the template drive (mount / unmount / rename notifications); Choose, Reauthorize, Clear and Reveal in Finder; sandbox entitlement changed from user-selected read-only to read-write.
Not done on purpose: no project creation and no Premiere copy yet; the "Copy Into" folder choice on the Premiere screen is still in memory only; recent projects are still sample data.

## Phase 04 — Project creation engine ✅
`ProjectNameGenerator` (renamed from `ProjectNaming`); immutable `ProjectCreationPlan` shared by the preview and the creation; `ProjectCreationService` builds the folder tree in a staging folder and renames it into place (never overwrites, never merges, cleans up on failure or cancellation); New Project creates real folders with progress, Cancel, duplicate / permission errors and the success dialog; `RecentProject` is Codable, ready for saving.
Not done on purpose: no Premiere copy. While "Create Premiere project from template" is on, Create Project is disabled and says why; folders-only creation needs it turned off. Created projects are not added to Recent Projects yet (that list is still sample data).

## Phase 05 — Premiere template copy (recommended next)
- Copy the `.prproj` into the staging folder before the final rename (copy, never modify the source), named `[Generated Name].prproj`, inside the "Copy Into" folder.
- Remove the phase gate in `AppState.creationBlocker` and `ProjectCreationService.create`.
- Open in Premiere Pro after creating.

## Phase 06 — Recent projects persistence
- Recent projects list (limit from Settings), verify each path on launch.

## Phase 07 — Polish & distribution
- Reels — Lite hierarchy (once supplied; it can already be entered by hand in Folder Templates), keyboard shortcuts, accessibility pass, app icon, signing/notarization, DMG.

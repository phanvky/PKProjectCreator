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

## Phase 05 — Premiere Pro template engine ✅
`PremiereTemplateService` validates the master (exists, regular file, readable, `.prproj`), copies it into the staging project's Copy Into folder as `{Generated Name}.prproj` and verifies the copy byte for byte; the copy is one step of the Phase 04 transaction, so a failed copy leaves nothing behind. Template states (ready to copy, missing, drive disconnected, permission denied, bookmark stale, invalid file) are tracked independently of the destination drive. Open in Premiere Pro uses the app macOS has registered for `.prproj`; a launch failure is only reported. The Phase 04 gate is removed.
Not done on purpose: created projects are still not added to Recent Projects; the Copy Into folder choice is still in memory only.

## Phase 06 — Recent projects & settings persistence ✅
`recent-projects.json` filled only by successful creations (no drive scanning; sample data removed); each record keeps a bookmark of the project folder and its volume identifier. Recent Projects: search, type filter, date sort, details, Reveal in Finder, Open in Premiere Pro, Copy Path, New Project Like This, Remove from List (metadata only, with confirmation), live status (available / drive disconnected / missing / permission needed) with Retry. Limit from Settings (default 20) keeps the newest. One `JSONFileStore` now gives settings, templates and recent projects the same schema version, atomic write, backup, damaged-file recovery and migration hook.
Not done on purpose: the Copy Into folder choice on Premiere Template is still in memory only.

## After Phase 06 (user requests) ✅
DaVinci Resolve template (copy `.drp`, set its project name; Working Folders left as in the master) and Update Project (add folders, rename/delete only empty folders, add a missing Premiere/Resolve file; never move or delete content). Merged to `main`.

## Phase 07 — End-to-end testing, hardening & optimization ✅
Full QA pass: Debug and Release builds without warnings, 86 tests, drive matrix A–K, scripted end-to-end run on a virtual drive, filesystem-safety review, performance check. Fixes: template folder names re-validated (no writing outside the project), non-recursive empty-folder removal, central plain-language file errors, folders-only confirmation when the Premiere template isn't ready, success dialog lists the Resolve file. See `QA_REPORT.md` and `MANUAL_TEST_CHECKLIST.md`.

## Phase 08 — Polish & distribution (recommended next)
- Reels — Lite hierarchy (once supplied; it can already be entered by hand in Folder Templates), keyboard shortcuts, accessibility pass, app icon, signing/notarization, DMG.

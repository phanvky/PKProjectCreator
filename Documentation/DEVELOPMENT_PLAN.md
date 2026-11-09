# Development Plan

## Phase 01 — UI foundation ✅ (this phase)
All five screens, sidebar, design system, live name preview + validation, static folder preview, in-memory template editing, sample recent projects, design-only success / drive-not-connected dialogs.
Not done on purpose: no disk access, no persistence, Create Project stays disabled, drive/template status shows "Not checked".

## Phase 02 — Filesystem foundation (recommended next)
- Change sandbox entitlement to user-selected read-write.
- Folder pickers (`NSOpenPanel`) for destination and Premiere template; security-scoped bookmarks saved in UserDefaults.
- Real volume status for KIOXIA / WORK (mounted check + `NSWorkspace` mount/unmount notifications).
- Real template-file check (exists / readable).
- Wire Reveal in Finder.

## Phase 03 — Project creation
- Create folder tree atomically (create in temp name, rename on success; never overwrite an existing folder).
- Copy `.prproj` (copy, never modify source); honour the "block if missing" policy.
- Success / error dialogs from `CreationResultDialogs.swift`.
- Open in Premiere Pro, Reveal in Finder, clear name option.

## Phase 04 — Persistence
- Folder templates as JSON (Codable) in Application Support.
- Recent projects list (limit from Settings), verify each path on launch.
- Settings in UserDefaults.

## Phase 05 — Polish & distribution
- Reels — Lite hierarchy (once approved), keyboard shortcuts, accessibility pass, app icon, signing/notarization, DMG.

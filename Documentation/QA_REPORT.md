# QA Report — Phase 07

Date: 2026-11-10 · Branch: `phase-07-qa` (from `main` a9605fc) · Tester: Claude (automated + scripted UI on a virtual drive)

## Build configuration
| Item | Value |
|---|---|
| Xcode project | `PKProjectCreator.xcodeproj`, scheme `PKProjectCreator` |
| Swift | 6.0 language mode (complete concurrency checking), default actor isolation `MainActor` |
| Minimum macOS | 26.0 (`MACOSX_DEPLOYMENT_TARGET`) |
| Architecture | arm64 (Apple Silicon) |
| Sandbox | App Sandbox on; user-selected files read/write; no network entitlement |
| Third-party dependencies | None (system frameworks only; `otool -L` shows only `/System` and `/usr/lib`) |
| Debug build | ✅ succeeded, 0 warnings |
| Release build | ✅ succeeded, 0 warnings |

## Automated tests — 86 passed, 0 failed
| Suite | Tests | Covers |
|---|---|---|
| ProjectNameGeneratorTests | 7 | name format, placeholder, invalid names, NUL / "/" / ":" |
| FolderTemplateTests / FolderTemplateStoreTests | 17 / 3 | template engine, nesting, rename, move, duplicates, persistence, corruption recovery |
| FileAccessTests | 8 | bookmarks, stale renewal, drive identity by UUID, independent drives, permission failures |
| SettingsStoreTests | 3 | defaults, restart, damaged file |
| ProjectCreationTests | 9 | staging, exact structure, Vietnamese names, no overwrite/merge, rollback, cancellation |
| PremiereTemplateTests | 13 | copy + verify, bad sources, collisions, master unchanged, drive matrix A–D, Resolve copy + rename |
| RecentProjectsTests | 9 | record, remove (list only), limit, disconnected/missing kept, migration |
| ProjectUpdateTests | 7 | scan, empty-only rename/delete, files only when missing, partial failure |
| HardeningTests (new) | 10 | Vietnamese + punctuation names, damaged template paths, error wording, non-recursive delete, full drive during copy |

## Test matrix
| Case | Result | How |
|---|---|---|
| A. Both drives connected | ✅ | Unit (fake volumes) + real run on a virtual drive |
| B. KIOXIA off, WORK on | ✅ | Unit: destination "disconnected", template "Ready to copy", Create disabled |
| C. WORK off, KIOXIA on | ✅ | Unit: template "WORK disconnected", Create blocked while Premiere is on |
| D. Both off | ✅ | Unit: both reported, `createProject()` starts no task, nothing written |
| E. Project already exists | ✅ | Unit + real: blocked with a clear message; existing project and its files untouched |
| F. Invalid project name | ✅ | Unit: message shown, Create disabled, disk untouched |
| G. Vietnamese name (`PSC Tùng & Thảo`) | ✅ | Unit + real: folder, `.prproj`, `.drp` and Resolve `<ProjectName>` (`&amp;`) exact |
| H. `&`, `( )`, `'`, `-`, digits, diacritics | ✅ | Unit (parameterised): every character kept |
| I. Template missing | ✅ | Create blocked while "Create Premiere project" is on; folders only needs unticking it **and** confirming a dialog (new in this phase) |
| J. Drive fails during copy | ✅ | Unit: out-of-space / failure injected at the copy step → clear message, staging removed, master and existing projects unchanged |
| K. Permission revoked | ✅ | Unit: "Permission denied / needed" with Reauthorize guidance; nothing bypasses the sandbox |

## End-to-end run (Release build, scripted, virtual exFAT drive `PKTEST`)
Steps 1–19 of the brief passed: launch → saved settings → destination and WORK templates resolved → date/type/name → generated name → preview → validation → staging → 18 folders → Premiere and Resolve copies (Premiere byte-identical; Resolve name set) → rename into place (no staging left) → Recent Projects record → success dialog → Reveal in Finder. Step 20 (open Premiere Pro) was **not** run, to avoid launching Premiere. The success dialog appears only after the final rename; every failure path tested ends with an error alert and no dialog.

The user's real settings, templates and recent-projects files were backed up before and restored byte-for-byte after; KIOXIA was never written to.

## Filesystem safety review
Every create / copy / move / delete call was read (`ProjectCreationService`, `PremiereTemplateService`, `ProjectUpdateService`, `JSONFileStore`).
- No overwrite: copies refuse an existing target; the final step is a rename that fails if the name appeared meanwhile.
- Recursive delete is used only on the operation's own staging folder (`.PKProjectCreator-Staging-<UUID>`, created by the same call) and on the app's temporary folder inside its container.
- **Fixed:** the year folder cleanup and Update Project deletes now use `removeEmptyFolder` (Finder metadata removed, then `rmdir`), which the system refuses for a folder with anything inside.
- **Fixed:** folder names loaded from `folder-templates.json` are re-checked before creation, so a hand-edited `..` or `a/b` can't write outside the project.
- Paths are built with `URL.appending(path:)` from validated components, never by joining strings typed by the user.
- Masters (`.prproj`, `.drp`) are only read: read-only bookmarks, the Resolve rewrite happens on the copy.
- Success is reported only after the commit (`ProjectCreationService.create` returns after the rename).

## Error handling
`FileErrorText.describe` is now the one place that turns system errors into plain explanations: out of space, no permission (with "reauthorize"), read-only drive, file/drive gone, name exists. The raw system text appears only in brackets after an explanation. Covered messages: destination unavailable, template unavailable, permission denied, invalid name, duplicate project, insufficient storage, copy failure, folder creation failure, bookmark resolution failure, staging cleanup failure (with the leftover path).

## Performance (Release build, Apple Silicon)
- Idle CPU 0.0 %; switching screens repeatedly stays at 0 %; physical footprint ≈ 58 MB (peak 62 MB).
- No timers, polling, network calls, thumbnails or media processing. Status re-checks run only on volume mount / unmount / rename notifications and when the app becomes active (plus one re-check 1.5 s later).
- Disk work (creation, update, scanning) runs off the main actor (`@concurrent`). The only disk scan is Update Project's, started by the user and limited to 4 levels.

## Changes made in this phase
- Path-safety check for template folder names; non-recursive empty-folder removal; central error wording.
- Folders-only confirmation when the Premiere template isn't ready.
- Success dialog now lists the DaVinci Resolve file too.
- 10 new hardening tests; drive matrix A and D added to the existing drive test.

## Known limitations
- Resource and recent-project status checks run on the main actor. They are fast (bookmark resolution without mounting), but with 100 recent projects on a slow drive a refresh could take noticeable time.
- A duplicate project name is detected when Create Project is clicked, not while typing (it is then refused safely).
- The Copy Into folder choice (Premiere and Resolve) is not saved between launches.
- Recent Projects shows Premiere status but not the DaVinci Resolve file.
- The DaVinci Resolve name rewrite depends on Resolve's undocumented `.drp` format (checked with Resolve Studio 21); a future format change makes creation fail safely rather than produce a broken file.
- No app icon, signing, notarization or installer yet.

## Remaining risks
- Real drive unplugging during a copy was simulated, not physically performed (see the manual checklist).
- "Open in Premiere Pro" has never been clicked in testing.
- The saved destination is still `KIOXIA/PROJECT VIDEO/EVENT/2026` with the year-folder option on, which creates `…/2026/2026/…`. The user should choose `EVENT`.

## Manual tests still required
See `Documentation/MANUAL_TEST_CHECKLIST.md`: physical KIOXIA / WORK disconnect and reconnect, remount under a different name, permission renewal, and unplugging during creation.

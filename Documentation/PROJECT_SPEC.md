# PKProjectCreator — Product Spec

Offline macOS app for PHANKY FILM that creates video project folders from templates and copies a Premiere Pro master project into each one. No cloud, server, account or remote database.

## Core features
1. Create project folders from a folder template.
2. Generated project name: `yyyy - MM - dd` + Project Type + Project Name — e.g. `2026 - 11 - 12 Event Develon`.
3. Copy the `.prproj` master template into `04_Project/Premiere Pro/` as `[Generated Name].prproj`.
4. Manage folder templates and the Premiere master template.
5. Browse recent projects.
6. Remember destinations and external-drive permissions (security-scoped bookmarks).

## Project types
Event, PSC, PSH, Tour, Golf Tournament, TVC, Reels.

## Naming rules
- User text is never rewritten; it is validated.
- Rejected: empty / whitespace-only, `/`, `:`, control characters, final `.prproj` name over 255 UTF-8 bytes.
- Vietnamese Unicode, spaces, `&`, `( )`, `'`, `-` are allowed.

## Locations
- Suggested project destination: `/Volumes/KIOXIA/PROJECT VIDEO/EVENT`. With "Use year folder from project date" on, the year of the project date is appended at the time of use: `…/EVENT/2026`. The `EVENT` folder does not change with project type.
- Suggested Premiere master: `/Volumes/WORK/TÀI NGUYÊN /PREMIERE PRO/PROJECT MODEL/Project/Year - Month - Day - Name 2026.prproj` (note the space after `NGUYÊN`).
- Both are only **suggested locations** until the user chooses them in a macOS file dialog. Choosing is what authorizes them; the app then shows **Authorized location**. A path that merely exists is never treated as usable.
- The template must be a `.prproj` file. It is authorized read-only and is never modified. It can be replaced or cleared.
- The destination and the template are tracked independently, each with one of these states: connected and authorized · connected, permission needed · disconnected · permission expired (stale bookmark that couldn't be renewed) · not found · not selected.
- Drives are recognized by volume identifier and by where the saved bookmark resolves, not by name or mount path. Both resources are re-checked at launch, after a choice, when any volume is mounted, unmounted or renamed, and when the app becomes active.

## Settings
Saved in `settings.json`, next to `folder-templates.json` (see Template storage for the real path). Format: `{ "schemaVersion": 1, "settings": {...} }`, atomic write after every change. Missing or invalid values fall back to safe defaults; an unreadable file is kept as `settings.damaged.json` and the user is told.

Fields: `defaultProjectType`, `defaultDestinationURL`, `destinationBookmarkData`, `destinationVolume`, `useYearFolderFromProjectDate`, `premiereTemplateURL`, `premiereTemplateBookmarkData`, `premiereTemplateVolume`, `createPremiereProjectByDefault`, `openFinderAfterCreation`, `openPremiereAfterCreation`, `clearProjectNameAfterCreation`, `maximumRecentProjects`. Nothing confidential is stored; bookmark data is a macOS permission token that only this app can use.

## Folder templates
**Standard Production** — 18 folders, 19 with root. Default for Event, PSC, PSH, Tour, Golf Tournament, TVC.
```
01_Footages/  Cam 01, Cam 02, Flycam, FPV, Cam 360, Action Cam
02_Music/
03_SFX/
04_Project/   Premiere Pro, DaVinci Resolve, After Effects
05_AI/        Images, Video
06_Graphic/
07_Export/
```
**Reels — Lite** — planned with 9 folders including root, but the hierarchy has **not been supplied — do not invent it**. It ships with no folders, is shown as "Needs configuration", and is not a default for any type until the user adds its folders.

### Template rules
- A template is *configured* (usable) once it has at least one folder. Only configured templates can be defaults.
- A project type has at most one default template. A type with none (Reels, today) uses the first configured template.
- The last configured template can't be deleted, and its last folder can't be removed.
- Folders are identified by a stable ID, never by name. Nesting depth is unlimited.
- Folder names are validated, never rewritten. Rejected: empty / whitespace-only, `/`, `:`, control characters, `.` and `..`, over 255 UTF-8 bytes, and a name already used by a sibling (ignoring letter case, as Mac volumes do). The same name under a different parent is fine. No Windows-only restrictions.
- A folder can't be moved into itself or into one of its own subfolders.
- Deleting a folder or a template asks for confirmation.

### Template storage
- `folder-templates.json` in Application Support/PKProjectCreator. The app is sandboxed, so the real path is `~/Library/Containers/com.phankyfilm.PKProjectCreator/Data/Library/Application Support/PKProjectCreator/`.
- Format: `{ "schemaVersion": 1, "templates": [...] }`. Every change is saved immediately with an atomic write.
- Built-in templates are written only when no file and no backup exist (first launch). An existing file is never replaced by defaults.
- `folder-templates.backup.json` holds the last valid file from before the latest save.
- A file that can't be read (damaged, or saved by a newer app version) is moved to `folder-templates.damaged.json`, the backup is loaded (or the built-in templates if there is none), and the user is told.

## Project creation
- The project is created at `{destination}/{yyyy}/{Generated Name}/` (or `{destination}/{Generated Name}/` with the year folder off). The year folder is created if it doesn't exist yet.
- Choose the folder that should contain the year folders (e.g. `EVENT`) as the destination, not a year folder itself: choosing `EVENT/2026` with the year folder on creates `EVENT/2026/2026/…`.
- The folders created are exactly the selected template's folders: 18 for Standard Production, 19 directories with the project root. Nothing else.
- An existing project is never overwritten and never merged into: if a folder with the generated name already exists (letter case ignored, as on Mac volumes), creation is refused.
- Creation is all-or-nothing. The tree is built in a hidden staging folder (`.PKProjectCreator-Staging-{UUID}`) next to the final location and renamed into place only at the end. On failure or cancellation the staging folder is removed, a year folder made by this run is removed if still empty, and nothing else is touched. If the staging folder can't be removed, the error says where it is.
- Checked before anything is written: project name, template has folders, destination authorized, reachable and writable, no duplicate.
- With "Create Premiere project from template" on, the project gets the Premiere copy or is not created at all. It never silently falls back to folders only; folders only happens only when the user turns that option off.
- Safe manual test: make an empty folder (e.g. `PK Test` on the Desktop), choose it as the destination with **Choose Another…**, type a name, click **Create Project**. Check the 18 folders and `04_Project/Premiere Pro/{Generated Name}.prproj` in Finder. Afterwards choose the real destination (`EVENT`) again and delete `PK Test`.

## Premiere template copy
- The master is the `.prproj` the user chose and authorized (read-only) on Premiere Template; the suggested WORK path is never used without that.
- It is copied into the project's Copy Into folder (default `04_Project/Premiere Pro/`) as `{Generated Name}.prproj`, the same generated name as the project folder, during creation and before the project is moved into place.
- The copy is checked (same size, same bytes). If anything fails, the whole project is rolled back and the error says what to do.
- The master is only ever read: never renamed, moved, deleted, modified, or given new metadata. Its bookmark is read-only, so macOS itself would refuse a write.
- Template states: Ready to copy · Template missing · {drive} disconnected · Permission denied / needed · Bookmark stale · Invalid template file (wrong extension or a folder) · Not selected. They are independent of the destination drive.
- Open in Premiere Pro (after creating, or from the success dialog) opens the copy with the app macOS has registered for `.prproj`. If there is none or it fails to launch, the user is told; the project is kept.

## Missing Premiere template policy
Block creation until the template is available. Creating folders only requires the user to explicitly turn off "Create Premiere project from template". Incomplete projects are never created silently.

## Design reference
`Documentation/DesignReferences/` — 5 screens + 3 states (drive not connected, project created, validation error + missing template). Dark graphite, native macOS controls, restrained blue accent.

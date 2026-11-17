# PKProjectCreator 1.0.3 (build 4) — 2026-11-18

- **DaVinci Resolve Working Folders:** the copied `.drp` now has Project media location, Proxy generation location and Cache files location set to the project's own `DaVinci Resolve` folder (e.g. `…/07_Project/DaVinci Resolve`), for new projects and for Update Project. Confirmed by importing into Resolve 21.
- Gallery stills location can't be set from the file: Resolve sets it from the project library on import. Change it by hand in Project Settings if needed.
- Adds the official zstd 1.5.7 library (built into the app) to read and write Resolve's compressed settings.

# PKProjectCreator 1.0.2 (build 3) — 2026-11-15

- **Edit folders per project:** Folder Preview on New Project has the folder toolbar (add, subfolder, move, rename, delete, drag onto another folder). Changes apply to that project only; Reset to Template undoes them. Switching to another template asks before discarding them.
- **Your own project types:** Settings › General › Project Types (add, rename, delete, reorder), also reachable from the ✏️ next to Project Type. Renaming updates folder templates and the default type; projects already created keep their names.
- **Copy Into is saved** between launches, follows a folder that is renamed or moved, and finds renumbered folders (e.g. `04_Project` → `07_Project`), so the Premiere and Resolve files always land in the project folder.
- Built-in Standard Production (used on a fresh install) is the 2026-11-15 structure: `01_Footages` (Cam 01, Cam 02, Flycam, FPV, Cam 360, Action Cam), `02_Voice`, `03_Music`, `04_SFX`, `05_Graphic`, `06_AI` (Images, Video), `07_Project` (Premiere Pro, DaVinci Resolve, After Effects), `08_Export`. Saved templates are not changed.
- Suggested Premiere master on a fresh install: `Project Teamplate 27.0.prproj`.
- Known: Update Project doesn't yet match renumbered folders.

# PKProjectCreator 1.0.1 (build 2) — 2026-11-10

- App icon: the approved PHANKY "Creator Project" artwork, fitted to the macOS icon grid (824 px tile in 1024, transparent rounded corners) in all ten sizes. The supplied square artwork had a solid black background, which would have shown as black corners.
- No other changes.

# PKProjectCreator 1.0.0 (build 1) — 2026-11-10

First release for PHANKY FILM. Offline macOS app (Apple Silicon, macOS 26+) that creates video project folders from templates.

## What it does
- **New Project:** date, project type and name give the generated name `yyyy - MM - dd Type Name` (Vietnamese and punctuation kept). Shows a live folder preview. Creates the project in the chosen destination (optional year folder) in one all-or-nothing step: never overwrites or merges, and rolls back on any failure.
- **Premiere Pro:** copies the master `.prproj` into `04_Project/Premiere Pro` under the generated name, checked byte for byte. Can open it in Premiere after creating.
- **DaVinci Resolve (optional):** copies the master `.drp` into `04_Project/DaVinci Resolve` and sets the Resolve project name to the generated name. Working Folders stay as in the master.
- **Folder Templates:** Standard Production built in; add, rename, move and nest folders; default template per project type.
- **Recent Projects:** projects created by the app, with search, type filter, drive status, Reveal in Finder, Open in Premiere Pro, New Project Like This.
- **Update Project:** add folders to an existing project, rename or delete only empty folders, add a missing Premiere or Resolve file. Never moves folders or touches content.
- **External drives:** KIOXIA (projects) and WORK (templates) are tracked separately by volume ID, update live when plugged, unplugged or renamed, and use macOS security-scoped permissions.
- **Settings:** defaults, locations with reauthorize, naming preview, recent-list size. Saved with backups and damaged-file recovery.

## Safety
The master templates are only read. Deleting happens only for the app's own temporary staging folder and, in Update Project, for folders that are empty at that moment. Every error explains what happened and what to do.

## Known limitations
- Not notarized and ad-hoc signed: on another Mac, Gatekeeper requires **Open Anyway** once (see INSTALLATION.md).
- The Copy Into folder choice (Premiere and Resolve) isn't saved between launches (fixed in 1.0.2).
- Recent Projects shows Premiere status but not the Resolve file.
- A duplicate project name is reported when Create Project is clicked, not while typing.
- Resolve name setting relies on Resolve's undocumented `.drp` format (checked with Resolve Studio 21); if it changes, creation stops safely with an error.
- Not yet tested by hand: physically unplugging a drive during creation, and the Open in Premiere Pro button (see MANUAL_TEST_CHECKLIST.md).

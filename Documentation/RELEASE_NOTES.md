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
- The Copy Into folder choice (Premiere and Resolve) isn't saved between launches.
- Recent Projects shows Premiere status but not the Resolve file.
- A duplicate project name is reported when Create Project is clicked, not while typing.
- Resolve name setting relies on Resolve's undocumented `.drp` format (checked with Resolve Studio 21); if it changes, creation stops safely with an error.
- Not yet tested by hand: physically unplugging a drive during creation, and the Open in Premiere Pro button (see MANUAL_TEST_CHECKLIST.md).

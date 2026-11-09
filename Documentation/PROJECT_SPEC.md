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
- Projects: `/Volumes/KIOXIA/PROJECT VIDEO/EVENT/{yyyy}` (year from the project date, when enabled). The `EVENT` folder does not change with project type.
- Premiere master: `/Volumes/WORK/TÀI NGUYÊN /PREMIERE PRO/PROJECT MODEL/Project/Year - Month - Day - Name 2026.prproj` (note the space after `NGUYÊN`).
- KIOXIA and WORK are separate volumes and are handled independently.

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
**Reels — Lite** — 9 folders including root. Default for Reels. Hierarchy **not yet specified** — do not invent it.

A project type belongs to exactly one template.

## Missing Premiere template policy
Block creation until the template is available. Creating folders only requires the user to explicitly turn off "Create Premiere project from template". Incomplete projects are never created silently.

## Design reference
`Documentation/DesignReferences/` — 5 screens + 3 states (drive not connected, project created, validation error + missing template). Dark graphite, native macOS controls, restrained blue accent.

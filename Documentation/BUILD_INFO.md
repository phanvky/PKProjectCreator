# Build Info — PKProjectCreator 1.0.3 (4)

| Item | Value |
|---|---|
| Product | PKProjectCreator |
| Bundle identifier | `com.phankyfilm.PKProjectCreator` (unchanged) |
| Version / build | 1.0.3 / 4 |
| Minimum macOS | 26.0 |
| Architecture | arm64 only (Apple Silicon) |
| Configuration | Release (`-O`, whole-module), Swift 6 language mode |
| Built on | macOS 27.2, Xcode 27.2 (27B52), 2026-11-18 |
| Source | `main` 9b8ecd8 (branch `resolve-working-folders`) + version bump, tag v1.0.3 |
| Dependencies | zstd 1.5.7 (Swift package from github.com/facebook/zstd, linked statically); `/usr/bin/zip`, `unzip`, `zipinfo` are called at runtime for the Resolve file |
| Network | None (no network entitlement, no network code) |

## Signing
- No signing identities exist on the build Mac (`security find-identity -v -p codesigning` → 0), so there is no Apple Development or Developer ID certificate.
- The release app is **ad-hoc signed** with Hardened Runtime and these entitlements only:
  - `com.apple.security.app-sandbox`
  - `com.apple.security.files.user-selected.read-write`
- The debugging entitlement (`get-task-allow`) that Xcode adds when signing locally was removed for the release copy.
- `codesign --verify --strict --deep` → valid, satisfies its designated requirement.
- `spctl --assess` → **rejected** (expected for ad-hoc; see Gatekeeper in INSTALLATION.md).

## Notarization
**Not notarized.** Notarization needs a Developer ID Application certificate and an Apple Developer account, and neither is available. Nothing was submitted to Apple.

## Artifacts (outside the source tree)
`/Volumes/WORK/APP/Developer/PKProjectCreator-Release/1.0.3/` (older release folders were moved to the Trash at the user's request)
| File | Size | SHA-256 |
|---|---|---|
| `PKProjectCreator.app` | 8.4 MB | (bundle) |
| `PKProjectCreator.dmg` | 4,141,654 bytes (4.1 MB), UDZO, APFS | `f7bb054268f7838511937973ccd6e16884b69fea4f0b74d6a40d6f80431f19d8` |

1.0.2 DMG: 3,325,804 bytes, SHA-256 `a8c1708efba7db52280bf184cbc1ac0fba3b54c979d1e4001ae91869f6dae2ff`. 1.0.1 DMG: 3,253,123 bytes, SHA-256 `2f7df24b5696e4a6c30d1154b6e69fe7f2ac04abbedb3c4bf8df67b3a69c55cc`. 1.0.0 DMG: 1,406,336 bytes, SHA-256 `aab670eb9516a3239c0b52a10f32c2f87f9fef7739c5d4f3a9d7604e3067d1fe`.

DMG contents: `PKProjectCreator.app` and an `Applications` link to `/Applications`. No source, debug symbols or build products.

## How it was built
```sh
# 1. Release build
xcodebuild -project PKProjectCreator.xcodeproj -scheme PKProjectCreator \
  -configuration Release -derivedDataPath build clean build

# 2. Copy out of the source tree
R=/Volumes/WORK/APP/Developer/PKProjectCreator-Release/1.0.3
ditto --norsrc build/Build/Products/Release/PKProjectCreator.app "$R/PKProjectCreator.app"

# 3. Re-sign ad-hoc with Hardened Runtime and only the release entitlements
#    (release.entitlements = app-sandbox + files.user-selected.read-write, both true)
codesign --force --sign - --options runtime --timestamp=none \
  --entitlements release.entitlements "$R/PKProjectCreator.app"
codesign --verify --strict --deep --verbose=2 "$R/PKProjectCreator.app"

# 4. DMG from a staging folder holding the app and an Applications link
hdiutil create -volname PKProjectCreator -srcfolder <staging>/PKProjectCreator \
  -format UDZO -fs APFS "$R/PKProjectCreator.dmg"
hdiutil verify "$R/PKProjectCreator.dmg"
```

With a Developer ID later: sign with `--sign "Developer ID Application: …" --options runtime --timestamp`, then notarize with `xcrun notarytool submit PKProjectCreator.dmg --keychain-profile <profile> --wait` (or Xcode Organizer) and `xcrun stapler staple PKProjectCreator.dmg`.

## Checks performed
- All automated tests passed on the release source (Debug test run), including the Resolve Working Folders tests.
- Release build signed ad-hoc with only the two release entitlements; `codesign --verify --strict --deep` valid; version 1.0.3 / 4 read from the bundle; zstd is inside the binary (no extra library files).
- DMG verified, mounted, contents and `Applications` link checked.
- Installed from the DMG into `/Applications` (1.0.2 moved to the Trash) and launched.
- Working Folders output checked against the real master `.drp` and confirmed by the user in Resolve (media, proxy, cache). Not checked: creating a real project from the installed 1.0.3.

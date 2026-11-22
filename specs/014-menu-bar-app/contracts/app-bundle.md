# Contract: the app bundle (spec 014)

What `scripts/make-app.sh` produces and what the spec 005 amendment packages. Release signing, notarization and the
cask are the amendment's; this contract fixes the layout both rely on.

## Layout

```text
Desktop Name Manager.app/
└── Contents/
    ├── Info.plist
    ├── PkgInfo
    ├── MacOS/DesktopNameManager       # the app
    ├── Helpers/dnm                    # the command-line tool, identical to the standalone build
    └── Resources/
        ├── AppIcon.icns
        ├── MenuBarGlyph.svg           # the menu-bar item's template image
        └── Licenses/                  # the license files of every shipped component (constitution)
```

- `dnm` lives in `Contents/Helpers/` so that it is signed as nested code and is not taken for the app's main
  executable. The cask links `dnm` and `desktop-name` to it (spec 005 amendment). `dnm` run from there behaves exactly
  as a standalone `dnm` (FR-020): it finds the store by the same rule and never depends on the app running.
- Both executables carry the same build stamp (version, build, commit).

## Info.plist keys

| Key | Value |
|---|---|
| `CFBundleIdentifier` | `com.altmansoftwaredesign.desktop-name-manager` (release), `...desktop-name-manager.dev` (development) |
| `CFBundleName` / `CFBundleDisplayName` | `Desktop Name Manager` |
| `CFBundleExecutable` | `DesktopNameManager` |
| `CFBundleShortVersionString` | `MARKETING_VERSION` from `Version.xcconfig` |
| `CFBundleVersion` | `CURRENT_PROJECT_VERSION` from `Version.xcconfig` |
| `CFBundleIconFile` | `AppIcon` |
| `LSMinimumSystemVersion` | `26.0` |
| `LSUIElement` | `true` (no Dock icon; shown while a window is open, by switching the activation policy) |
| `LSApplicationCategoryType` | `public.app-category.utilities` |
| `NSHumanReadableCopyright` | the MIT copyright line |
| `NSPrincipalClass` | `NSApplication` |

No usage-description keys (`NS...UsageDescription`): the app asks for no permission. No entitlements file; hardened
runtime at release. Not sandboxed (research R14).

## Development builds

`just app` assembles `build.noindex/app/Desktop Name Manager.app` with the `.dev` bundle ID, ad-hoc signed, from a
debug build (which uses the `.dev` store, as a debug `dnm` does). It never installs anything or registers a login item
by itself.

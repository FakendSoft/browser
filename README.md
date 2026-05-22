# Fakend Browser

Fakend Browser is a minimalist native macOS browser shell using Blink through
Chromium Embedded Framework (CEF). The UI target is black, compact, and fast:
tabs, a location field, and the page.

## Requirements

- macOS on Apple Silicon for the current scaffold.
- Flox.
- Apple Command Line Tools are enough for the current CMake/Ninja build.
  Full Xcode is still needed for Xcode UI or `xcodebuild` workflows.

## Environment

```sh
flox activate
```

Installed Flox tools are tracked in `.flox/env/manifest.toml`.

## Build Flow

```sh
flox activate -- scripts/doctor.sh
flox activate -- scripts/fetch-cef.sh
flox activate -- scripts/configure.sh
flox activate -- scripts/build.sh
flox activate -- scripts/package-dmg.sh
```

The CEF archive is intentionally not committed. `scripts/fetch-cef.sh` downloads
the current stable macOS ARM64 standard distribution from the official CEF build
index, verifies SHA1, extracts it under `vendor/cef/dist/`, and updates
`vendor/cef/current`.

`scripts/build.sh` also applies an ad-hoc local signature to the generated app
bundle so nested CEF framework/helper resources pass macOS verification during
development.

For isolated smoke tests, set `FAKEND_BROWSER_USER_DATA_DIR` to a temporary
directory before launching the app, or run:

```sh
flox activate -- scripts/smoke-gui.sh
```

## Releases

GitHub Actions has a manual `Release` workflow. Running it computes the next
CalVer tag for the current UTC month:

- First release in a month: `vYYYY.M.1`
- Later releases in the same month: `vYYYY.M.2`, `vYYYY.M.3`, ...

The workflow builds on `macos-15` ARM64, creates a signed app bundle, packages
`Fakend Browser YYYY.M.N.dmg`, and publishes it to a GitHub Release.

## Current State

This repository currently contains the project plan, Flox environment, CMake
scaffold, native AppKit shell, CEF bridge classes, helper scripts, and a local
build of `build/Fakend Browser.app`. A GUI smoke test starts CEF and creates a
per-tab profile under an isolated temp user-data directory.

# Fakend Browser TODO

This is the working plan for Fakend Browser. Keep it current as implementation
decisions change.

## Product Direction

- [x] Name: Fakend Browser.
- [x] Target: macOS native app, ultraminimal UI, black/sleek visual language.
- [x] Engine: Blink via Chromium Embedded Framework (CEF), not WebKit.
- [x] First usable milestone: open a native `.app`, create one tab, load a URL.
- [x] Second milestone: multiple tabs with separate CEF request contexts and
      per-tab storage roots.
- [ ] Third milestone: harden process, storage, and network isolation.

## Current Context

- [x] Project directory started empty.
- [x] Flox environment created in `.flox/`.
- [x] Flox tooling installed: `cmake`, `ninja`, `xcodegen`, `swiftlint`, `jq`,
      `python3`.
- [x] Host architecture is `arm64`.
- [x] Host OS observed as macOS 26.4.1.
- [x] CEF is available in Flox/Nix only for Linux, so macOS uses the official
      CEF binary distribution.
- [x] Current stable CEF macOS ARM64 standard distribution resolved from the
      official index:
      `cef_binary_147.0.14+g76d2442+chromium-147.0.7727.138_macosarm64.tar.bz2`
      with SHA1 `52257263f13bc142d589a3e42b7b1f88df19f5f5`.
- [x] Full Xcode is not currently selected. `xcodebuild` reports Command Line
      Tools only. The current CMake/Ninja path builds with Command Line Tools;
      Xcode UI and `xcodebuild` workflows still need full Xcode selected.

## Architecture

- [x] Use AppKit/Objective-C++ for the native macOS shell.
- [x] Use CMake + Ninja from Flox for reproducible local builds.
- [x] Use C++20 for current CEF headers.
- [x] Use CEF standard distribution so the project has headers, CMake files,
      `libcef_dll_wrapper`, and sample-compatible bundle layout.
- [x] Use separate helper app executables for CEF subprocesses on macOS,
      including renderer-specific helper bundles.
- [x] Initialize CEF from the main app with an external message pump integrated
      into the AppKit run loop.
- [x] Copy `Chromium Embedded Framework.framework` and the helper `.app`
      variants into the main `.app` bundle at build time. Current macOS CEF
      resources live inside the framework bundle.
- [ ] Enable CEF sandboxing after signing and entitlement structure is in place.
      Development starts with sandbox disabled to get the first browser window
      bootstrapped.

## Tab Model

- [x] Represent each tab as a native object owning:
      - an AppKit container view,
      - a `CefBrowser`,
      - a `CefClient`,
      - a unique `CefRequestContext`.
- [x] Store each tab under:
      `~/Library/Application Support/Fakend Browser/CEF/Tab-<tab-id>`.
- [x] Use one `CefRequestContextSettings.cache_path` per tab for cookie/cache
      isolation.
- [x] Add `FAKEND_BROWSER_USER_DATA_DIR` override for isolated smoke profiles.
- [x] Track title and URL changes from CEF display callbacks.
- [x] Close and release each tab cleanly via `CefLifeSpanHandler`.
- [x] Add policy checks for popups, downloads, permission prompts, and external
      protocols before enabling general browsing.

## UI

- [x] Single native window with black background and hidden title bar chrome.
- [x] Compact tab strip with icon-only controls where practical.
- [x] Compact URL field.
- [x] No landing page, no marketing UI, no decorative gradients.
- [x] Keyboard shortcuts:
      - `Cmd+L` focus location.
      - `Cmd+T` new tab.
      - `Cmd+W` close tab.
      - `Cmd+R` reload.
      - `Cmd+[` and `Cmd+]` history navigation.
- [ ] Respect macOS focus, resize, and activation behavior.

## Build Steps

- [x] Initialize Flox environment.
- [x] Install build tooling into Flox.
- [x] Fetch the CEF standard distribution with `scripts/fetch-cef.sh`.
- [x] Configure with `scripts/configure.sh`.
- [x] Build with `scripts/build.sh`.
- [x] Run `build/Fakend Browser.app` in a short GUI smoke test.
- [x] Add `scripts/smoke-gui.sh` for repeatable isolated GUI smoke tests.
- [x] Add ad-hoc local codesigning for debug builds.
- [x] Add DMG packaging script.
- [x] Add manual GitHub Actions release workflow.
- [x] Add CalVer release version script.
- [ ] Add hardened signing, entitlements, and sandbox support.
- [ ] Add release packaging and notarization steps.

## Verification

- [x] `flox activate -- scripts/doctor.sh` reports required CMake/Ninja tools
      and CEF. It warns about `xcodebuild` until full Xcode is selected.
- [x] `flox activate -- scripts/fetch-cef.sh` downloads and verifies CEF.
- [x] `flox activate -- scripts/configure.sh` generates the Ninja build.
- [x] `flox activate -- scripts/build.sh` produces and signs the main `.app`.
- [x] Smoke test: launch app with an isolated `FAKEND_BROWSER_USER_DATA_DIR`;
      CEF starts and creates a per-tab profile directory.
- [x] Smoke test: open a second tab and confirm two separate tab profile
      directories are created.
- [x] Inspect process tree and confirm CEF helper processes are used.
- [x] Smoke test: confirm the CEF renderer helper starts and the first new-tab
      page loads through DevTools.
- [ ] Verify close/reopen tab does not leave orphan helper processes.

## Risks / Decisions To Revisit

- [ ] CEF macOS bundle structure is strict; if custom bundling fights CMake,
      switch to the CEF sample CMake macros and reduce from `cefsimple`.
- [ ] Per-tab `CefRequestContext` isolates browser storage but does not mean a
      hard OS process per tab for every site. Evaluate Chromium process model
      flags after the first working milestone.
- [ ] CEF sandbox requires signing and helper entitlements; do not ship without
      revisiting it.
- [ ] Browser security surface is large. Keep default features conservative
      until navigation, permissions, downloads, and external protocol handling
      are explicitly reviewed.

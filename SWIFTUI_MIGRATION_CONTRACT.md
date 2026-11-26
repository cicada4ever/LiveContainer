# SwiftUI Modernization Contract — LiveContainer

Status: planning and compatibility guardrails  
Base: `main`  
Working branch: `feature/swiftui-modernization`

## Objective

Modernize and complete the existing `LiveContainerSwiftUI` application. LiveContainer already has a SwiftUI application target and feature views; do not throw away that foundation or rewrite its runtime. This is a presentation, navigation, state-adapter, and maintainability project.

## Non-negotiable app identity and data compatibility rules

1. Preserve the effective Release app bundle identifier (currently derived from `LIVECONTAINER_BUNDLE_IDENTIFIER`, default release form `com.kdt.livecontainer`) and all existing Debug/Release configuration behavior.
2. Preserve the effective signing Team ID, application-identifier prefix, provisioning/signing configuration, and keychain access groups. The current `entitlements.xml` includes the shared `com.kdt.livecontainer.shared` keychain groups through `.127`; do not remove, reorder, rename, or regenerate these groups. Do not assume a source placeholder is the actual signing identity in the produced IPA.
3. Preserve both existing App Groups: the SideStore group (`group.com.SideStore.SideStore`) and AltStore compatibility group (`group.com.rileytestut.AltStore`), including their effective signing entitlements.
4. Preserve the main app's existing file/document behavior, file sharing, external storage security-scoped bookmarks, URL schemes, app intents, background modes, scene configuration, multiple-scene behavior, and extension bundle IDs.
5. Preserve LiveContainer's user defaults keys and app-group defaults suite. Do not reset defaults, delete preferences, or silently change the suite name.
6. Preserve existing file locations and formats:
   - App Documents root: `Documents/`
   - Guest app bundles: `Documents/Applications/`
   - Private app/container data: `Documents/Data/Application/`
   - Private app-group data: `Documents/Data/AppGroup/`
   - Tweaks: `Documents/Tweaks/`
   - Shared LiveContainer root: `<SideStore App Group>/LiveContainer/`
   - Shared guest bundles/data/app-group data/tweaks: `Applications/`, `Data/Application/`, `Data/AppGroup/`, and `Tweaks/` beneath that root.
   - Built-in SideStore data container: `Documents/SideStore/`
7. Preserve `LCContainerInfo.plist` format and semantics, app/container folder names, app bundle metadata, container bookmarks, external-storage bookmarks, per-container keychain-group assignments, app group isolation, spoofed identifier settings, and existing app data UUIDs.
8. Do not modify or replace LCBootstrap, Mach-O utilities, guest process/runtime hooks, dylib loading, TweakLoader, ZSign, JIT, LiveProcess, LaunchAppExtension, ShareExtension, or multitasking execution semantics as part of presentation work.
9. Do not alter SideStoreSupport intent/XPC behavior, SideStore embedded executable/module naming, intent metadata/type names, App Groups, or widget integration as part of UI work.
10. Never move, rename, purge, reset, or migrate existing user files merely to fit a new UI structure.

## Existing integration contract with SideStore

The combined IPA is assembled by `.github/workflows/build.yml` and `.github/build_github.sh`. The current process:

- Builds the LiveContainer Xcode scheme, including `SideStoreSupport.framework`.
- Retrieves the fork's SideStore nightly IPA.
- Moves the embedded SideStore app into `LiveContainer.app/Frameworks/SideStoreApp.framework`.
- Runs `dylibify` on the embedded SideStore executable and applies the expected signing step.
- Adds SideStore App Group, URL scheme, and supported intent metadata to LiveContainer.
- Copies the SideStore intent definitions and adjusts module type names for `SideStoreSupport`.
- Moves and renames the SideStore widget extension as LiveContainer's LiveWidget extension and signs it.
- Publishes both `LiveContainer.ipa` and `LiveContainer+SideStore.ipa`.

Keep this pipeline and its output names functioning. Do not replace the SideStore download source, change the release tag, or publish a feature-branch artifact to the shared nightly release without an explicit, tested promotion process. Eventually pin the exact SideStore commit/build consumed by each combined IPA, but first preserve the current known-good behavior.

## UI modernization scope

Bring the current SwiftUI application to feature parity and consistent native iOS quality:

- App library: app list/grid, search, sorting, hidden apps, app banners, progress, app actions, and empty states.
- App settings: app preferences, app data, containers, external storage, tweak assignments, signing preferences, language/orientation and all current flags.
- Installation: file, URL and source installation, replacement selection, progress, cancellation and failures.
- Sources and catalogue browsing.
- Tweaks and tweak configuration.
- Multitasking windows and dock.
- JIT and JIT diagnostics.
- Storage management, app data, cache and data management.
- Multi-LiveContainer management.
- Settings, certificate operations, import/export, help, diagnostics, error reporting, and all existing deep-link routes.

The UI may be restructured, but each existing action and persisted preference must remain behaviorally equivalent.

## Architecture direction

- Keep `LiveContainerSwiftUIApp`, `AppDelegate`, scene handling, shared model ownership, URL dispatch, multitasking windows, and existing runtime interfaces intact unless a measured requirement calls for a small adapter change.
- Use SwiftUI as the primary presentation layer. Retain the UIKit bridge for app-banner rendering or other specialized functionality until a tested native equivalent exists.
- Separate screens, presentation models, routing, and service adapters. Keep DataManager, LCAppInfo, LCAppModel, LCContainer, LCPath, and runtime managers authoritative.
- Do not recreate the filesystem model or app/container model inside new UI state.
- Do not use view lifecycle callbacks to start duplicate runtime operations. Handle async work, cancellation, and errors explicitly.
- Use native SwiftUI navigation, menus, sheets, controls, and system materials with availability checks and accessible fallbacks.

## Build and package verification

Every milestone must be checked in two separate ways:

1. Standalone LiveContainer build and launch.
2. Combined LiveContainer + SideStore package built with the SideStore version from the intended fork/branch.

The combined IPA must be inspected for expected executables, frameworks, extensions, bundle identifiers, URL schemes, App Groups, entitlements, and App Intents metadata. The SideStore embedded app must be loadable and the SideStoreSupport/LiveProcess refresh bridge must work.

A feature-branch validation run must publish build artifacts only; it must not overwrite the shared `nightly` release unless it is the deliberate release candidate.

## Data-safety release gate

A successful build or clean install does not prove an existing installation will update safely. The release candidate must be installed **over the existing LiveContainer installation without deleting it first**, using the same effective bundle identifier and compatible signing identity/application-identifier prefix. Then verify that all existing guest apps, app data, app groups, container metadata, external bookmarks, tweaks, certificates, preferences, built-in SideStore state, and SideStore Keychain/database data remain available.

Before any in-place upgrade test, retain the known-good combined IPA and make a user-controlled backup of critical app data. If the signing identity or App Group/Keychain compatibility cannot be proven, stop and report it. Never claim that all files and data are preserved until this real-device upgrade test succeeds.

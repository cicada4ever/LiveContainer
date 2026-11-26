# LiveContainer — SwiftUI Feature-Parity Register

Base branch: `main`  
Rewrite branch: `feature/swiftui-modernization`  
Status: inventory started; the existing SwiftUI app is the foundation, not disposable legacy code.

Check an item only after its new or modernized screen has passed functional tests and the combined IPA still opens existing user data.

## App shell, lifecycle and navigation

- [ ] Existing SwiftUI app entry point and app delegate behavior
- [ ] Scene configuration, duplicate-window handling and restoration
- [ ] Existing tabs, conditional Tweaks tab and selected-tab persistence
- [ ] Navigation, menus, sheets, alerts and presentation dismissal
- [ ] Every current URL/deep-link route
- [ ] File import, IPA handoff and share extension
- [ ] Crash/last-launch error reporting and copy/share logs
- [ ] App Intents, Siri/Shortcuts integration and supported notifications
- [ ] Multi-window scene behavior

Existing integration points: `LiveContainerSwiftUI/App/`, `LiveContainerSwiftUI/Views/LCTabView.swift`, `ShareExtension/`, `LiveContainer/Info.plist`.

## Guest app library

- [ ] App list and grid presentation
- [ ] App banner, icon loading and skeleton/loading state
- [ ] Search, debouncing and filtering
- [ ] Custom sorting and persisted sort rules
- [ ] Hidden apps, strict hiding and authentication unlock
- [ ] App count, empty state and shared-app status
- [ ] Launch app, multitask launch and existing-window activation
- [ ] Install IPA, install URL and web-based installation
- [ ] Replacement selection, progress, errors and cancellation
- [ ] App actions, remove/hide/unhide, visibility and icon state
- [ ] Built-in SideStore listing and launch behavior
- [ ] Correct app behavior in portrait, landscape and iPad layouts

Existing implementation: `LiveContainerSwiftUI/Views/AppList/LCAppListView.swift`, `LCAppBanner/`, `LCAppSortManager.swift`, `LCAppModel.swift`.

## App settings and container management

- [ ] Per-app preferences and app metadata
- [ ] Container list, creation, selection and rename
- [ ] Default container selection and saved selection
- [ ] Private versus shared app storage
- [ ] Move an app between private and shared locations
- [ ] External storage selection and security-scoped bookmarks
- [ ] Unused container selection and cleanup
- [ ] App-group isolation and container-specific behavior
- [ ] Keychain-group assignment per container
- [ ] Spoofed identifier settings and persisted values
- [ ] App-specific tweak folder selection
- [ ] Language, orientation and multitasking options
- [ ] Signing preferences and all current compatibility/fix flags

Existing implementation: `LCAppSettingsView.swift`, `LCContainerView.swift`, `LCSelectContainerView.swift`, `LCAppPreferenceView.swift`, `LCAppModel.swift`, `LCContainer.swift`.

## Runtime, multitasking and JIT

- [ ] Guest app launch in normal mode
- [ ] Guest app launch in multitask/virtual-window mode
- [ ] Multitasking dock and window management
- [ ] Bring existing guest window to foreground
- [ ] Per-app multitask options and global multitask settings
- [ ] JIT enable flows and all supported JIT enablers
- [ ] JIT-less diagnostics and failure recovery
- [ ] Classic mode and helper-process options
- [ ] 32-bit emulation configuration
- [ ] Tweak loader configuration and injection status
- [ ] Tweak enable/disable and signing behavior

The UI may call these systems but must not rewrite their implementation. Keep `LCBootstrap`, `LiveProcess`, `TweakLoader`, `ZSign`, Mach-O/process hooks and runtime libraries outside the UI migration.

## Sources, tweaks and settings

- [ ] Source list, browsing and source details
- [ ] Built-in SideStore/AltStore source behavior
- [ ] Tweaks list, sorting, configuration and folder assignment
- [ ] Certificate import, removal, refresh and status
- [ ] Multi-LiveContainer configuration and status handling
- [ ] Storage management: app bundles, containers, app groups, tweaks, temporary and other data
- [ ] Storage breakdown remains read-only and accurate
- [ ] Data management and cache operations
- [ ] Help, diagnostics, troubleshooting and error surfaces
- [ ] All settings and AppStorage/UserDefaults-backed controls
- [ ] Hidden-app security and Face ID/authentication flow
- [ ] User-configurable app display style and icons

Existing implementation: `LCAltStoreSourcesView.swift`, `LCTweaksView.swift`, `LCSettingsView.swift`, `LCStorageManagementView.swift`, `LCDataManagementView.swift`, `LCJITLessDiagnoseView.swift`, `LCMultiLCManagementView.swift`.

## Persistence and upgrade regression scenarios

- [ ] Existing Documents folder and files preserved
- [ ] Existing guest app bundles in `Documents/Applications` remain available
- [ ] Existing private containers in `Documents/Data/Application` remain available
- [ ] Existing private App Group data in `Documents/Data/AppGroup` remains available
- [ ] Existing tweaks in `Documents/Tweaks` remain available
- [ ] Existing shared LiveContainer data under the SideStore App Group remains available
- [ ] Existing app/container UUIDs and `LCContainerInfo.plist` metadata remain valid
- [ ] Existing bookmarks and external storage access remain valid
- [ ] Existing per-container keychain group assignments remain valid
- [ ] Existing UserDefaults and app-group preferences remain valid
- [ ] Built-in SideStore state in `Documents/SideStore` remains available
- [ ] Existing signing certificate and certificate password remain accessible
- [ ] Existing URL handlers, share extension, App Intents and widgets still work
- [ ] Standalone LiveContainer launches and operates correctly
- [ ] Combined LiveContainer + SideStore IPA embeds the correct SideStore build
- [ ] In-place installation over existing LiveContainer on a real device succeeds without deleting the app first

## Combined-package regression scenarios

- [ ] Host LiveContainer bundle ID and signing identity remain compatible
- [ ] Main App Groups and 128 existing LiveContainer keychain groups remain intact
- [ ] Host Info.plist retains `ALTAppGroups` with the SideStore group
- [ ] `SideStoreSupport.framework` remains embedded and loadable
- [ ] Embedded SideStore keeps the `com.SideStore.SideStore` Keychain service identity
- [ ] Embedded SideStore bundle ID remains unchanged
- [ ] Embedded `LCAppInfo.plist` retains the data UUID and container metadata
- [ ] SideStore App Intents metadata and module type-name remapping remain correct
- [ ] LiveProcess, LaunchAppExtension, ShareExtension and LiveWidget remain present
- [ ] Combined IPA compatibility verifier passes
- [ ] Built-in SideStore launch and Refresh All through the XPC/intent bridge succeed

## Removal rule

Do not replace a working SwiftUI view/model simply to reorganize files. Improve it in stages. Retain UIKit, Objective-C and C bridges wherever needed for a working native feature. Remove or replace a view only after all of its behaviors and persisted settings are covered by tests.

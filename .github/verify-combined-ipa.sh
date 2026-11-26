#!/usr/bin/env bash
set -euo pipefail

IPA_PATH="${1:-}"
EXPECTED_LC_BUNDLE_ID="${EXPECTED_LC_BUNDLE_ID:-com.kdt.livecontainer}"
EXPECTED_SIDESTORE_BUNDLE_ID="${EXPECTED_SIDESTORE_BUNDLE_ID:-com.SideStore.SideStore}"
REQUIRED_SIDESTORE_GROUP="group.com.SideStore.SideStore"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ -n "$IPA_PATH" ]] || fail "Usage: $0 path/to/LiveContainer+SideStore.ipa"
[[ -f "$IPA_PATH" ]] || fail "Combined IPA not found: $IPA_PATH"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

/usr/bin/unzip -q "$IPA_PATH" -d "$WORK_DIR" || fail "Could not extract the combined IPA."

APP="$WORK_DIR/Payload/LiveContainer.app"
[[ -d "$APP" ]] || fail "Payload/LiveContainer.app is missing."

plist_value() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true
}

require_file() {
  [[ -f "$1" ]] || fail "Required file is missing: ${1#"$WORK_DIR"/}"
}

require_dir() {
  [[ -d "$1" ]] || fail "Required directory is missing: ${1#"$WORK_DIR"/}"
}

LC_INFO="$APP/Info.plist"
require_file "$LC_INFO"

LC_BUNDLE_ID="$(plist_value "$LC_INFO" "CFBundleIdentifier")"
[[ "$LC_BUNDLE_ID" == "$EXPECTED_LC_BUNDLE_ID" ]] || fail "LiveContainer bundle ID mismatch: expected '$EXPECTED_LC_BUNDLE_ID', got '$LC_BUNDLE_ID'."

ALT_APP_GROUPS="$(plist_value "$LC_INFO" "ALTAppGroups")"
[[ "$ALT_APP_GROUPS" == *"$REQUIRED_SIDESTORE_GROUP"* ]] || fail "Host Info.plist is missing ALTAppGroups entry '$REQUIRED_SIDESTORE_GROUP'. Embedded SideStore uses this to resolve its existing shared database."

URL_TYPES="$(plist_value "$LC_INFO" "CFBundleURLTypes")"
for scheme in livecontainer sidestore "sidestore-$EXPECTED_LC_BUNDLE_ID"; do
  [[ "$URL_TYPES" == *"$scheme"* ]] || fail "Required URL scheme '$scheme' is missing from LiveContainer Info.plist."
done

SUPPORTED_INTENTS="$(plist_value "$LC_INFO" "INIntentsSupported")"
for intent in RefreshAllIntent ViewAppIntent; do
  [[ "$SUPPORTED_INTENTS" == *"$intent"* ]] || fail "Required App Intent '$intent' is missing from LiveContainer Info.plist."
done

FRAMEWORKS="$APP/Frameworks"
SIDESTORE="$FRAMEWORKS/SideStoreApp.framework"
require_dir "$FRAMEWORKS/SideStoreSupport.framework"
require_dir "$SIDESTORE"
require_file "$SIDESTORE/SideStore"
require_file "$SIDESTORE/Info.plist"
require_file "$SIDESTORE/LCAppInfo.plist"
require_file "$APP/Intents.intentdefinition"
require_file "$APP/ViewApp.intentdefinition"
require_dir "$APP/Metadata.appintents"
require_file "$APP/Metadata.appintents/extract.actionsdata"

SIDESTORE_BUNDLE_ID="$(plist_value "$SIDESTORE/Info.plist" "CFBundleIdentifier")"
[[ "$SIDESTORE_BUNDLE_ID" == "$EXPECTED_SIDESTORE_BUNDLE_ID" ]] || fail "Embedded SideStore bundle ID mismatch: expected '$EXPECTED_SIDESTORE_BUNDLE_ID', got '$SIDESTORE_BUNDLE_ID'."

BUILTIN_DATA_UUID="$(plist_value "$SIDESTORE/LCAppInfo.plist" "LCDataUUID")"
[[ -n "$BUILTIN_DATA_UUID" ]] || fail "Embedded SideStore LCAppInfo.plist is missing LCDataUUID."

# The embedded built-in SideStore must keep the exact container identity that
# LiveContainer ships in its source metadata. Merely having a UUID is not enough:
# a changed UUID would point the UI at a different data directory on upgrade.
SOURCE_LC_APP_INFO=".github/sidelc/LCAppInfo.plist"
require_file "$SOURCE_LC_APP_INFO"
EXPECTED_DATA_UUID="$(plist_value "$SOURCE_LC_APP_INFO" "LCDataUUID")"
[[ -n "$EXPECTED_DATA_UUID" ]] || fail "Repository LCAppInfo.plist has no LCDataUUID."
[[ "$BUILTIN_DATA_UUID" == "$EXPECTED_DATA_UUID" ]] || fail "Embedded SideStore LCDataUUID changed: expected '$EXPECTED_DATA_UUID', got '$BUILTIN_DATA_UUID'."

CONTAINERS="$(plist_value "$SIDESTORE/LCAppInfo.plist" "LCContainers")"
[[ "$CONTAINERS" == *"folderName"* ]] || fail "Embedded SideStore LCAppInfo.plist is missing container metadata."
EXPECTED_CONTAINER_FOLDER="$(/usr/libexec/PlistBuddy -c 'Print :LCContainers:0:folderName' "$SOURCE_LC_APP_INFO" 2>/dev/null || true)"
EMBEDDED_CONTAINER_FOLDER="$(/usr/libexec/PlistBuddy -c 'Print :LCContainers:0:folderName' "$SIDESTORE/LCAppInfo.plist" 2>/dev/null || true)"
[[ -n "$EXPECTED_CONTAINER_FOLDER" ]] || fail "Repository LCAppInfo.plist has no built-in SideStore container folder."
[[ "$EMBEDDED_CONTAINER_FOLDER" == "$EXPECTED_CONTAINER_FOLDER" ]] || fail "Embedded SideStore container folder changed: expected '$EXPECTED_CONTAINER_FOLDER', got '$EMBEDDED_CONTAINER_FOLDER'."
cmp -s "$SOURCE_LC_APP_INFO" "$SIDESTORE/LCAppInfo.plist" || fail "Embedded SideStore LCAppInfo.plist differs from the repository's canonical file; built-in SideStore container metadata may not survive an upgrade."

PLUGINS="$APP/PlugIns"
require_dir "$PLUGINS/LiveProcess.appex"
require_dir "$PLUGINS/LaunchAppExtension.appex"
require_dir "$PLUGINS/ShareExtension.appex"
require_dir "$PLUGINS/LiveWidgetExtension.appex"
require_file "$PLUGINS/LiveWidgetExtension.appex/LiveWidgetExtension"

WIDGET_BUNDLE_ID="$(plist_value "$PLUGINS/LiveWidgetExtension.appex/Info.plist" "CFBundleIdentifier")"
WIDGET_EXECUTABLE="$(plist_value "$PLUGINS/LiveWidgetExtension.appex/Info.plist" "CFBundleExecutable")"
[[ "$WIDGET_BUNDLE_ID" == "$EXPECTED_LC_BUNDLE_ID.LiveWidget" ]] || fail "LiveWidget bundle ID mismatch: got '$WIDGET_BUNDLE_ID'."
[[ "$WIDGET_EXECUTABLE" == "LiveWidgetExtension" ]] || fail "LiveWidget executable name mismatch: got '$WIDGET_EXECUTABLE'."

printf 'Combined IPA compatibility check passed.\n'
printf '  LiveContainer: %s\n' "$LC_BUNDLE_ID"
printf '  Embedded SideStore: %s\n' "$SIDESTORE_BUNDLE_ID"
printf '  SideStore App Group: %s\n' "$REQUIRED_SIDESTORE_GROUP"
printf '  Built-in SideStore data UUID preserved: %s\n' "$BUILTIN_DATA_UUID"
printf '  Built-in SideStore container folder preserved: %s\n' "$EMBEDDED_CONTAINER_FOLDER"
printf '  Full built-in SideStore LCAppInfo.plist: identical to canonical source\n'
printf '  SideStoreSupport, LiveProcess, LaunchAppExtension, ShareExtension, LiveWidget: present\n'
printf '  URL schemes and App Intents: present\n'

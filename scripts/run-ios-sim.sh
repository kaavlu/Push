#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-run}"
APP_ARGS=("${@:2}")

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

PROJECT="Push.xcodeproj"
SCHEME="Push"
APP_PREFIX="Push"
BASE_DEVICE_NAME="iPhone 14 Pro Max"
DEVICE_TYPE_ID="com.apple.CoreSimulator.SimDeviceType.iPhone-14-Pro-Max"
DERIVED_DATA="$ROOT/DerivedData"

# Worktree label:
# - Orca worktrees: /Users/.../orca/workspaces/Push/rusalka -> rusalka
# - Main worktree on main branch -> main
BRANCH_NAME="$(git branch --show-current 2>/dev/null || true)"
WORKTREE_BASENAME="$(basename "$ROOT")"

if [ "$BRANCH_NAME" = "main" ] || [ "$BRANCH_NAME" = "master" ]; then
  WORKTREE_NAME="$BRANCH_NAME"
else
  WORKTREE_NAME="$WORKTREE_BASENAME"
fi

# Keep names simulator-safe/readable
SAFE_WORKTREE_NAME="$(echo "$WORKTREE_NAME" | tr -cd '[:alnum:]_.-' | cut -c1-24)"
SIM_NAME="$APP_PREFIX - $SAFE_WORKTREE_NAME"
STATUS_LABEL="$(echo "$SAFE_WORKTREE_NAME" | cut -c1-8)"

get_latest_ios_runtime() {
  /usr/bin/python3 <<'PY'
import json
import subprocess
import sys

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "-j"]))

runtimes = []
for runtime in data.get("runtimes", []):
    if not runtime.get("isAvailable"):
        continue

    identifier = runtime.get("identifier", "")
    version = runtime.get("version", "")

    if "iOS" not in identifier:
        continue

    def version_key(v):
        return tuple(int(x) for x in v.split(".") if x.isdigit())

    runtimes.append((version_key(version), identifier))

if not runtimes:
    sys.exit(1)

print(sorted(runtimes)[-1][1])
PY
}

get_sim_udid() {
  /usr/bin/python3 <<PY
import json
import subprocess
import sys

target_name = "$SIM_NAME"

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"]))

for runtime, devices in data.get("devices", {}).items():
    for device in devices:
        if device.get("name") == target_name:
            print(device.get("udid"))
            sys.exit(0)

sys.exit(1)
PY
}

create_sim_if_needed() {
  if UDID="$(get_sim_udid 2>/dev/null)"; then
    echo "$UDID"
    return
  fi

  RUNTIME_ID="$(get_latest_ios_runtime)"

  xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE_ID" "$RUNTIME_ID" >/dev/null

  get_sim_udid
}

label_status_bar() {
  local udid="$1"

  # Best effort. On newer iPhone simulators, carrier text may not always be visible,
  # so we override both time and operatorName.
  xcrun simctl status_bar "$udid" override \
    --time "$STATUS_LABEL" \
    --operatorName "$STATUS_LABEL" \
    --cellularMode active \
    --cellularBars 4 \
    --wifiMode active \
    --wifiBars 3 \
    --batteryState charged \
    --batteryLevel 100 >/dev/null 2>&1 || true
}

run_app() {
  UDID="$(create_sim_if_needed)"

  open -a Simulator --args -CurrentDeviceUDID "$UDID" >/dev/null 2>&1 || open -a Simulator

  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null

  label_status_bar "$UDID"

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    build

  APP="$(find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "*.app" | head -1)"

  if [ -z "$APP" ]; then
    echo "No built .app found."
    exit 1
  fi

  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"

  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$UDID" "$APP" >/dev/null
  if [ "${#APP_ARGS[@]}" -gt 0 ]; then
    xcrun simctl launch "$UDID" "$BUNDLE_ID" "${APP_ARGS[@]}" >/dev/null
  else
    xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
  fi

  echo "Ran $SCHEME on \"$SIM_NAME\""
}

stop_sim() {
  UDID="$(get_sim_udid 2>/dev/null || true)"

  if [ -z "${UDID:-}" ]; then
    echo "No simulator exists for \"$SIM_NAME\""
    exit 0
  fi

  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  echo "Stopped \"$SIM_NAME\""
}

restart_sim() {
  stop_sim >/dev/null || true
  run_app
}

status_sim() {
  UDID="$(get_sim_udid 2>/dev/null || true)"

  if [ -z "${UDID:-}" ]; then
    echo "No simulator exists for \"$SIM_NAME\""
    exit 0
  fi

  xcrun simctl list devices | grep "$UDID" || true
}

case "$ACTION" in
  run)
    run_app
    ;;
  stop)
    stop_sim
    ;;
  restart)
    restart_sim
    ;;
  status)
    status_sim
    ;;
  *)
    echo "Usage: $0 [run|stop|restart|status]"
    exit 1
    ;;
esac

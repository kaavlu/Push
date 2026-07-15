#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

PROJECT="Push.xcodeproj"
SCHEME="Push"
APP_PREFIX="Push"
DERIVED_DATA="$ROOT/DerivedData"
DEFAULT_DEVICE_NAME="iPhone 17"
PRO_MAX_DEVICE_NAME="iPhone 17 Pro Max"

ACTION="run"
DEVICE_MODE="default"
APP_ARGS=()
# When set (stop hook), never create devices and only reload a Booted preferred sim.
RELOAD_IF_BOOTED=false

usage() {
  cat <<EOF
Usage: $0 [run|stop|restart|status|list|prune|reload-if-booted] [--iphone-17|--iphone-17-pro-max|--all] [-- app args...]

Default run behavior:
  - If any Push simulators for this worktree are already booted, rebuild/reload all of them.
  - Otherwise, boot/create the regular iPhone 17 simulator for this worktree.

Actions:
  run                 Build + install + launch (default).
  stop                Shutdown worktree sim(s).
  restart             Shutdown then run.
  status              Print matching simctl rows.
  list                List all Push-prefixed sims (any worktree).
  prune               Delete known-orphan Push sims (e.g. Push - Push - *).
  reload-if-booted    Like run for --iphone-17, but exit 0 if preferred sim is not Booted (no create).

Device flags:
  --iphone-17           Target the regular iPhone 17 simulator for this worktree.
  --iphone-17-pro-max   Target the iPhone 17 Pro Max simulator for this worktree.
  --all                 Target all existing Push simulators for this worktree.

Worktree labels:
  - Orca path .../orca/workspaces/Push/<name> → label <name>
  - Primary / non-Orca checkout → always label main (stable across feature branches)
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    run|stop|restart|status|list|prune|reload-if-booted)
      ACTION="$1"
      shift
      ;;
    --iphone-17|--17)
      DEVICE_MODE="iphone17"
      shift
      ;;
    --iphone-17-pro-max|--17-pro-max|--pro-max)
      DEVICE_MODE="iphone17_pro_max"
      shift
      ;;
    --all)
      DEVICE_MODE="all"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      APP_ARGS=("$@")
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      APP_ARGS+=("$1")
      shift
      ;;
  esac
done

# Worktree label:
# - Orca worktrees: /Users/.../orca/workspaces/Push/rusalka -> rusalka
# - Primary checkout (Desktop, any feature branch) -> main so Stop/run reuse one sim
WORKTREE_BASENAME="$(basename "$ROOT")"

if [[ "$ROOT" == *"/orca/workspaces/Push/"* ]] || [[ "$ROOT" == *"/orca/workspaces/Push" ]]; then
  # .../orca/workspaces/Push/<card> or the Push workspace root itself
  if [ "$WORKTREE_BASENAME" = "Push" ] && [[ "$ROOT" == *"/orca/workspaces/Push" ]]; then
    WORKTREE_NAME="main"
  else
    WORKTREE_NAME="$WORKTREE_BASENAME"
  fi
else
  WORKTREE_NAME="main"
fi

SAFE_WORKTREE_NAME="$(echo "$WORKTREE_NAME" | tr -cd '[:alnum:]_.-' | cut -c1-24)"
if [ -z "$SAFE_WORKTREE_NAME" ]; then
  SAFE_WORKTREE_NAME="worktree"
fi

SIM_PREFIX="$APP_PREFIX - $SAFE_WORKTREE_NAME"
STATUS_LABEL="$(echo "$SAFE_WORKTREE_NAME" | cut -c1-8)"

if [ "$ACTION" = "reload-if-booted" ]; then
  ACTION="run"
  RELOAD_IF_BOOTED=true
  if [ "$DEVICE_MODE" = "default" ]; then
    DEVICE_MODE="iphone17"
  fi
fi

device_name_for_mode() {
  case "$1" in
    iphone17_pro_max) echo "$PRO_MAX_DEVICE_NAME" ;;
    iphone17|default|all) echo "$DEFAULT_DEVICE_NAME" ;;
    *) echo "$DEFAULT_DEVICE_NAME" ;;
  esac
}

sim_name_for_device() {
  local device_name="$1"
  echo "$SIM_PREFIX - $device_name"
}

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

    def version_key(value):
        return tuple(int(part) for part in value.split(".") if part.isdigit())

    runtimes.append((version_key(version), identifier))

if not runtimes:
    sys.exit("No available iOS simulator runtimes found.")

print(sorted(runtimes)[-1][1])
PY
}

get_device_type_id() {
  local preferred_name="$1"

  PREFERRED_NAME="$preferred_name" /usr/bin/python3 <<'PY'
import json
import os
import subprocess
import sys

preferred_name = os.environ["PREFERRED_NAME"]
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devicetypes", "-j"]))
available = [
    item for item in data.get("devicetypes", [])
    if item.get("isAvailable", True)
]

def emit_matching(predicate):
    for item in available:
        if predicate(item.get("name", "")):
            print(item["identifier"])
            return True
    return False

if emit_matching(lambda name: name == preferred_name):
    sys.exit(0)

if "Pro Max" in preferred_name and emit_matching(lambda name: name.startswith("iPhone") and "Pro Max" in name):
    sys.exit(0)

if emit_matching(lambda name: name == "iPhone 17"):
    sys.exit(0)

if emit_matching(lambda name: name.startswith("iPhone")):
    sys.exit(0)

sys.exit("No available iPhone simulator device types found.")
PY
}

list_worktree_sims() {
  local only_booted="${1:-false}"

  SIM_PREFIX="$SIM_PREFIX" ONLY_BOOTED="$only_booted" /usr/bin/python3 <<'PY'
import json
import os
import subprocess

prefix = os.environ["SIM_PREFIX"]
device_prefix = prefix + " - "
only_booted = os.environ["ONLY_BOOTED"] == "true"
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"]))

for runtime, devices in data.get("devices", {}).items():
    if "com.apple.CoreSimulator.SimRuntime.iOS" not in runtime:
        continue

    for device in devices:
        name = device.get("name", "")
        state = device.get("state", "")
        udid = device.get("udid", "")

        if name != prefix and not name.startswith(device_prefix):
            continue
        if not device.get("isAvailable", True):
            continue
        if only_booted and state != "Booted":
            continue

        print(f"{udid}\t{name}\t{state}")
PY
}

get_sim_udid_by_name() {
  local sim_name="$1"

  SIM_NAME="$sim_name" /usr/bin/python3 <<'PY'
import json
import os
import subprocess
import sys

target_name = os.environ["SIM_NAME"]
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"]))

for runtime, devices in data.get("devices", {}).items():
    if "com.apple.CoreSimulator.SimRuntime.iOS" not in runtime:
        continue

    for device in devices:
        if device.get("name") == target_name and device.get("isAvailable", True):
            print(device.get("udid"))
            sys.exit(0)

sys.exit(1)
PY
}

create_sim() {
  local sim_name="$1"
  local preferred_device_name="$2"
  local runtime_id
  local device_type

  runtime_id="$(get_latest_ios_runtime)"
  device_type="$(get_device_type_id "$preferred_device_name")"

  xcrun simctl create "$sim_name" "$device_type" "$runtime_id"
}

boot_sim() {
  local udid="$1"

  if xcrun simctl boot "$udid" >/dev/null 2>&1; then
    xcrun simctl bootstatus "$udid" -b >/dev/null
    return
  fi

  if xcrun simctl list devices | grep -F "$udid" | grep -F "(Booted)" >/dev/null; then
    xcrun simctl bootstatus "$udid" -b >/dev/null
    return
  fi

  return 1
}

ensure_sim_for_mode() {
  local mode="$1"
  local device_name
  local sim_name
  local udid

  device_name="$(device_name_for_mode "$mode")"
  sim_name="$(sim_name_for_device "$device_name")"

  if udid="$(get_sim_udid_by_name "$sim_name" 2>/dev/null)"; then
    echo "$udid	$sim_name"
    return
  fi

  udid="$(create_sim "$sim_name" "$device_name")"
  echo "$udid	$sim_name"
}

ensure_booted_sim_for_mode() {
  local mode="$1"
  local target
  local udid
  local sim_name

  target="$(ensure_sim_for_mode "$mode")"
  udid="$(cut -f1 <<< "$target")"
  sim_name="$(cut -f2- <<< "$target")"

  if ! boot_sim "$udid"; then
    echo "Existing simulator \"$sim_name\" could not boot; recreating it." >&2
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    udid="$(create_sim "$sim_name" "$(device_name_for_mode "$mode")")"
    boot_sim "$udid"
  fi

  echo "$udid	$sim_name"
}

target_sims_for_run() {
  local booted
  local preferred_name
  local udid

  if [ "$RELOAD_IF_BOOTED" = true ]; then
    preferred_name="$(sim_name_for_device "$(device_name_for_mode "$DEVICE_MODE")")"
    if udid="$(get_sim_udid_by_name "$preferred_name" 2>/dev/null)"; then
      if xcrun simctl list devices | grep -F "$udid" | grep -F "(Booted)" >/dev/null; then
        echo "$udid	$preferred_name"
        return
      fi
    fi
    echo "Skip reload: \"$preferred_name\" is not Booted (no create)." >&2
    return 2
  fi

  if [ "$DEVICE_MODE" = "iphone17" ] || [ "$DEVICE_MODE" = "iphone17_pro_max" ]; then
    ensure_booted_sim_for_mode "$DEVICE_MODE"
    return
  fi

  if [ "$DEVICE_MODE" = "all" ]; then
    booted="$(list_worktree_sims false)"
    if [ -n "$booted" ]; then
      while IFS=$'\t' read -r udid name _state; do
        boot_sim "$udid"
        echo "$udid	$name"
      done <<< "$booted"
      return
    fi
  else
    booted="$(list_worktree_sims true)"
    if [ -n "$booted" ]; then
      while IFS=$'\t' read -r udid name _state; do
        echo "$udid	$name"
      done <<< "$booted"
      return
    fi
  fi

  ensure_booted_sim_for_mode "iphone17"
}

label_status_bar() {
  local udid="$1"

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

build_app() {
  local destination_udid="$1"

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$destination_udid" \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    build
}

find_built_app() {
  local app_dir="$DERIVED_DATA/Build/Products/Debug-iphonesimulator"
  local app="$app_dir/$SCHEME.app"

  if [ -d "$app" ]; then
    echo "$app"
    return
  fi

  find "$app_dir" -maxdepth 1 -name "*.app" ! -name "*-Runner.app" | head -1
}

install_and_launch() {
  local udid="$1"
  local app="$2"
  local bundle_id="$3"

  label_status_bar "$udid"
  xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
  xcrun simctl install "$udid" "$app" >/dev/null

  if [ "${#APP_ARGS[@]}" -gt 0 ]; then
    xcrun simctl launch "$udid" "$bundle_id" "${APP_ARGS[@]}" >/dev/null
  else
    xcrun simctl launch "$udid" "$bundle_id" >/dev/null
  fi
}

run_app() {
  local targets
  local first_udid
  local app
  local bundle_id
  local count=0
  local target_status=0

  set +e
  targets="$(target_sims_for_run)"
  target_status=$?
  set -e

  # 2 = reload-if-booted and preferred sim not Booted (caller should not debounce as success).
  if [ "$target_status" -eq 2 ]; then
    exit 2
  fi
  if [ -z "$targets" ]; then
    exit 0
  fi
  if [ "$target_status" -ne 0 ]; then
    exit "$target_status"
  fi

  first_udid="$(head -1 <<< "$targets" | cut -f1)"

  # One focus call is enough; a second open can spawn extra Simulator windows under races.
  open -a Simulator --args -CurrentDeviceUDID "$first_udid" >/dev/null 2>&1 || open -a Simulator

  build_app "$first_udid"

  app="$(find_built_app)"
  if [ -z "$app" ]; then
    echo "No built .app found." >&2
    exit 1
  fi

  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")"

  while IFS=$'\t' read -r udid name; do
    [ -z "$udid" ] && continue
    install_and_launch "$udid" "$app" "$bundle_id"
    echo "Reloaded $SCHEME on \"$name\""
    count=$((count + 1))
  done <<< "$targets"

  echo "Reloaded $count simulator(s) for worktree \"$SAFE_WORKTREE_NAME\""
}

target_sims_for_management() {
  local device_name
  local sim_name
  local udid

  if [ "$DEVICE_MODE" = "iphone17" ] || [ "$DEVICE_MODE" = "iphone17_pro_max" ]; then
    device_name="$(device_name_for_mode "$DEVICE_MODE")"
    sim_name="$(sim_name_for_device "$device_name")"
    if udid="$(get_sim_udid_by_name "$sim_name" 2>/dev/null)"; then
      echo "$udid	$sim_name"
    fi
    return
  fi

  list_worktree_sims false | while IFS=$'\t' read -r udid name _state; do
    echo "$udid	$name"
  done
}

stop_sim() {
  local targets
  targets="$(target_sims_for_management)"

  if [ -z "$targets" ]; then
    echo "No simulators exist for \"$SIM_PREFIX\""
    exit 0
  fi

  while IFS=$'\t' read -r udid name; do
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    echo "Stopped \"$name\""
  done <<< "$targets"
}

restart_sim() {
  if [ "$DEVICE_MODE" = "default" ]; then
    DEVICE_MODE="all"
  fi

  stop_sim >/dev/null || true
  run_app
}

status_sim() {
  local targets
  targets="$(target_sims_for_management)"

  if [ -z "$targets" ]; then
    echo "No simulators exist for \"$SIM_PREFIX\""
    exit 0
  fi

  while IFS=$'\t' read -r udid _name; do
    xcrun simctl list devices | grep "$udid" || true
  done <<< "$targets"
}

list_all_push_sims() {
  /usr/bin/python3 <<'PY'
import json
import subprocess

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"]))
for runtime, devices in data.get("devices", {}).items():
    if "com.apple.CoreSimulator.SimRuntime.iOS" not in runtime:
        continue
    for device in devices:
        name = device.get("name", "")
        if not name.startswith("Push"):
            continue
        if not device.get("isAvailable", True):
            continue
        print(f"{device.get('udid')}\t{name}\t{device.get('state', '')}")
PY
}

prune_orphan_sims() {
  # Accidental labels from the old basename/branch heuristic and truncated Orca names
  # that are clearly not intentional multi-worktree devices. Never delete stock Xcode sims.
  local udid name state deleted=0

  while IFS=$'\t' read -r udid name state; do
    [ -z "$udid" ] && continue
    case "$name" in
      "Push - Push - "*|"Push - Push")
        ;;
      *)
        continue
        ;;
    esac
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    echo "Pruned \"$name\" ($udid)"
    deleted=$((deleted + 1))
  done < <(list_all_push_sims)

  if [ "$deleted" -eq 0 ]; then
    echo "No orphan Push sims to prune (looked for Push - Push*)."
  else
    echo "Pruned $deleted orphan simulator(s)."
  fi
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
  list)
    list_all_push_sims
    ;;
  prune)
    prune_orphan_sims
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

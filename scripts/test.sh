#!/usr/bin/env bash
# Unified test/build entrypoint for agents and humans.
# Keeps a separate DerivedData tree so stop-hook app builds do not lock build.db.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

PROJECT="Push.xcodeproj"
SCHEME="Push"
# Resolved lazily for suite/full/fast: worktree Push sim via run-ios-sim.sh
# (not stock unlabeled "iPhone 17", which opens a second flaky Simulator).
DESTINATION="${PUSH_TEST_DESTINATION:-}"
DERIVED_DATA="${PUSH_TEST_DERIVED_DATA:-$ROOT/DerivedData-Tests}"
PARALLEL="${PUSH_TEST_PARALLEL:-NO}"
RUN_IOS_SIM="$ROOT/scripts/run-ios-sim.sh"

usage() {
  cat <<EOF
Usage: $0 <command> [args]

Commands:
  build                 Compile Push for generic iOS Simulator (no tests).
  suite <ClassName>     Run one XCTest class (e.g. DataLayerTests).
  full                  Run entire PushTests target (serial by default).
  fast                  Build + a small smoke set (AppEnvironment + AdaptiveLayout).

Env:
  PUSH_TEST_DESTINATION   xcodebuild -destination override
                          (default: worktree sim from run-ios-sim.sh ensure-booted-udid,
                          e.g. Push - main - iPhone 17 — never stock "iPhone 17")
  PUSH_TEST_DERIVED_DATA  derived data path (default: DerivedData-Tests)
  PUSH_TEST_PARALLEL      YES/NO for -parallel-testing-enabled (default: NO)
  PUSH_TEST_DEVICE        --iphone-17 (default) or --iphone-17-pro-max for ensure-booted-udid

Do not run PushUITests unless explicitly asked.
EOF
}

# Resolve destination to the labeled worktree simulator (create/boot via the
# same script that owns visual sims). Explicit PUSH_TEST_DESTINATION wins.
resolve_destination() {
  if [ -n "${DESTINATION:-}" ]; then
    echo "$DESTINATION"
    return
  fi

  local device_flag="${PUSH_TEST_DEVICE:---iphone-17}"
  local udid
  # ensure-booted-udid logs the sim name on stderr; UDID only on stdout.
  udid="$("$RUN_IOS_SIM" ensure-booted-udid "$device_flag")"
  if [ -z "$udid" ]; then
    echo "error: could not resolve worktree simulator UDID via $RUN_IOS_SIM" >&2
    exit 1
  fi
  echo "platform=iOS Simulator,id=$udid"
}

run_xcode() {
  xcodebuild "$@"
}

cmd_build() {
  run_xcode \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    build
  echo "BUILD SUCCEEDED (derivedData: $DERIVED_DATA)"
}

cmd_suite() {
  local class_name="${1:-}"
  if [ -z "$class_name" ]; then
    echo "suite requires a class name, e.g. DataLayerTests" >&2
    exit 2
  fi

  local dest
  dest="$(resolve_destination)"

  run_xcode \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:"PushTests/$class_name" \
    -parallel-testing-enabled "$PARALLEL" \
    test
}

cmd_full() {
  local dest
  dest="$(resolve_destination)"

  run_xcode \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:PushTests \
    -parallel-testing-enabled "$PARALLEL" \
    test
}

cmd_fast() {
  local dest
  dest="$(resolve_destination)"

  run_xcode \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:PushTests/AppEnvironmentTests \
    -only-testing:PushTests/AdaptiveLayoutTests \
    -parallel-testing-enabled "$PARALLEL" \
    test
}

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  build)
    cmd_build
    ;;
  suite)
    cmd_suite "${1:-}"
    ;;
  full)
    cmd_full
    ;;
  fast)
    cmd_fast
    ;;
  ""|-h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac

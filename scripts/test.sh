#!/usr/bin/env bash
# Unified test/build entrypoint for agents and humans.
# Keeps a separate DerivedData tree so stop-hook app builds do not lock build.db.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

PROJECT="Push.xcodeproj"
SCHEME="Push"
# Stock Xcode device for unit tests (not the worktree-scoped Push - main - iPhone 17 visual sim).
DESTINATION="${PUSH_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
DERIVED_DATA="${PUSH_TEST_DERIVED_DATA:-$ROOT/DerivedData-Tests}"
PARALLEL="${PUSH_TEST_PARALLEL:-NO}"

usage() {
  cat <<EOF
Usage: $0 <command> [args]

Commands:
  build                 Compile Push for generic iOS Simulator (no tests).
  suite <ClassName>     Run one XCTest class (e.g. DataLayerTests).
  full                  Run entire PushTests target (serial by default).
  fast                  Build + a small smoke set (AppEnvironment + AdaptiveLayout).

Env:
  PUSH_TEST_DESTINATION   xcodebuild -destination (default: $DESTINATION)
  PUSH_TEST_DERIVED_DATA  derived data path (default: DerivedData-Tests)
  PUSH_TEST_PARALLEL      YES/NO for -parallel-testing-enabled (default: NO)

Do not run PushUITests unless explicitly asked.
EOF
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

  run_xcode \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:"PushTests/$class_name" \
    -parallel-testing-enabled "$PARALLEL" \
    test
}

cmd_full() {
  run_xcode \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:PushTests \
    -parallel-testing-enabled "$PARALLEL" \
    test
}

cmd_fast() {
  run_xcode \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
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

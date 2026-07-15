#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

MODE_FILE=".claude/run-mode"
MODE="live"
if [ -f "$MODE_FILE" ]; then
  MODE="$(cat "$MODE_FILE")"
fi

if [ "$MODE" = "mock" ]; then
  exec ./scripts/run-ios-sim.sh
else
  exec ./scripts/run-ios-sim.sh -- --live
fi

#!/usr/bin/env bash
# Claude/Grok Stop hook: rebuild + reload the preferred Booted sim when Swift changed.
# Safe defaults: lock, debounce, no create, skip docs-only turns, run-mode=off supported.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

MODE_FILE=".claude/run-mode"
LOCK_DIR=".claude/stop-hook.lock"
LAST_RUN_FILE=".claude/stop-hook.last-run"
LAST_HEAD_FILE=".claude/stop-hook.last-head"
LOG_STAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Seconds: skip if a successful reload finished this recently.
DEBOUNCE_SECONDS="${PUSH_STOP_HOOK_DEBOUNCE:-45}"

MODE="live"
if [ -f "$MODE_FILE" ]; then
  MODE="$(tr -d '[:space:]' < "$MODE_FILE")"
fi

log() {
  echo "[$LOG_STAMP] $*"
}

path_is_relevant() {
  # stdin: one path per line
  grep -E '^(Push|PushTests|PushUITests)/|Push\.xcodeproj/' \
    | grep -E '\.(swift|pbxproj|xcconfig|plist)$|Push\.xcodeproj/' >/dev/null 2>&1
}

if [ "$MODE" = "off" ] || [ "$MODE" = "disabled" ]; then
  log "stop-hook: run-mode=$MODE — skipping."
  exit 0
fi

# Non-blocking lock so overlapping agent Stops do not double-build.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "stop-hook: another reload in progress — skipping."
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

if [ -f "$LAST_RUN_FILE" ]; then
  last_epoch="$(cat "$LAST_RUN_FILE" 2>/dev/null || echo 0)"
  now_epoch="$(date +%s)"
  if [ "$((now_epoch - last_epoch))" -lt "$DEBOUNCE_SECONDS" ]; then
    log "stop-hook: debounced (last run ${DEBOUNCE_SECONDS}s window) — skipping."
    exit 0
  fi
fi

relevant_change=false

# Uncommitted edits under app/test sources.
if git status --porcelain --untracked-files=normal -- \
  'Push' 'PushTests' 'Push.xcodeproj' 'PushUITests' 2>/dev/null \
  | sed 's/^...//' \
  | path_is_relevant; then
  relevant_change=true
fi

# After a commit the tree is clean — reload once if HEAD moved and touched sources.
head_stamp="$(git rev-parse HEAD 2>/dev/null || echo none)"
last_head="$(cat "$LAST_HEAD_FILE" 2>/dev/null || true)"
if [ "$relevant_change" = false ] && [ "$head_stamp" != "$last_head" ]; then
  if git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null | path_is_relevant; then
    relevant_change=true
  else
    # Non-source commit (docs only): advance stamp so we do not re-check forever.
    echo "$head_stamp" > "$LAST_HEAD_FILE"
  fi
fi

if [ "$relevant_change" = false ]; then
  log "stop-hook: no Push/PushTests source changes — skipping."
  exit 0
fi

export PUSH_STOP_HOOK=1

set +e
if [ "$MODE" = "mock" ]; then
  log "stop-hook: reload-if-booted (mock)"
  ./scripts/run-ios-sim.sh reload-if-booted --iphone-17
else
  log "stop-hook: reload-if-booted (live)"
  ./scripts/run-ios-sim.sh reload-if-booted --iphone-17 -- --live
fi
status=$?
set -e

if [ "$status" -eq 2 ]; then
  # Preferred sim not Booted — do not debounce; advance HEAD stamp so docs commits stay quiet.
  echo "$head_stamp" > "$LAST_HEAD_FILE"
  log "stop-hook: preferred sim not Booted — no rebuild."
  exit 0
fi

if [ "$status" -ne 0 ]; then
  log "stop-hook: reload failed (exit $status)."
  exit "$status"
fi

date +%s > "$LAST_RUN_FILE"
echo "$head_stamp" > "$LAST_HEAD_FILE"
log "stop-hook: done."

#!/usr/bin/env bash

set -euo pipefail

LABEL="good first issue"
MIN_CODEX_WEEKLY_REMAINING=25

# Exit codes:
#   0 = eligible issue found and returned
#   3 = no eligible issue found
#   4 = Codex weekly remaining usage is too low
#   5 = unable to determine Codex usage
#   other nonzero = unexpected error

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

for command in git gh jq python3 codex; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Error: required command '$command' was not found." >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Codex weekly usage check
#
# Codex exposes rate limits through its app-server JSON-RPC interface.
# The secondary rate-limit window represents the weekly limit.
# Codex returns usedPercent, so:
#
#   remainingPercent = 100 - usedPercent
# ---------------------------------------------------------------------------

get_codex_weekly_remaining_percent() {
  python3 <<'PY'
import json
import select
import subprocess
import sys
import time

TIMEOUT_SECONDS = 15

process = subprocess.Popen(
    [
        "codex",
        "-s",
        "read-only",
        "-a",
        "untrusted",
        "app-server",
    ],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    bufsize=1,
)

if process.stdin is None or process.stdout is None:
    print("Could not open Codex app-server pipes.", file=sys.stderr)
    sys.exit(1)


def send(message):
    process.stdin.write(json.dumps(message) + "\n")
    process.stdin.flush()


def wait_for_response(expected_id):
    deadline = time.monotonic() + TIMEOUT_SECONDS

    while time.monotonic() < deadline:
        remaining = deadline - time.monotonic()

        ready, _, _ = select.select(
            [process.stdout],
            [],
            [],
            max(0, remaining),
        )

        if not ready:
            break

        line = process.stdout.readline()

        if not line:
            break

        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue

        if message.get("id") == expected_id:
            return message

    raise TimeoutError(
        f"Timed out waiting for Codex RPC response id={expected_id}"
    )


try:
    # 1. Initialize RPC connection.
    send({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "clientInfo": {
                "name": "push-automation-usage-check",
                "version": "1.0.0",
            }
        },
    })

    init_response = wait_for_response(1)

    if "error" in init_response:
        raise RuntimeError(
            init_response["error"].get("message", "Codex initialization failed")
        )

    # 2. Complete initialization handshake.
    send({
        "jsonrpc": "2.0",
        "method": "initialized",
        "params": {},
    })

    # 3. Request account rate limits.
    send({
        "jsonrpc": "2.0",
        "id": 2,
        "method": "account/rateLimits/read",
        "params": {},
    })

    usage_response = wait_for_response(2)

    if "error" in usage_response:
        raise RuntimeError(
            usage_response["error"].get(
                "message",
                "Codex rate-limit request failed",
            )
        )

    result = usage_response.get("result") or {}
    rate_limits = result.get("rateLimits") or {}
    weekly = rate_limits.get("secondary") or {}

    used_percent = weekly.get("usedPercent")

    if not isinstance(used_percent, (int, float)):
        raise RuntimeError(
            "Codex did not return a weekly usedPercent value."
        )

    remaining_percent = max(0.0, min(100.0, 100.0 - used_percent))

    # Print only the numeric value to stdout so Bash can capture it.
    print(f"{remaining_percent:.2f}")

except Exception as error:
    print(f"Unable to read Codex weekly usage: {error}", file=sys.stderr)
    sys.exit(1)

finally:
    process.terminate()

    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        process.kill()
PY
}

echo "Checking Codex weekly usage..." >&2

if ! CODEX_WEEKLY_REMAINING="$(get_codex_weekly_remaining_percent)"; then
  echo "Error: unable to determine Codex weekly usage. Refusing to start automation." >&2
  exit 5
fi

echo "Codex weekly remaining: ${CODEX_WEEKLY_REMAINING}%" >&2

# Strictly greater than 25%.
if ! awk \
  -v remaining="$CODEX_WEEKLY_REMAINING" \
  -v minimum="$MIN_CODEX_WEEKLY_REMAINING" \
  'BEGIN { exit !(remaining > minimum) }'
then
  echo "Skipping automation: Codex weekly remaining usage is ${CODEX_WEEKLY_REMAINING}%, which is not above ${MIN_CODEX_WEEKLY_REMAINING}%." >&2
  exit 4
fi

echo "Codex usage check passed: ${CODEX_WEEKLY_REMAINING}% remaining." >&2

# ---------------------------------------------------------------------------
# Find next eligible good-first-issue
# ---------------------------------------------------------------------------

# Shared Git directory across worktrees.
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
LOCK_DIR="$GIT_COMMON_DIR/push-agent-issue-locks"

mkdir -p "$LOCK_DIR"

# Remove stale claims older than 10 hours.
find "$LOCK_DIR" \
  -mindepth 1 \
  -maxdepth 1 \
  -type d \
  -mmin +600 \
  -exec rm -rf {} + 2>/dev/null || true

# Fetch candidate issues once, oldest first.
ISSUES="$(
  gh issue list \
    --state open \
    --label "$LABEL" \
    --limit 100 \
    --json number,title,createdAt,url \
    --jq 'sort_by(.createdAt)'
)"

# Fetch open PR information once.
OPEN_PRS="$(
  gh pr list \
    --state open \
    --limit 200 \
    --json number,title,body,headRefName,url
)"

# Fetch local worktree information once.
WORKTREES="$(git worktree list --porcelain)"

while IFS= read -r ISSUE; do
  NUMBER="$(jq -r '.number' <<< "$ISSUE")"

  # Skip if an open PR appears to implement this issue.
  if jq -e \
    --arg n "$NUMBER" '
      any(.[];
        (.headRefName | test("^issue-" + $n + "(-|$)"))
        or
        (.title | test("#" + $n + "\\b"))
        or
        (
          (.body // "")
          | test(
              "(?i)(close[sd]?|fix(e[sd])?|resolve[sd]?)\\s+#"
              + $n
              + "\\b"
            )
        )
      )
    ' <<< "$OPEN_PRS" >/dev/null; then
    continue
  fi

  # Skip if a local worktree branch already exists for the issue.
  if grep -Eq \
    "branch refs/heads/issue-${NUMBER}(-|$)" \
    <<< "$WORKTREES"; then
    continue
  fi

  # Atomically claim the issue.
  ISSUE_LOCK="$LOCK_DIR/$NUMBER"

  if ! mkdir "$ISSUE_LOCK" 2>/dev/null; then
    continue
  fi

  # Return only the selected issue with full implementation context.
  gh issue view "$NUMBER" \
    --json number,title,body,url,createdAt,comments

  exit 0

done < <(jq -c '.[]' <<< "$ISSUES")

# No eligible issue found.
exit 3
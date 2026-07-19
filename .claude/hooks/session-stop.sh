#!/bin/bash
# Claude Code Stop hook: append one compact record for each distinct project state.
# It deliberately never copies the complete active.md into the history log.

set +e

HOOK_DIR=$(cd -- "${BASH_SOURCE[0]%/*}" 2>/dev/null && pwd)
. "$HOOK_DIR/hook-common.sh"
hook_enter_project || exit 0

STATE_DIR="production/session-state"
LOG_DIR="production/session-logs"
LOCK_DIR="$STATE_DIR/.session-stop.lock"
FINGERPRINT_FILE="$STATE_DIR/.last-session-fingerprint"
LOG_FILE="$LOG_DIR/session-log.md"

mkdir -p "$STATE_DIR" "$LOG_DIR" 2>/dev/null

# Atomic mkdir prevents recursive or concurrent Stop hooks from writing repeatedly.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT INT TERM

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
HEAD_COMMIT=$(git rev-parse --short HEAD 2>/dev/null)
WORKTREE=$(git status --porcelain=v1 2>/dev/null)
STATE_HASH="none"
if [ -f "$STATE_DIR/active.md" ]; then
    STATE_HASH=$(hook_hash_stream < "$STATE_DIR/active.md")
fi

FINGERPRINT=$(printf '%s\n%s\n%s\n%s\n' "$BRANCH" "$HEAD_COMMIT" "$WORKTREE" "$STATE_HASH" | hook_hash_stream)
PREVIOUS=""
[ -f "$FINGERPRINT_FILE" ] && PREVIOUS=$(tr -d '\r\n' < "$FINGERPRINT_FILE")

if [ "$FINGERPRINT" = "$PREVIOUS" ]; then
    exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %z')
{
    echo "## Session state: $TIMESTAMP"
    echo "- Branch: ${BRANCH:-unknown}"
    echo "- HEAD: ${HEAD_COMMIT:-unknown}"
    if [ -n "$WORKTREE" ]; then
        echo "- Working tree:"
        printf '%s\n' "$WORKTREE" | sed 's/^/  - `/' | sed 's/$/`/'
    else
        echo "- Working tree: clean"
    fi
    echo "- Active state hash: $STATE_HASH"
    echo ""
} >> "$LOG_FILE" 2>/dev/null

printf '%s\n' "$FINGERPRINT" > "$FINGERPRINT_FILE" 2>/dev/null
exit 0

#!/usr/bin/env bash
# Two-player co-op test: starts a hosting copy of the game and a joining
# copy (both headless, over 127.0.0.1), lets them play a few steps and
# checks both sides. Exit code 0 = both passed.
#   Tools/coop_test.sh [port]   (default 17777)
# SKIP_IMPORT=1 skips the import (Tools/test.sh imports once for every suite).
set -uo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${1:-17777}"
if [ "${SKIP_IMPORT:-0}" != "1" ]; then
	"$TOOLS_DIR/godot.sh" --headless --xr-mode off --import >/dev/null 2>&1
fi
HOST_LOG="$(mktemp)"
GUEST_LOG="$(mktemp)"
"$TOOLS_DIR/godot.sh" --headless --xr-mode off res://Tests/CoopTest.tscn -- role=host "port=$PORT" >"$HOST_LOG" 2>&1 &
HOST_PID=$!
"$TOOLS_DIR/godot.sh" --headless --xr-mode off res://Tests/CoopTest.tscn -- role=guest "port=$PORT" >"$GUEST_LOG" 2>&1
GUEST_STATUS=$?
wait "$HOST_PID"
HOST_STATUS=$?
for LOG in "$HOST_LOG" "$GUEST_LOG"; do
	grep -E "^  (ok|FAIL)|COOP |SCRIPT ERROR|Parse Error|^ERROR|^WARNING" "$LOG" \
		| grep -vE "leaked at exit|still in use at exit|RID allocations|translation"
done
rm -f "$HOST_LOG" "$GUEST_LOG"
[ "$HOST_STATUS" -eq 0 ] && [ "$GUEST_STATUS" -eq 0 ]

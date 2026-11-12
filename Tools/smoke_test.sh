#!/usr/bin/env bash
# Imports the project and runs the headless smoke test. Exit code 0 = pass.
# Prints only the test lines and real errors (engine exit-leak noise is dropped).
set -uo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$TOOLS_DIR/godot.sh" --headless --xr-mode off --import >/dev/null 2>&1
LOG="$(mktemp)"
"$TOOLS_DIR/godot.sh" --headless --xr-mode off --fixed-fps 60 res://Tests/SmokeTest.tscn >"$LOG" 2>&1
STATUS=$?
grep -E "^  (ok|FAIL)|SMOKE TEST|SCRIPT ERROR|Parse Error|^ERROR|^WARNING" "$LOG" \
	| grep -vE "leaked at exit|still in use at exit|RID allocations"
rm -f "$LOG"
exit $STATUS

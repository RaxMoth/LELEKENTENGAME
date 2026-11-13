#!/usr/bin/env bash
# Runs the headless smoke test. Exit code 0 = pass.
#   Tools/smoke_test.sh [core|full|areas=lab,sales]
#     core (default): the house's skeleton + lab, sales, defense
#     full:           every area (adds cellar, town, towers)
#     areas=a,b:      the skeleton + just those areas (empty: the skeleton)
# Prints only the test lines, the section times and real errors (engine
# exit-leak noise is dropped). SKIP_IMPORT=1 skips the import (Tools/test.sh
# imports once for every suite).
set -uo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-core}" in
	core) SELECTION="scope=core" ;;
	full) SELECTION="scope=full" ;;
	*) SELECTION="$1" ;;
esac
if [ "${SKIP_IMPORT:-0}" != "1" ]; then
	"$TOOLS_DIR/godot.sh" --headless --xr-mode off --import >/dev/null 2>&1
fi
LOG="$(mktemp)"
"$TOOLS_DIR/godot.sh" --headless --xr-mode off --fixed-fps 60 res://Tests/SmokeTest.tscn -- "$SELECTION" >"$LOG" 2>&1
STATUS=$?
grep -E "^  (ok|FAIL|time)|SMOKE TEST|SCRIPT ERROR|Parse Error|^ERROR|^WARNING" "$LOG" \
	| grep -vE "leaked at exit|still in use at exit|RID allocations"
rm -f "$LOG"
exit $STATUS

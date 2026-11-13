#!/usr/bin/env bash
# Every test a change needs, as fast as it goes: imports the project once,
# then runs the unit tests and the smoke test side by side, and the co-op
# test after them. Exit code 0 = all passed.
#   Tools/test.sh          core: unit tests + core smoke test + co-op test (before a PR)
#   Tools/test.sh full     the same with the full smoke test (CI on main)
#   Tools/test.sh quick    unit tests + core smoke test, no co-op (while working)
# Each suite's output follows, then one line per suite with its time.
set -uo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-core}"
SMOKE_SCOPE="core"
[ "$MODE" = "full" ] && SMOKE_SCOPE="full"
export SKIP_IMPORT=1

seconds_since() { echo $(( $(date +%s) - $1 )); }

START=$(date +%s)
"$TOOLS_DIR/godot.sh" --headless --xr-mode off --import >/dev/null 2>&1
IMPORT_SECONDS=$(seconds_since "$START")

UNIT_LOG="$(mktemp)"
SMOKE_LOG="$(mktemp)"
UNIT_START=$(date +%s)
"$TOOLS_DIR/unit_tests.sh" >"$UNIT_LOG" 2>&1 &
UNIT_PID=$!
"$TOOLS_DIR/smoke_test.sh" "$SMOKE_SCOPE" >"$SMOKE_LOG" 2>&1
SMOKE_STATUS=$?
SMOKE_SECONDS=$(seconds_since "$UNIT_START")
wait "$UNIT_PID"
UNIT_STATUS=$?
UNIT_SECONDS=$(seconds_since "$UNIT_START")

echo "==== unit tests ===="
grep -E "Overall Summary|FAILED|Failed|failure|SCRIPT ERROR|Parse Error" "$UNIT_LOG" | sed 's/\x1b\[[0-9;]*m//g'
echo "==== smoke test ($SMOKE_SCOPE) ===="
cat "$SMOKE_LOG"
rm -f "$UNIT_LOG" "$SMOKE_LOG"

COOP_STATUS=0
COOP_SECONDS=0
if [ "$MODE" != "quick" ]; then
	echo "==== co-op test ===="
	COOP_START=$(date +%s)
	"$TOOLS_DIR/coop_test.sh"
	COOP_STATUS=$?
	COOP_SECONDS=$(seconds_since "$COOP_START")
fi

result() { [ "$1" -eq 0 ] && echo "pass" || echo "FAIL"; }
echo
echo "import   ${IMPORT_SECONDS} s"
echo "unit     $(result $UNIT_STATUS)  ${UNIT_SECONDS} s (in parallel with the smoke test)"
echo "smoke    $(result $SMOKE_STATUS)  ${SMOKE_SECONDS} s ($SMOKE_SCOPE)"
[ "$MODE" != "quick" ] && echo "co-op    $(result $COOP_STATUS)  ${COOP_SECONDS} s"
echo "total    $(seconds_since "$START") s"
[ "$UNIT_STATUS" -eq 0 ] && [ "$SMOKE_STATUS" -eq 0 ] && [ "$COOP_STATUS" -eq 0 ]

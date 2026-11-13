#!/usr/bin/env bash
# Every test a change needs, as fast as it goes: imports the project once,
# runs the unit tests and the smoke test side by side, then the co-op test.
# Exit code 0 = all passed.
#   Tools/test.sh [base]  changed (default): the unit tests, the smoke test
#                         for just the areas the changes since [base]
#                         (default origin/main) touch, and the co-op test
#                         when co-op code changed (Tools/affected_areas.sh;
#                         shared code runs everything). CI on pull requests.
#   Tools/test.sh quick   unit tests + core smoke test, no co-op
#   Tools/test.sh core    unit tests + core smoke test + co-op test
#   Tools/test.sh full    unit tests + full smoke test + co-op test (CI on main)
# Each suite's output follows, then one line per suite with its time.
set -uo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-changed}"
RUN_SMOKE="yes"
RUN_COOP="yes"
case "$MODE" in
	quick) SMOKE_SELECTION="core"; RUN_COOP="no" ;;
	core) SMOKE_SELECTION="core" ;;
	full) SMOKE_SELECTION="full" ;;
	*)
		# "changed", or a base ref to compare with.
		BASE="origin/main"
		[ "$MODE" != "changed" ] && BASE="$MODE"
		echo "==== what changed since $BASE ===="
		eval "$("$TOOLS_DIR/affected_areas.sh" "$BASE")"
		RUN_SMOKE="$SMOKE"
		RUN_COOP="$COOP"
		if [ "$AREAS" = "full" ]; then
			SMOKE_SELECTION="full"
		else
			SMOKE_SELECTION="areas=$AREAS"
		fi
		MODE="changed"
		;;
esac
export SKIP_IMPORT=1

seconds_since() { echo $(( $(date +%s) - $1 )); }
result() { [ "$1" -eq 0 ] && echo "pass" || echo "FAIL"; }

START=$(date +%s)
"$TOOLS_DIR/godot.sh" --headless --xr-mode off --import >/dev/null 2>&1
IMPORT_SECONDS=$(seconds_since "$START")

UNIT_LOG="$(mktemp)"
SMOKE_LOG="$(mktemp)"
UNIT_START=$(date +%s)
"$TOOLS_DIR/unit_tests.sh" >"$UNIT_LOG" 2>&1 &
UNIT_PID=$!
SMOKE_STATUS=0
if [ "$RUN_SMOKE" = "yes" ]; then
	"$TOOLS_DIR/smoke_test.sh" "$SMOKE_SELECTION" >"$SMOKE_LOG" 2>&1
	SMOKE_STATUS=$?
fi
SMOKE_SECONDS=$(seconds_since "$UNIT_START")
wait "$UNIT_PID"
UNIT_STATUS=$?
UNIT_SECONDS=$(seconds_since "$UNIT_START")

echo "==== unit tests ===="
sed 's/\x1b\[[0-9;]*m//g' "$UNIT_LOG" | grep -E "Overall Summary|FAILED|SCRIPT ERROR|Parse Error"
if [ "$RUN_SMOKE" = "yes" ]; then
	echo "==== smoke test ($SMOKE_SELECTION) ===="
	cat "$SMOKE_LOG"
fi
rm -f "$UNIT_LOG" "$SMOKE_LOG"

COOP_STATUS=0
COOP_SECONDS=0
if [ "$RUN_COOP" = "yes" ]; then
	echo "==== co-op test ===="
	COOP_START=$(date +%s)
	"$TOOLS_DIR/coop_test.sh"
	COOP_STATUS=$?
	COOP_SECONDS=$(seconds_since "$COOP_START")
fi

echo
echo "import   ${IMPORT_SECONDS} s"
echo "unit     $(result $UNIT_STATUS)  ${UNIT_SECONDS} s"
if [ "$RUN_SMOKE" = "yes" ]; then
	echo "smoke    $(result $SMOKE_STATUS)  ${SMOKE_SECONDS} s ($SMOKE_SELECTION, side by side with the unit tests)"
else
	echo "smoke    skipped (nothing the game runs changed)"
fi
if [ "$RUN_COOP" = "yes" ]; then
	echo "co-op    $(result $COOP_STATUS)  ${COOP_SECONDS} s"
else
	echo "co-op    skipped"
fi
echo "total    $(seconds_since "$START") s"
[ "$UNIT_STATUS" -eq 0 ] && [ "$SMOKE_STATUS" -eq 0 ] && [ "$COOP_STATUS" -eq 0 ]

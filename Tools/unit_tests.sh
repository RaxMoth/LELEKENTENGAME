#!/usr/bin/env bash
# Runs the gdUnit4 unit tests in Tests/Unit headlessly. Exit code 0 = pass.
# HTML/XML reports go to build/test-reports. Extra arguments go to gdUnit4
# (e.g. -a res://Tests/Unit/lane_grid_test.gd to run one suite).
# SKIP_IMPORT=1 skips the import (Tools/test.sh imports once for every suite).
set -uo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "${SKIP_IMPORT:-0}" != "1" ]; then
	"$TOOLS_DIR/godot.sh" --headless --xr-mode off --import >/dev/null 2>&1
fi
# --remote-debug to an unbound port stops Godot's interactive CLI debugger
# from waiting for input when a test script fails to parse.
"$TOOLS_DIR/godot.sh" --headless --xr-mode off -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
	-rd build/test-reports -rc 3 -a res://Tests/Unit "$@"

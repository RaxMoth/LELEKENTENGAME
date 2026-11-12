#!/usr/bin/env bash
# Runs the gdUnit4 unit tests in Tests/Unit headlessly. Exit code 0 = pass.
# HTML/XML reports go to build/test-reports. Extra arguments go to gdUnit4
# (e.g. -a res://Tests/Unit/lane_grid_test.gd to run one suite).
set -uo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$TOOLS_DIR/godot.sh" --headless --import >/dev/null 2>&1
# --remote-debug to an unbound port stops Godot's interactive CLI debugger
# from waiting for input when a test script fails to parse.
"$TOOLS_DIR/godot.sh" --headless -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
	-rd build/test-reports -a res://Tests/Unit "$@"

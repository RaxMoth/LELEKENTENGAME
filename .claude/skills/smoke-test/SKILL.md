---
name: smoke-test
description: Run the gdUnit4 unit tests and the headless Godot smoke test (boots every menu and level, pause/win/lose/results, popups, save round-trip) and report failures. Use after changing any .gd, .tscn or .tres file and before committing.
allowed-tools:
  - Bash(Tools/unit_tests.sh*)
  - Bash(Tools/smoke_test.sh)
---
Run from the project root, in this order (exit code 0 = pass):

1. `Tools/unit_tests.sh`: gdUnit4 suites in `Tests/Unit/` (fast, pure logic).
   One suite: `Tools/unit_tests.sh -a res://Tests/Unit/grid_data_test.gd`.
2. `Tools/smoke_test.sh`: imports, then runs `res://Tests/SmokeTest.tscn`.

- Pass: report the check count in one line.
- Fail: list each `FAIL`/`FAILED` line and every `SCRIPT ERROR` / `Parse Error`, open
  the scripts they point to, find the cause and fix it, then run again.
  Don't weaken or delete a check to make it pass.
- If Godot isn't found, tell the user to set `GODOT=/path/to/Godot` (4.7+).

The smoke test resets the local `user://` savegame of this project.

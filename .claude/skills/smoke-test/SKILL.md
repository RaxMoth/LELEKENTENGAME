---
name: smoke-test
description: Run the tests (gdUnit4 unit tests, the headless Godot smoke test playing the house through the XR pointer path in the flat simulator, and the two-player co-op test) and report failures. Use after changing any .gd, .tscn or .tres file and before committing.
allowed-tools:
  - Bash(Tools/test.sh*)
  - Bash(Tools/unit_tests.sh*)
  - Bash(Tools/smoke_test.sh*)
  - Bash(Tools/coop_test.sh*)
  - Bash(Tools/affected_areas.sh*)
---
Run from the project root (exit code 0 = pass):

- `Tools/test.sh`: imports once, runs the unit tests and the smoke test for
  just the areas the changes since `origin/main` touch (it lists the files
  and their areas; shared code runs everything), then the co-op test when
  co-op code changed, and prints one line per suite with its time — what CI
  runs on a PR. `Tools/test.sh quick` (unit + core smoke), `core` (+ co-op),
  `full` (every area + co-op, as CI does on `main`).
- One part only: `Tools/unit_tests.sh` (one suite:
  `Tools/unit_tests.sh -a res://Tests/Unit/lane_grid_test.gd`),
  `Tools/smoke_test.sh [core|full|areas=lab,sales]`, `Tools/coop_test.sh`. Set
  `SKIP_IMPORT=1` when the project was just imported.

- Pass: report the check counts and the total time in one line.
- Fail: list each `FAIL`/`FAILED` line and every `SCRIPT ERROR` / `Parse Error`, open
  the scripts they point to, find the cause and fix it, then run again.
  Don't weaken or delete a check to make it pass.
- If Godot isn't found, tell the user to set `GODOT=/path/to/Godot` (4.7+).

The smoke and co-op tests reset the local `user://` savegame of this project.

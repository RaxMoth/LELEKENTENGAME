@Docs/instructor.md

## Golden rules

1. **Professional, clean design, always.** Nothing may look childish or like
   programmer art. Follow `Docs/DESIGN.md`: `Palette` colors and theme
   variations only, icons from `Assets/Icons` (never text glyphs like `●` or `★`),
   one primary action per screen, 8 px spacing. Verify visual changes with
   screenshots (`/design-review`) before calling them done.
2. **VR only.** This repo is one game: a VR crime-sim run out of one house
   (working title Porchlight VR, `Docs/GAME.md`). The house is the only
   world — no levels or level select, one day after another. It is a 3D
   scene inheriting `LevelBase` (which owns the `XRPlayerRig`); UI in it lives
   in the world (no screen-space HUD); input is controller pointers; hold
   the headset refresh rate on a Quest; no camera motion the player didn't
   make; pooled spawning. Only the menus are 2D (the no-headset flow), and
   the house must stay playable in the rig's flat simulator.
3. **Typed, documented GDScript** following `Docs/instructor.md`; state in StateCharts.
4. **Nothing is done until the tests pass:** `Tools/test.sh` (exit 0): one
   import, the unit tests and the smoke test for just the areas your
   changes touch (`Tools/affected_areas.sh`; shared code runs everything),
   the co-op test when co-op code changed — what CI runs on a PR.
   `Tools/test.sh full` runs everything (CI on `main`). New pure logic gets
   a gdUnit4 suite in `Tests/Unit/`; a new area folder gets a line in
   `Tools/affected_areas.sh`.
5. **Data over code.** Tunables in Resources / `Ressources/game_config.tres`.
6. **Two developers, one `main`.** Two people develop this game in parallel,
   each with Claude. Follow `Docs/WORKFLOW.md`:
   - Never commit or push to `main`. Start every task on a fresh branch
     `<name>/<topic>` from an up-to-date `main` (`git switch main && git pull
     --ff-only && git switch -c <name>/<topic>`); ask the user for their name
     prefix if it isn't clear from the branch they are on.
   - Only commit, push or open a PR when the user asks. Before a PR: bring
     the branch up to date with `origin/main`, run `Tools/test.sh`, then
     `gh pr create` with the template filled in.
   - Never push to the other person's branch, never force-push except
     `--force-with-lease` on your own branch.
   - Before committing, check `git diff` and drop editor rewrites you didn't
     intend (`.import` churn, renumbered `unique_id`s).
   - Shared hotspots (`House.tscn`, `game_config.tres`, `types.gd`,
     `translations.csv`, `project.godot`): keep edits minimal and in place;
     prefer new files and sub-scenes over growing these.

## Working in this repo

- Team workflow (branches, PRs, CI, shared hotspots, scene conflicts):
  `Docs/WORKFLOW.md`. CI (`.github/workflows/tests.yml`) runs both test
  scripts on every PR.
- Target engine: Godot 4.7 with OpenXR. The game, controls, headset setup
  and design decisions: `Docs/GAME.md`; API overview: `Docs/SYSTEMS.md`; adding
  levels and content: `Docs/GETTING_STARTED.md`; visuals: `Docs/DESIGN.md`.
- `Tools/godot.sh <args>` runs Godot from the project root (finds it via
  `$GODOT`, `PATH` or `/Applications/Godot.app`). Use it instead of a bare `godot`.
- Tests: `Tools/test.sh [changed|quick|core|full]` runs everything below
  with one import. `Tools/unit_tests.sh` (gdUnit4, `Tests/Unit/*_test.gd`, extend
  `GdUnitTestSuite`; classes under test must not need autoloads),
  `Tools/smoke_test.sh [core|full|areas=lab,sales]` (the house's skeleton
  plus the chosen areas; each area's checks run on their own) and
  `Tools/coop_test.sh` (host + guest; on PRs only when co-op code changes). Screenshots + contact sheets:
  `Tools/screenshots.sh build/screenshots`.
- Project skills: `/smoke-test`, `/design-review`, `/new-level <Name>`,
  `/new-popup <Name>`. Review before committing with the `godot-reviewer` agent.
- Scene/resource file rules load from `.claude/rules/godot-scene-files.md`
  when you touch `.tscn`/`.tres` files.
- The game is split into three areas that two people develop in parallel:
  defense (`Scenes/Levels/House/Garden/`), customers (`.../Sales/`) and the
  house (`.../Lab/`, `.../Office/`, the level). Stay inside the area you were
  asked to work on; the contract between areas is in
  `Scenes/Levels/House/README.md`.
- The `godot` MCP server (`.mcp.json`) gives GDScript diagnostics from the
  running editor's language server (`get_diagnostics`,
  `scan_workspace_diagnostics`) and its console output. It needs the Godot
  editor open on this project.

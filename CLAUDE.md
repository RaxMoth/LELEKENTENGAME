@Docs/instructor.md

## Golden rules

1. **Professional, clean design, always.** Nothing may look childish or like
   programmer art. Follow `Docs/DESIGN.md`: `Palette` colors and theme
   variations only, icons from `Assets/Icons` (never text glyphs like `●` or `★`),
   one primary action per screen, 8 px spacing. Verify visual changes with
   screenshots (`/design-review`) before calling them done.
2. **Mobile first.** Touch input, safe areas, 60 FPS on mid-range phones, pooled spawning.
3. **Typed, documented GDScript** following `Docs/instructor.md`; state in StateCharts.
4. **Nothing is done until the tests pass:** `Tools/unit_tests.sh` and
   `Tools/smoke_test.sh` (exit 0). New pure logic gets a gdUnit4 suite in `Tests/Unit/`.
5. **Data over code.** Tunables in Resources / `Ressources/game_config.tres`.

## Working in this repo

- Target engine: Godot 4.7. API overview: `Docs/SYSTEMS.md`; starting a new
  game: `Docs/GETTING_STARTED.md`; visuals: `Docs/DESIGN.md`; 3D / XR and the
  Porchlight VR prototype: `Docs/VR.md`.
- `Tools/godot.sh <args>` runs Godot from the project root (finds it via
  `$GODOT`, `PATH` or `/Applications/Godot.app`). Use it instead of a bare `godot`.
- Tests: `Tools/unit_tests.sh` (gdUnit4, `Tests/Unit/*_test.gd`, extend
  `GdUnitTestSuite`; classes under test must not need autoloads) and
  `Tools/smoke_test.sh` (whole game). Screenshots + contact sheets:
  `Tools/screenshots.sh build/screenshots`.
- Project skills: `/smoke-test`, `/design-review`, `/new-level <Name>`,
  `/new-popup <Name>`. Review before committing with the `godot-reviewer` agent.
- Scene/resource file rules load from `.claude/rules/godot-scene-files.md`
  when you touch `.tscn`/`.tres` files.
- The `godot` MCP server (`.mcp.json`) gives GDScript diagnostics from the
  running editor's language server (`get_diagnostics`,
  `scan_workspace_diagnostics`) and its console output. It needs the Godot
  editor open on this project.

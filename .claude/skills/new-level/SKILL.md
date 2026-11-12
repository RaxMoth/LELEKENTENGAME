---
name: new-level
description: Scaffold a new playable level or game mode that inherits LevelBase, with its script, LevelData resource and registration in game_config.tres.
argument-hint: "[LevelName] [short description]"
disable-model-invocation: true
---
Create a level named `$0` (PascalCase) following `Docs/GETTING_STARTED.md`
section 2 and `Docs/instructor.md`:

1. `Scenes/Levels/$0/$0.tscn`: an inherited scene of
   `res://Scenes/Game/LevelBase/LevelBase.tscn` (root `instance=` the base,
   like `Scenes/Examples/Runner/Runner.tscn`). Gameplay nodes go under `World`.
2. `Scenes/Levels/$0/<snake_case>_level.gd`: `extends LevelBase`, with a `##`
   header doc and only the hooks it needs (`_on_level_setup`,
   `_on_level_started`, `_level_physics_process`, ...). Call `add_score()`,
   `win()`, `lose()` or `end_run()`. Fully typed. Tunables as `@export`.
3. `Ressources/Levels/<snake_case>.tres`: a `LevelData` with `id`, `title`,
   `description`, `scene_path`, star thresholds and rewards; add it to
   `levels` in `Ressources/game_config.tres`.
4. Art: `PlaceholderShape` with `Palette` colors (see `Docs/DESIGN.md`).
5. Run the `smoke-test` skill (it plays every configured level) and the
   `design-review` skill for the new level (`level=<id>`).

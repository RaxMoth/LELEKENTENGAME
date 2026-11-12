---
name: new-level
description: Scaffold a new playable VR level that inherits LevelBase, with its script, LevelData resource and registration in game_config.tres.
argument-hint: "[LevelName] [short description]"
disable-model-invocation: true
---
Create a level named `$0` (PascalCase) following `Docs/GETTING_STARTED.md`
section 2 and `Docs/instructor.md`:

1. `Scenes/Levels/$0/$0.tscn`: an inherited scene of
   `res://Scenes/Game/LevelBase/LevelBase.tscn` (root `instance=` the base,
   like `Scenes/Levels/House/House.tscn`). Build the stage under
   `World` (a `WorldEnvironment` with fog of the horizon color, scenery, a
   `WalkableArea` wired to `rig.walkable_area` in `_on_level_setup`),
   override `World/XRPlayerRig`'s transform to where the player stands and
   `World/Announcer`'s to a spot in their view.
2. `Scenes/Levels/$0/<snake_case>_level.gd`: `extends LevelBase`, with a `##`
   header doc and only the hooks it needs (`_on_level_setup`,
   `_on_level_started`, `_level_physics_process`, ...). Input comes from
   `rig` signals (`primary_action_pressed(pointer)`, ...) connected in the
   scene; pick with `RayMath` on the pointer ray. Call `add_score()`,
   `announce()`, `win()`, `lose()` or `end_run()`. Fully typed. Tunables as `@export`.
3. Status UI in the world: a `Control` scene on a `WorldScreen` (see
   `Sales/SalesBoard.tscn`) or `Label3D`s — never a screen-space HUD.
4. `Ressources/Levels/<snake_case>.tres`: a `LevelData` with `id`, `title`,
   `description`, `scene_path`, star thresholds and rewards; add it to
   `levels` in `Ressources/game_config.tres`.
5. Art: `PlaceholderMesh3D` + `BlobShadow3D` with `Palette` colors (see
   `Docs/DESIGN.md`); frequent spawns through `Pools.spawn()`; positional
   sound with `Audio.play_sfx_at()`.
6. Run the `smoke-test` skill (it plays every configured level in the flat
   simulator) and the `design-review` skill for the new level (`level=<id>`,
   at `--resolution 1280x720`).

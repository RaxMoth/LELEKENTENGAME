# Agent Instructor — Godot Mobile Game Base Template

## Project Overview

This is a **Godot 4.7+** reusable base template targeting **2D mobile games**
(also exports to Web/desktop). The renderer is **GL Compatibility** for the widest
Android/iOS device support. The viewport is `720×1280` portrait with
`canvas_items` stretch and `expand` aspect. Every architectural decision must
reflect that this runs on low-to-mid-range Android and iOS devices.

This is not a prototype. It is a production-quality, scalable, maintainable
template: no shortcuts, no quick hacks, no throwaway variables. Every system is
designed to be extended cleanly by future developers. See
[SYSTEMS.md](SYSTEMS.md) for the API and [GETTING_STARTED.md](GETTING_STARTED.md)
for starting a new game.

---

## Project Structure

```
res://
├── Assets/          # Textures, audio, fonts, themes, icons, localization (read-only at runtime)
├── Docs/            # Documentation (DESIGN.md = design system)
├── Globals/         # Autoloads ONLY (scripts, plus scenes for UI / SceneManager / Debug)
├── Ressources/      # .tres data instances (game_config, levels, upgrades...)
├── Scenes/          # .tscn files by domain; .gd here only if attached to a scene in the same folder
│   ├── Boot/        # Main scene (splash)
│   ├── Menus/       # MainMenu, LevelSelect, Shop
│   ├── Game/        # LevelBase — every level inherits it
│   ├── Entities/    # Reusable gameplay entities (player, enemy, projectile, pickups, XR rig...)
│   ├── Levels/      # The game's own levels, one folder each (Porchlight = the XR prototype)
│   ├── UI/          # HUD and popups
│   └── Examples/    # Self-contained example games (deletable per folder)
├── Scripts/         # Standalone class_name scripts (not tied to one scene)
│   ├── Components/  # Composable node components
│   ├── Resources/   # Resource schemas (data definitions)
│   ├── Profile/     # Persistent player-data modules
│   ├── Services/    # Ads / store / analytics provider base classes
│   ├── UI/          # Reusable UI controls
│   ├── Input/       # Gesture detection
│   ├── XR/          # 3D / XR building blocks (XRPointer, WorldScreen)
│   └── Utils/       # Helpers and data structures
├── Tests/           # Smoke test, screenshot tool, Unit/ gdUnit4 suites (excluded from exports)
├── Tools/           # Shell helpers: godot.sh, smoke_test.sh, screenshots.sh (ignored by Godot)
└── addons/
    ├── godot_state_charts/   # State chart library — always use this for state management
    └── gdUnit4/              # Unit test framework (editor/tests only, excluded from exports)
```

Respect the folder color-coding in `project.godot`. Never place files in the wrong directory.

---

## Core Principles — Non-Negotiable

### 1. Mobile First
- Target 60 FPS on mid-range devices (Snapdragon 7xx equivalent); the Battery
  Saver setting caps at 30 FPS — design for both.
- No heavy shaders, no CPU-heavy per-frame algorithms, no `SubViewport` unless essential.
- All UI is designed for **touch** — minimum touch target 48×48 dp (≈ 88 px at 720 wide).
- HUD/UI lives on `CanvasLayer`s, independent from the game camera.
- UI uses **anchors and containers** — never hardcoded pixel positions for layout.
- Every full-screen UI starts with a `SafeAreaContainer` (notches, rounded corners).
- Layouts must work for tall (20:9) and short (16:9) phones and tablets.

### 2. Signals over Direct References
- Nodes communicate through **signals**; cross-system communication goes through
  the `Events` bus.
- Every signal has explicit parameter types:
  ```gdscript
  signal health_changed(current_health: float, max_health: float)
  ```
- Static connections are made in the scene (`[connection]` / signal dock);
  `connect()` in code only for dynamic connections.
- Never use `call_group()` as fire-and-forget — use typed signals.

### 3. State Management via godot_state_charts
- Entity and flow state (player, enemies, level flow) is managed with the
  `godot_state_charts` addon. No hand-rolled state machines for those.
- Use `CompoundState` for hierarchy (`Alive > { Idle, Moving }`), `ParallelState`
  for independent dimensions, `AtomicState` for leaves.
- Transitions are `Transition` nodes with an `event`. Events are sent only with
  `Types.EVENT_*` constants — never magic strings in code.
- Connect `state_entered`, `state_exited`, `state_processing`,
  `state_physics_processing` to the owner's methods. Movement/physics belongs in
  `state_physics_processing`.
- Simple stateless helpers (a tower that always aims, a projectile) may use
  `_physics_process` directly.

### 4. Typed GDScript — No Exceptions
- Every variable, parameter, return type and loop variable is explicitly typed
  (`debug/gdscript/warnings/untyped_declaration` is set to warn):
  ```gdscript
  var base_movement_speed: float = 300.0
  func apply_damage(damage_amount: float) -> void:
  for enemy: Node2D in nearby_enemies:
  ```
- Descriptive names only — no `x`, `i`, `hp`, `spd`.
- Designer-facing values use `@export` with `@export_group`.
- `const` for compile-time constants; `static var` only for truly shared state.
- Don't name members after engine members (`priority`, `visible`...) and don't
  use `class_name`s that collide with engine classes.
- Prefer a native node when the engine has one (e.g. `TouchJoystick` extends
  Godot's `VirtualJoystick` and only adds pause/scene-change safety).

### 5. Resource-Driven Data (No Hardcoding)
- Tunable data lives in custom `Resource` classes (`Scripts/Resources/`) with
  instances in `Ressources/` or as sub-resources of the scene that owns them.
- `Ressources/game_config.tres` (`GameConfig.get_default()`) is the single entry
  point for game-wide data: scenes, currencies, levels, upgrades, products,
  achievements, daily rewards, energy and ad pacing.
- Levels read per-level tuning from `LevelData.custom_parameters`.

### 6. Autoloads — Focused Services
Autoloads are services with one responsibility each. Current set and why they exist:

| Autoload | Reason it must be global |
|---|---|
| `Types` | Shared constants/enums; no state |
| `Global` | Stateless helpers; **must not hold mutable state** |
| `Events` | Decoupled cross-system signals |
| `Platform` | OS notifications (pause/resume/back) arrive at the root |
| `Settings` | Preferences must apply before any scene loads |
| `SaveManager` | One owner of the savegame file |
| `Profile` | Persistent player data shared by every scene |
| `Audio` | Music must survive scene changes |
| `Pools` | Pools outlive individual spawners; cleared on scene change |
| `Analytics`, `Ads`, `Store` | SDK facades must exist once per app |
| `UI` | Popups/toasts overlay every scene and survive pausing |
| `SceneManager` | Owns scene swaps and the transition overlay |
| `Debug` | Developer overlay (removes itself in release builds) |

Do not add new autoloads without a documented reason in this table. Prefer a
`ProfileModule`, a component, a `Resource` or a signal on `Events`.

---

## Scene and Script Architecture

### Levels
Every playable level/mode is an **inherited scene of
`Scenes/Game/LevelBase/LevelBase.tscn`** with a script that `extends LevelBase`.
LevelBase owns the flow StateChart (`Intro → Playing ⇄ Paused → Won | Lost`),
HUD, pause, results, rewards, saving and analytics. Levels override hooks
(`_on_level_setup`, `_on_level_started`, `_level_physics_process`, ...) and call
`add_score()`, `win()`, `lose()`, `end_run()`.

### Composition over inheritance
- Entities are composed of components from `Scripts/Components/`
  (Health, Hurtbox, Hitbox, Velocity, Targeting, Shooter, Stats...).
- Components communicate **signals upward, method calls downward**.
- Components are wired with exported node references in the scene
  (`HurtboxComponent.health_component`), never `get_parent()`.
- `Global.find_component(node, ComponentClass)` is allowed for queries on other
  entities (e.g. targeting reading an enemy's health).

### Entity StateChart layout (recommended)
```
EntityRoot (CharacterBody2D / Node2D)
├── Visual (Sprite / AnimatedSprite2D / PlaceholderShape)
├── CollisionShape2D
├── ...components
└── StateChart
    └── Root (CompoundState)
        ├── Alive (CompoundState) { Idle, Moving, Attacking... }
        └── Dead (AtomicState)    # Dead → Alive on Types.EVENT_RESPAWN for pooled entities
```

### Duck-typed hooks
Optional methods whose names live in `Types.METHOD_*`:
`receive_scene_params(params)`, `handle_back() -> bool`,
`_on_pool_spawned()`, `_on_pool_despawned()`,
`apply_wave_modifiers(health_multiplier, speed_multiplier)`.

---

### 3D / XR scenes
See [VR.md](VR.md). In short:
- The player is an `XRPlayerRig`; it runs a flat simulator when no headset is
  connected, so every XR scene must stay playable (and testable) without one.
- A screen-space overlay is invisible inside a headset: UI is a normal
  `Control` scene shown on a `WorldScreen`; popups reach the player through
  `UI.set_world_space_enabled()` (the rig does this).
- Pick with `RayMath` on simple shapes instead of physics raycasts where you
  can; spawn with `Pools.spawn_3d()`; art stand-ins are `PlaceholderMesh3D` +
  `BlobShadow3D` (no real-time shadows — they are too expensive on standalone
  headsets).
- No artificial camera motion (no shake, no forced movement); the player's
  head owns the camera.

## Performance Rules

- Physics logic in `state_physics_processing` (or `_physics_process` for
  stateless helpers) — never in `_process`.
- `CharacterBody2D` for controlled/AI movers; `Area2D` for triggers, hit/hurt boxes, pickups.
- Anything spawned often (projectiles, pickups, enemies, damage numbers) goes
  through `Pools.spawn()` / `Pools.despawn()`. Never `instantiate()` +
  `queue_free()` in a hot path. Pooled scripts reset in `_on_pool_spawned()` and
  guard callbacks with `Pools.is_in_pool(self)`.
- Never toggle collision objects inside physics callbacks — defer.
- Throttle expensive queries (targeting re-evaluates on an interval).
- Share textures via atlases; UI shares one `Theme` (`Assets/Themes/main_theme.tres`).
- `preload()` assets that always exist; `load()` optional/runtime ones and null-check.

---

## UI Architecture

- HUD: `Scenes/UI/HUD/` (used by LevelBase). Popups: `Scenes/UI/Popups/` (extend `BasePopup`).
  Screens: `Scenes/Menus/`.
- Open popups with `UI.open_popup(scene, data)` and await `.closed`.
- HUD and popups emit signals — they never run game logic.
- Visuals follow [DESIGN.md](DESIGN.md): colors from `Palette` (code) and the
  theme / its type variations (UI), icons from `Assets/Icons` via `IconLabel`
  or Button icons — never text glyphs (`●`, `★`, `♥`) as icons, no per-node
  color/size overrides unless intentional. It must look professional and
  clean, never childish.
- Game-world touch input uses `_unhandled_input` (or `GestureDetector`), so UI
  buttons consume their touches first. Touch controls that must live under the
  HUD (joystick) use `_gui_input` on a lower `CanvasLayer`.
- Use `BaseButton` subclasses for interactive UI (they get automatic feedback).

---

## Code Style and Documentation

### File Header
Every `.gd` script starts with a `##` doc comment: purpose, usage, dependencies.

### Naming Conventions
| Element | Convention | Example |
|---|---|---|
| Script class | PascalCase | `class_name HealthComponent` |
| Variables | snake_case, descriptive | `current_movement_direction` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_ENEMY_AGGRO_RANGE` |
| Signals | snake_case, past tense | `health_changed`, `target_acquired` |
| Functions | snake_case, verb-first | `calculate_damage_reduction()` |
| StateChart events | `StringName` constants in `Types` | `Types.EVENT_DIED` |
| Scene files | PascalCase | `TopDownPlayer.tscn` |
| Script files | snake_case | `top_down_player.gd` |

### Comments
- Public API (signals, exports, public methods) has `##` doc comments.
- Inline `#` comments explain **why**, not what.
- No `TODO` without an owner or issue.

---

## What the Agent Must Never Do

- **Never** use `$NodeName` — use `@onready var node: Type = %UniqueName`.
- **Never** use `get_node("/root/SomeSingleton")` — use autoload names.
- **Never** hardcode StateChart event strings in code — use `Types.EVENT_*`.
- **Never** put game state in `Global`.
- **Never** skip static typing.
- **Never** `queue_free()` a pooled node — `Pools.despawn()` it.
- **Never** create autoloads for things that can be a Resource, component,
  ProfileModule or `Events` signal.
- **Never** place `.gd` files in `Scenes/` that aren't attached to a `.tscn` in the
  same folder (examples may keep their example-only resource scripts with them).
- **Never** hand-roll a state machine where `godot_state_charts` fits.
- **Never** design for mouse/keyboard first — touch is primary.

---

## Checklist Before Committing Any Change

- [ ] All new variables, parameters and loop variables are typed and descriptive
- [ ] New signals have typed parameters
- [ ] Entity/flow state goes through a StateChart with `Types.EVENT_*`
- [ ] Components are wired via exported references, not `get_parent()`
- [ ] UI uses anchors/containers inside a `SafeAreaContainer`
- [ ] Frequently spawned objects use `Pools`
- [ ] New tunable data lives in a Resource / `game_config.tres`
- [ ] Doc comments on all public API
- [ ] Visual changes follow `Docs/DESIGN.md` and were checked with screenshots
- [ ] New pure logic has a gdUnit4 suite in `Tests/Unit/`; `Tools/unit_tests.sh` passes
- [ ] `Tools/smoke_test.sh` passes

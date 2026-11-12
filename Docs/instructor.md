# Agent Instructor — Porchlight VR (working title)

## Project Overview

This is a single **VR game** on **Godot 4.7+**: a crime-sim run out of one
house — craft in the lab, sell at the back window, defend the front door,
all at once (working title Porchlight VR, see [GAME.md](GAME.md)). It runs
through **OpenXR** on standalone headsets (Meta Quest, Android) and PC
headsets (SteamVR, Windows). The renderer is **GL Compatibility** for the
widest standalone-headset support. Every architectural decision must reflect
that a standalone headset is a phone that renders two eyes at 72–90 Hz.

Levels are 3D scenes played in the headset. Without one, the same scenes run
in the `XRPlayerRig`'s flat simulator (development, tests, a desktop
fallback). The **menus** (main menu, level select, shop) are the only 2D
screens: the flat-screen flow, at a `720×1280` portrait viewport with
`canvas_items` stretch and `expand` aspect. Inside a headset the game boots
straight into the XR start level and popups appear on an in-world screen.

This is not a prototype. It is production-quality, scalable, maintainable
code: no shortcuts, no quick hacks, no throwaway variables. Every system is
designed to be extended cleanly by future developers. See
[SYSTEMS.md](SYSTEMS.md) for the API and [GETTING_STARTED.md](GETTING_STARTED.md)
for adding levels and content.

---

## Project Structure

```
res://
├── Assets/          # Textures, audio, fonts, themes, icons, localization (read-only at runtime)
├── Docs/            # Documentation (DESIGN.md = design system)
├── Globals/         # Autoloads ONLY (scripts, plus scenes for UI / SceneManager / Debug)
├── Ressources/      # .tres data instances (game_config, levels, upgrades...)
├── Scenes/          # .tscn files by domain; .gd here only if attached to a scene in the same folder
│   ├── Boot/        # Main scene (splash; routes to the XR level or the menus)
│   ├── Menus/       # MainMenu, LevelSelect, Shop (2D, flat-screen flow)
│   ├── Game/        # LevelBase — every level inherits it (3D, owns the XR rig)
│   ├── Entities/    # Reusable entities (XRPlayerRig, pooled 3D effects)
│   ├── Levels/      # The game's levels: House (Lab, Sales, Garden, Office, Workers)
│   └── UI/          # Popups (shown on the in-world screen inside a headset)
├── Scripts/         # Standalone class_name scripts (not tied to one scene)
│   ├── Components/  # Composable node components
│   ├── Game/        # Pure game rules (timing, quality, stash, sales, heat, day clock)
│   ├── Resources/   # Resource schemas (data definitions)
│   ├── Profile/     # Persistent player-data modules
│   ├── Services/    # Ads / store / analytics provider base classes
│   ├── UI/          # Reusable UI controls (menus, popups, in-world screens)
│   ├── XR/          # XR building blocks (pointer, screens, locomotion, grab, sockets, buttons)
│   └── Utils/       # Helpers, ray / lane math, 3D placeholders
├── Tests/           # Smoke test, screenshot tool, Unit/ gdUnit4 suites (excluded from exports)
├── Tools/           # Shell helpers: godot.sh, smoke_test.sh, screenshots.sh (ignored by Godot)
└── addons/
    ├── godot_state_charts/   # State chart library — always use this for state management
    └── gdUnit4/              # Unit test framework (editor/tests only, excluded from exports)
```

Respect the folder color-coding in `project.godot`. Never place files in the wrong directory.

---

## Core Principles — Non-Negotiable

### 1. VR First
- Hold the headset's refresh rate (72 Hz on Quest 2, 90 Hz on Quest 3 / PC
  headsets) on a standalone headset — a dropped frame is felt, not just seen.
  Never cap the frame rate; the headset paces frames.
- No heavy shaders, no full-screen effects on standalone (bloom is off there),
  no real-time shadows (`BlobShadow3D` instead), no CPU-heavy per-frame
  algorithms, a `SubViewport` only where it shows UI in the world.
- **Comfort:** no artificial camera motion — no shake, no forced movement, no
  locomotion the player didn't ask for; the horizon and ground stay fixed;
  important things sit inside a ~100° arc in front of the player.
- **No screen-space UI in levels:** a headset can't see a `CanvasLayer`.
  Status lives on `WorldScreen`s / `Label3D`s in the world; popups go through
  the rig's in-world popup screen.
- **Input is controller pointers and hands:** `XRPlayerRig` signals
  (`primary_action_pressed`, `secondary_action_pressed`, `menu_pressed`,
  `item_grabbed`, `item_placed`), `XRPointer` rays, `Grabbable` /
  `ItemSocket` / `PointerButton` for hand interaction and `XRLocomotion`
  for movement. Grip grabs; the dominant trigger uses, the off-hand trigger
  is the second action. The flat simulator maps mouse and WASD onto the same
  API, so every level must stay playable without a headset.
- **Shared state in one place:** a level's game state (the house's stash,
  heat, prices) lives in one node (`Operation`) that every front reads and
  writes — the seam for co-op replication later.
- **Menus (2D, flat flow):** touch targets ≥ 48×48 dp (≈ 88 px at 720 wide),
  anchors and containers (never hardcoded positions), a `SafeAreaContainer`
  at the root, layouts that work on tall and short windows.

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
  for enemy: LaneEnemy in nearby_enemies:
  ```
- Descriptive names only — no `x`, `i`, `hp`, `spd`.
- Designer-facing values use `@export` with `@export_group`.
- `const` for compile-time constants; `static var` only for truly shared state.
- Don't name members after engine members (`priority`, `visible`...) and don't
  use `class_name`s that collide with engine classes.
- Prefer a native node when the engine has one (e.g. `XRPlayerRig` extends
  Godot's `XROrigin3D` and uses its `XRCamera3D` / `XRController3D` nodes).

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
| `Platform` | OS notifications (pause/resume/back) arrive at the root; headset detection |
| `Settings` | Preferences must apply before any scene loads |
| `SaveManager` | One owner of the savegame file |
| `Profile` | Persistent player data shared by every scene |
| `Audio` | Music must survive scene changes |
| `Pools` | Pools outlive individual spawners; cleared on scene change |
| `Analytics`, `Ads`, `Store` | SDK facades must exist once per app |
| `UI` | Popups/toasts overlay every scene, survive pausing, and render into the in-world screen in a headset |
| `SceneManager` | Owns scene swaps and the transition overlay; sends a headset player "home" to the XR start level |
| `Coop` | The two-player network session (host / join, players, discovery) must outlive level reloads, and its RPC node path must be the same on both players |
| `Debug` | Developer overlay (removes itself in release builds) |

Do not add new autoloads without a documented reason in this table. Prefer a
`ProfileModule`, a component, a `Resource` or a signal on `Events`.

---

## Scene and Script Architecture

### Levels
Every playable level is an **inherited scene of
`Scenes/Game/LevelBase/LevelBase.tscn`** (a `Node3D`) with a script that
`extends LevelBase`. LevelBase owns the `XRPlayerRig` (`rig`), the in-world
`Announcer` (`announce()`), the flow StateChart (`Intro → Playing ⇄ Paused →
Won | Lost`), pause (controller menu button, Esc, back), results, rewards,
saving and analytics. Levels build their stage under `World`, place the rig
and announcer, override hooks (`_on_level_setup`, `_on_level_started`,
`_level_physics_process`, ...) and call `add_score()`, `win()`, `lose()`,
`end_run()`.

### The House: fronts
The House level is split into fronts (`FrontGarden`, `SalesWindow`, `Lab`,
`Office`), each a `HouseFront` scene owned by one area. A front gets a
`HouseContext` (level, rig, `Operation`, `DayCycle`) at setup, keeps its own
nodes, data and logic, and reports back only through `HouseFront`'s signals.
Fronts never reference each other; shared state goes through `Operation`.
New area data goes into the area's own folders and upgrade catalog.

### Composition over inheritance
- Entities are composed of components from `Scripts/Components/`
  (Health, HitFlash3D, WaveSpawner...) plus small scene-local scripts.
- Components communicate **signals upward, method calls downward**.
- Components are wired with exported node references in the scene
  (`HitFlash3DComponent.health_component`), never `get_parent()`.
- `Global.find_component(node, ComponentClass)` is allowed for queries on other
  entities (e.g. a defender reading an attacker's health).

### Entity StateChart layout (recommended)
```
EntityRoot (Node3D)
├── Visual (PlaceholderMesh3D / imported mesh) + BlobShadow3D
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

### XR scenes
See [GAME.md](GAME.md). In short:
- The player is the `XRPlayerRig` in `LevelBase`; it runs a flat simulator
  when no headset is connected, so every level must stay playable (and
  testable) without one.
- A screen-space overlay is invisible inside a headset: UI is a normal
  `Control` scene shown on a `WorldScreen`; popups reach the player through
  `UI.set_world_space_enabled()` (the rig does this).
- Pick with `RayMath` on simple shapes instead of physics raycasts where you
  can; spawn with `Pools.spawn()`; art stand-ins are `PlaceholderMesh3D` +
  `BlobShadow3D` (no real-time shadows — they are too expensive on standalone
  headsets).
- Sound is positional (`Audio.play_sfx_at()`), so the player hears where
  things happen.
- No artificial camera motion (no shake, no forced movement); the player's
  head owns the camera.

## Performance Rules

- Physics logic in `state_physics_processing` (or `_physics_process` for
  stateless helpers) — never in `_process`.
- Prefer ray / lane math (`RayMath`, `LaneGrid`) over physics bodies; if you
  need physics, `Area3D` for triggers and `CharacterBody3D` for movers.
- Anything spawned often (attackers, customers, items, bolts, floating text, effects) goes
  through `Pools.spawn()` / `Pools.despawn()`. Never `instantiate()` +
  `queue_free()` in a hot path. Pooled scripts reset in `_on_pool_spawned()` and
  guard callbacks with `Pools.is_in_pool(self)`.
- Never toggle collision objects inside physics callbacks — defer.
- Throttle expensive queries (targeting re-evaluates on an interval).
- Share meshes and materials (`PlaceholderMesh3D` caches them); UI shares one
  `Theme` (`Assets/Themes/main_theme.tres`).
- Keep in-world UI viewports few and small; a `WorldScreen` that rarely
  changes should not redraw every frame.
- `preload()` assets that always exist; `load()` optional/runtime ones and null-check.

---

## UI Architecture

- In-level UI: `Control` scenes shown on a `WorldScreen` in the level (e.g.
  `Scenes/Levels/House/Sales/SalesBoard.tscn`) and `Label3D`s; no HUD.
  Popups: `Scenes/UI/Popups/` (extend `BasePopup`; inside a headset they show
  on the rig's in-world popup screen). Menus: `Scenes/Menus/` (2D, flat flow).
- Open popups with `UI.open_popup(scene, data)` and await `.closed`.
- In-world UI and popups emit signals — they never run game logic.
- Visuals follow [DESIGN.md](DESIGN.md): colors from `Palette` (code) and the
  theme / its type variations (UI), icons from `Assets/Icons` via `IconLabel`
  or Button icons — never text glyphs (`●`, `★`, `♥`) as icons, no per-node
  color/size overrides unless intentional. It must look professional and
  clean, never childish.
- Game input comes from `XRPlayerRig` signals with an `XRPointer`. Pointers
  click `WorldScreen`s first; only presses that hit no screen reach the game.
  The flat simulator's mouse / touch handling lives in the rig — levels never
  read raw mouse or touch events.
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
| Scene files | PascalCase | `XRPlayerRig.tscn` |
| Script files | snake_case | `xr_player_rig.gd` |

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
  same folder (a level may keep its level-only base classes with it, like
  `LaneEnemy` / `LaneDefender` in `Scenes/Levels/House/Garden/`).
- **Never** hand-roll a state machine where `godot_state_charts` fits.
- **Never** design for mouse/keyboard first — tracked controllers are
  primary; the flat simulator is the fallback, not the target.
- **Never** add screen-space UI (a `CanvasLayer` HUD) to a level, or move the
  camera the player didn't move.
- **Never** cap the frame rate or add per-frame work that would drop a
  standalone headset below its refresh rate.

---

## Checklist Before Committing Any Change

- [ ] All new variables, parameters and loop variables are typed and descriptive
- [ ] New signals have typed parameters
- [ ] Entity/flow state goes through a StateChart with `Types.EVENT_*`
- [ ] Components are wired via exported references, not `get_parent()`
- [ ] Level UI lives in the world (WorldScreen / Label3D); menus use
      anchors/containers inside a `SafeAreaContainer`
- [ ] The level still plays in the flat simulator (the smoke test drives it)
- [ ] Frequently spawned objects use `Pools`
- [ ] New tunable data lives in a Resource / `game_config.tres`
- [ ] Doc comments on all public API
- [ ] Visual changes follow `Docs/DESIGN.md` and were checked with screenshots
- [ ] New pure logic has a gdUnit4 suite in `Tests/Unit/`; `Tools/unit_tests.sh` passes
- [ ] `Tools/smoke_test.sh` passes

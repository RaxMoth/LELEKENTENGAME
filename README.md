# Porchlight VR

A lane-defense game you stand inside. You are on the porch of a house at
night; a lawn of five lanes stretches away to a gate. Attackers come through
the gate and walk down the lanes. Plant defenders on the lawn, catch the
sparks that pay for them with your controller beams, and shoot what gets
through with the blaster in your other hand. Three attackers on the porch and
the run is over. How to play, headset setup and design decisions:
[Docs/VR.md](Docs/VR.md).

- **Engine:** Godot 4.7+ (tested on 4.7.2), GDScript, fully typed
- **VR:** OpenXR — standalone headsets (Meta Quest, `Meta Quest` export
  preset) and PC headsets through SteamVR (`Windows Desktop` preset)
- **Renderer:** GL Compatibility (widest standalone-headset support)
- **No headset?** The same game runs in a flat simulator (mouse / touch),
  which is how it is developed on macOS and how the smoke test plays it
- **Addons:** [godot_state_charts](addons/godot_state_charts) 0.22.5 for entity and level state,
  [gdUnit4](addons/gdUnit4) 6.2.3 for unit tests (editor/tests only, excluded from exports)

Open `project.godot` and press **F5**. With a headset session (SteamVR /
Quest Link) you start on the porch; without one you get the 2D menus →
Play → First Night in the flat simulator.

> **Status.** Game logic, UI and the pointer → world-screen input path are
> covered by the unit and smoke tests in the flat simulator. The OpenXR path
> (headset rendering, controller tracking, haptics) follows Godot's API but
> has not been run on a headset yet.

---

## What's inside

### The game (`Scenes/Levels/Porchlight/`)

Three defenders (Sparkbloom, Boltbloom, Stonecap), four attackers (Husk,
Dasher, Brute and flying Wisps only your blaster reaches), five waves, a
seed board above the gate (a 2D UI on a `WorldScreen`), positional sound and
controller haptics. All tuning is data (`Ressources/`, exports on the scenes).

### VR foundation

| Piece | Purpose |
|---|---|
| `LevelBase` (`Scenes/Game/`) | 3D base scene of every level: owns the `XRPlayerRig`, an in-world announcer and the flow StateChart (Intro → Playing ⇄ Paused → Won / Lost), score, results, rewards, saving, analytics |
| `XRPlayerRig` | Headset camera + two controllers with pointers; falls back to a flat simulator without a headset; one signal API for both |
| `XRPointer`, `WorldScreen` (`Scripts/XR/`) | Controller rays that click ordinary `Control` UI shown on panels in the world |
| `UI.set_world_space_enabled()` | Pause, results, settings and other popups appear on an in-world screen in front of the player |
| `RayMath`, `LaneGrid` | Picking and lane combat without physics bodies (cheap on standalone headsets) |
| `PlaceholderMesh3D`, `BlobShadow3D`, `HitFlash3DComponent`, pooled `FloatingText3D` / `PopEffect3D` | 3D stand-in art and feedback with shared meshes and materials |

### Core services (autoloads, `Globals/`)

| Autoload | Purpose |
|---|---|
| `Types` | Enums, groups, input / XR action names, StateChart event names |
| `Global` | Stateless helpers: component queries, spawn root, `await Global.wait()` |
| `Events` | Typed global event bus (currency, levels, achievements, ads, app lifecycle…) |
| `Platform` | Headset detection, platform checks, safe area for the menus, app pause/resume, back button |
| `Settings` | Volumes, controller haptics, FPS readout, language — persisted in `user://settings.cfg` |
| `SaveManager` | Versioned, crash-safe JSON savegame with backup, debounced autosave, migrations |
| `Profile` | Player data modules: wallet, inventory, level stars, upgrades, stats, achievements, daily rewards, energy |
| `Audio` | Music cross-fades, pooled positional 3D SFX, built-in synthesized UI sounds |
| `Pools` | Object pooling for attackers, bolts, sparks and effects |
| `Analytics` / `Ads` / `Store` | Provider-based facades with working mocks — plug in a real store / analytics SDK later |
| `UI` | Popup stack, confirm dialogs, toasts, loading overlay, in-world popup viewport for headsets |
| `SceneManager` | Fade transitions, scene params, back stack; sends a headset player "home" to the XR start level |
| `Debug` | FPS/memory overlay + cheat panel (F3 or 5 taps top-left), stripped from release builds |

### Menus & UI kit

The menus (main menu, level select, shop) are the 2D, flat-screen flow; the
popups (settings, pause, results with rewarded-ad ×2, reward, achievements,
confirm) work on screen and on the in-world popup screen. A clean,
professional dark UI defined in [Docs/DESIGN.md](Docs/DESIGN.md): `Palette`
color tokens, a generated theme, an SVG icon set, app icon + logo, and
components (`IconLabel`, `RewardList`, currency & energy pills, stars).

### Data-driven game definition

Everything a designer tunes lives in [`Ressources/game_config.tres`](Ressources/game_config.tres):
currencies, levels (with star thresholds and rewards), the XR start level,
shop upgrades, in-app products, achievements, 7-day login rewards,
energy/lives, ad pacing.

---

## Working on the game

Add levels (new nights, new places), defenders, attackers, waves and
upgrades: [Docs/GETTING_STARTED.md](Docs/GETTING_STARTED.md) ·
API reference: [Docs/SYSTEMS.md](Docs/SYSTEMS.md) ·
Coding rules: [Docs/instructor.md](Docs/instructor.md) ·
Design system: [Docs/DESIGN.md](Docs/DESIGN.md)

---

## Testing

```bash
Tools/unit_tests.sh    # gdUnit4 unit tests in Tests/Unit (pure logic, ~0.1 s)
Tools/smoke_test.sh    # boots the whole game
```

Unit tests cover pure logic (number formatting, ray math, the lane grid,
upgrade costs, level stars); add a `*_test.gd` suite next to them for new
logic. Reports land in `build/test-reports`. The smoke test boots every menu
and level, plays Porchlight through the same pointer → world-screen path a
headset uses (in the flat simulator), exercises pause / win / lose /
results, every popup and the save round-trip (exit code 0 = pass; it resets
the local save). `Tools/screenshots.sh build/screenshots` captures the menus,
popups and the game plus contact sheets for design reviews or store
listings. Both find Godot via `$GODOT`, `PATH` or `/Applications/Godot.app`.

---

## Claude Code setup

The repo is ready for [Claude Code](https://claude.com/claude-code):

| Piece | What it does |
|---|---|
| `CLAUDE.md` + `Docs/instructor.md` | Golden rules: VR-only architecture, typing, headset performance and comfort, professional design |
| `.claude/skills/` | `/smoke-test` (unit + smoke tests), `/design-review` (screenshots checked against DESIGN.md), `/new-level`, `/new-popup` |
| `.claude/agents/godot-reviewer.md` | Reviews a diff against the coding and design rules before committing |
| `.claude/rules/godot-scene-files.md` | Hand-editing rules for `.tscn`/`.tres`, loaded only when those files are touched |
| `.claude/settings.json` | Keeps keystores and export credentials out of Claude's reach |
| `.mcp.json` | [minimal-godot-mcp](https://github.com/ryanmazzolini/minimal-godot-mcp): GDScript diagnostics and console output from the open editor (Node 22+, approve once on first start) |

---

## Folder structure

```
Assets/        Themes, icons, fonts, audio, sprites, localization CSV
Docs/          VR.md (the game), getting started, systems reference, coding rules, design system
Globals/       Autoloads only (UI, SceneManager and Debug have scenes)
Ressources/    .tres data: game_config, levels, defenders, upgrades
Scenes/
  Boot/        Splash scene (main scene): headset → game, otherwise → menus
  Menus/       MainMenu, LevelSelect, Shop (2D, flat-screen flow)
  Game/        LevelBase — 3D, owns the XR rig; every level inherits it
  Entities/    XRPlayerRig, pooled 3D effects
  Levels/      Porchlight (the game)
  UI/          Popups (in-world screen inside a headset)
Scripts/
  Components/  Health, hit flash, wave spawner
  Resources/   Data schemas (GameConfig, LevelData, DefenderData, UpgradeData…)
  Profile/     Persistent player-data modules
  Services/    Ads / store / analytics provider base classes
  UI/          Reusable UI controls (menus, popups, in-world screens)
  XR/          XRPointer, WorldScreen
  Utils/       Ray / lane math, 3D placeholders, formatting, tweens, synth SFX
Tests/         Smoke test, screenshot tool, unit tests (excluded from exports)
Tools/         godot.sh, smoke_test.sh, screenshots.sh (ignored by Godot)
```

## License

MIT — use freely in any project.

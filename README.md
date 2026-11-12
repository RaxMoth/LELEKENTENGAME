# Godot Mobile 2D Base Template

A mobile-first foundation for 2D Godot games. Copy it, rename it, delete the
examples you don't need, and start building your game instead of the plumbing.

- **Engine:** Godot 4.7+ (tested on 4.7.2), GDScript, fully typed
- **Renderer:** GL Compatibility (widest Android/iOS/Web device support)
- **Layout:** 720×1280 portrait, `canvas_items` stretch + `expand` aspect, notch-safe UI
- **Addons:** [godot_state_charts](addons/godot_state_charts) 0.22.5 for entity and level state,
  [gdUnit4](addons/gdUnit4) 6.2.3 for unit tests (editor/tests only, excluded from exports)

Open `project.godot` and press **F5**: boot splash → main menu → level select →
five playable example games.

---

## What's inside

### Core services (autoloads, `Globals/`)

| Autoload | Purpose |
|---|---|
| `Types` | Enums, physics layers, groups, input actions, StateChart event names |
| `Global` | Stateless helpers: group queries, spawn root, geometry, `await Global.wait()` |
| `Events` | Typed global event bus (currency, levels, achievements, ads, app lifecycle…) |
| `Platform` | Mobile detection, notch safe area, haptics, app pause/resume, Android back button |
| `Settings` | Volumes, haptics, screen shake, battery saver, language — persisted in `user://settings.cfg` |
| `SaveManager` | Versioned, crash-safe JSON savegame with backup, debounced autosave, migrations |
| `Profile` | Player data modules: wallet, inventory, level stars, upgrades, stats, achievements, daily rewards, energy |
| `Audio` | Music cross-fades, pooled SFX, built-in synthesized UI sounds (no assets needed) |
| `Pools` | Object pooling for bullets, pickups, enemies, damage numbers |
| `Analytics` / `Ads` / `Store` | Provider-based facades with working mocks — plug in AdMob / Play Billing / StoreKit later |
| `UI` | Popup stack, confirm dialogs, toasts, loading overlay, automatic button feedback |
| `SceneManager` | Fade transitions, scene params, back stack, back-button routing |
| `Debug` | FPS/memory overlay + cheat panel (F3 or 5 taps top-left), stripped from release builds |

### Gameplay building blocks (`Scripts/Components/`)

Health, hurtbox/hitbox damage, projectiles (homing, pierce), velocity movement
with knockback, platformer movement (coyote time, jump buffer, double jump),
targeting (nearest/strongest/first-on-path), shooter (fire rate, spread,
multi-shot), pickups + magnet collector, loot tables, hit flash, health bars,
path following, wave spawner (markers / ring / path), stats with modifiers,
abilities with cooldowns, game camera (follow, shake, pinch-zoom, pan), tap areas.

### Design system & UI kit

A clean, professional dark UI defined in [Docs/DESIGN.md](Docs/DESIGN.md):
`Palette` color tokens, a generated theme (primary / secondary / success /
danger / ghost / card / icon buttons, cards, chips, pills), a 17-icon SVG set
(coin, gem, star, bolt, trophy…), app icon + logo, and components:
`IconLabel`, `RewardList`, currency & energy pills, stars, touch joystick,
cooldown button, HUD, and popups: confirm, settings, pause, results (with
rewarded-ad ×2), reward, achievements, perk choice. Gameplay placeholders are
drawn as soft-shaded vector shapes, so prototypes already look polished.

### Data-driven game definition

Everything a designer tunes lives in [`Ressources/game_config.tres`](Ressources/game_config.tres):
currencies, levels (with star thresholds and rewards), shop upgrades,
in-app products, achievements, 7-day login rewards, energy/lives, ad pacing.

### XR prototype (`Scenes/Levels/Porchlight/`)

**Porchlight VR** is a lane-defense game you stand inside: plant blooms on a
lawn in front of your porch, catch sparks with your pointer and shoot what
gets through. It runs on OpenXR headsets and, without one, in a flat
simulator (mouse / touch) from Level Select. See [Docs/VR.md](Docs/VR.md).

### Example games (`Scenes/Examples/`) — one folder each, delete what you don't need

| Example | Shows |
|---|---|
| **Idle Tapper** | Clicker, persistent upgrades, passive + offline income, reward popup |
| **Arena Survivor** | Joystick, auto-fire, enemy waves, XP gems, level-up perks, active ability, meta-upgrades |
| **Tower Defense** | Path enemies, tap-to-build/upgrade towers, first-on-path targeting, lives & gold |
| **Match-3 Puzzle** | Grid matching, swipe + tap input, gravity/refill, cascades, moves & target score |
| **Endless Runner** | One-tap jumps, parallax, pooled obstacles, ramping speed, best score |

---

## Start a new game

1. Copy this repository and open it in Godot.
2. Set your name in **Project Settings → Application** and in `game_config.tres`.
3. Set the package / bundle id in **Project → Export** (`com.yourstudio.yourgame`).
4. New level: **Scene → New Inherited Scene** from `Scenes/Game/LevelBase/LevelBase.tscn`,
   attach a script that `extends LevelBase`, add a `LevelData` to `game_config.tres`.
5. Delete the example folders you don't need and remove their levels from the config.

Full checklist: [Docs/GETTING_STARTED.md](Docs/GETTING_STARTED.md) ·
API reference: [Docs/SYSTEMS.md](Docs/SYSTEMS.md) ·
Coding rules: [Docs/instructor.md](Docs/instructor.md) ·
Design system: [Docs/DESIGN.md](Docs/DESIGN.md)

---

## Testing

```bash
Tools/unit_tests.sh    # gdUnit4 unit tests in Tests/Unit (pure logic, ~0.1 s)
Tools/smoke_test.sh    # boots the whole game
```

Unit tests cover pure logic (number formatting, grid/match rules, upgrade
costs, level stars); add a `*_test.gd` suite next to them for new logic.
Reports land in `build/test-reports`. The smoke test boots every menu and level, exercises pause / win / lose / results, every
popup and the save round-trip (exit code 0 = pass; it resets the local save).
`Tools/screenshots.sh build/screenshots` captures every screen plus contact
sheets for design reviews or store listings. Both find Godot via `$GODOT`,
`PATH` or `/Applications/Godot.app`.

---

## Claude Code setup

The repo is ready for [Claude Code](https://claude.com/claude-code):

| Piece | What it does |
|---|---|
| `CLAUDE.md` + `Docs/instructor.md` | Golden rules: architecture, typing, mobile performance, professional design |
| `.claude/skills/` | `/smoke-test` (unit + smoke tests), `/design-review` (screenshots checked against DESIGN.md), `/new-level`, `/new-popup` |
| `.claude/agents/godot-reviewer.md` | Reviews a diff against the coding and design rules before committing |
| `.claude/rules/godot-scene-files.md` | Hand-editing rules for `.tscn`/`.tres`, loaded only when those files are touched |
| `.claude/settings.json` | Keeps keystores and export credentials out of Claude's reach |
| `.mcp.json` | [minimal-godot-mcp](https://github.com/ryanmazzolini/minimal-godot-mcp): GDScript diagnostics and console output from the open editor (Node 22+, approve once on first start) |

---

## Folder structure

```
Assets/        Themes, icons, fonts, audio, sprites, localization CSV
Docs/          Getting started, systems reference, coding rules, design system
Globals/       Autoloads only (UI, SceneManager and Debug have scenes)
Ressources/    .tres data: game_config, levels, upgrades
Scenes/
  Boot/        Splash scene (main scene)
  Menus/       MainMenu, LevelSelect, Shop
  Game/        LevelBase — inherit this for every level
  Entities/    Reusable player, enemy, projectile, pickups, floating text
  UI/          HUD and popups
  Examples/    Self-contained example games
Scripts/
  Components/  Node components (health, hitbox, shooter, spawner, camera…)
  Resources/   Data schemas (GameConfig, LevelData, UpgradeData…)
  Profile/     Persistent player-data modules
  Services/    Ads / store / analytics provider base classes
  UI/          Reusable UI controls
  Input/       Gesture detector
  Utils/       Formatting, tweens, grid, placeholder art, synth SFX
Tests/         Smoke test and screenshot tool (excluded from exports)
Tools/         godot.sh, smoke_test.sh, screenshots.sh (ignored by Godot)
```

## License

MIT — use freely in any project.

# Getting Started

This repository is one game: **Porchlight VR**, a lane-defense game you
play standing on a porch in a headset ([VR.md](VR.md)). It is built on a
VR-only foundation: every level is a 3D scene with the `XRPlayerRig`, UI
lives in the world, and only the menus are 2D screens (the flat flow when no
headset is connected). Do the first section right away; the rest when you
need it.

## 1. Make it yours (10 minutes)

- [ ] Open `project.godot` in Godot 4.7+.
- [ ] **Project Settings → Application → Config:** name, description, version, icon.
- [ ] **`Ressources/game_config.tres`:** `game_title`, store URLs, privacy policy URL.
- [ ] **Project → Export:** set `package/unique_name` on the **Meta Quest**
      preset, e.g. `com.yourstudio.yourgame`, and the `.exe` name on
      **Windows Desktop** (SteamVR). Never change the package after publishing.
- [ ] Press **F5**. Without a headset you get the menus and the game in the
      flat simulator; with SteamVR / a Quest Link session you land in the game.

## 2. Add a level (a new night, a new place)

1. **Scene → New Inherited Scene** → `Scenes/Game/LevelBase/LevelBase.tscn`.
2. Save it as `Scenes/Levels/<Name>/<Name>.tscn`.
3. Attach a new script to the root that `extends LevelBase`.
4. Build the stage under **World** (`PlaceholderMesh3D` stand-ins, a
   `WorldEnvironment`), move **World/XRPlayerRig** to where the player
   stands and **World/Announcer** into their view.
5. Show status on in-world UI: a `WorldScreen` with a `Control` scene (like
   Porchlight's `SeedBoard`) or a `Label3D`. Never a screen-space HUD.
6. Override the hooks you need:

```gdscript
extends LevelBase

func _on_level_setup() -> void:      # build / connect things (before the intro)
	rig.primary_action_pressed.connect(_on_trigger)

func _on_level_started() -> void:    # after "Ready? Go!" on the announcer
	announce(tr("Hold the line!"))

func _level_physics_process(delta: float) -> void:  # only runs while playing
	pass

func _on_trigger(pointer: XRPointer) -> void:
	var hit_distance: float = RayMath.intersect_ground(pointer.ray_origin, pointer.ray_direction)
	...
```

7. Call `add_score(points)`, `win()`, `lose()` (or `end_run()` for endless modes).
8. Create a `LevelData` resource (right-click `Ressources/Levels` → New Resource →
   LevelData), set `id`, `title`, `scene_path`, star thresholds and rewards, and
   add it to `game_config.tres → levels`. It now appears in Level Select with
   stars, best score, unlocking, rewards, analytics and the results screen.
   To make it the level a headset player starts in, set
   `game_config.tres → xr_start_level_id`.

Pause (controller menu / B / Y, Esc, Android back), headset removal, the
time limit (`time_limit_seconds`), the results popup on the in-world screen,
rewarded "×2", interstitial pacing and progress saving are handled by
`LevelBase`. `/new-level <Name>` scaffolds all of this.

Without a headset the level runs in the rig's flat simulator (drag to look,
click to act), which is also what the smoke test drives — keep it playable.

## 3. Grow Porchlight

- **Defenders:** a `DefenderData` in `Ressources/Defenders/` plus a scene
  extending `LaneDefender`; add it to the level's `defenders` array.
- **Attackers:** a scene like `Husk.tscn` (pooled `LaneEnemy`, StateChart
  `Alive { Advancing ⇄ Attacking } → Dead`); tune with exports.
- **Waves:** `WaveData` entries on the level's `WaveSpawner`.
- **Shop upgrades:** an `UpgradeData` in `Ressources/Upgrades/`, listed in
  `game_config.tres → upgrades`, read with `Profile.upgrades.get_value()`
  (see `starting_sparks_upgrade` on `Porchlight.tscn`).
- Run `Tools/unit_tests.sh` and `Tools/smoke_test.sh` afterwards.

## 4. Art, fonts, audio

- **Design system:** read [DESIGN.md](DESIGN.md) first. Re-skin by changing
  `Scripts/Utils/palette.gd` and the matching theme colors.
- **Theme:** `Assets/Themes/main_theme.tres` — colors, corner radius and font sizes
  for every control. Type variations: `TitleLabel`, `OverlayLabel`, `HeaderLabel`,
  `AccentLabel`, `SmallLabel`, `CaptionLabel`, `BigNumberLabel`, `SecondaryButton`,
  `SuccessButton`, `DangerButton`, `GhostButton`, `DangerGhostButton`,
  `CardButton`, `IconButton`, `CardPanel`, `ChipPanel`, `PillPanel`,
  `TopBarPanel`, `ToastPanel`.
- **Branding:** replace `icon.svg` (app icon) and `Assets/Branding/logo.svg`
  (main menu and splash).
- **Icons:** `Assets/Icons/*.svg` (96 px, white glyphs tinted at runtime).
- **Font:** drop a `.ttf` into `Assets/Fonts/` and set it as the theme's default font.
- **Placeholder art:** `PlaceholderMesh3D` + `BlobShadow3D` — replace with
  imported meshes (glTF) when real art arrives; keep draw calls and
  materials few (standalone headsets are phones).
- **Sounds:** `Audio.play_sfx_at(preload("res://Assets/Audio/hit.ogg"), global_position)`
  (positional, so the player hears where it happened), `Audio.play_music(...)`.
  The synthesized presets (`SfxSynth`) are just stand-ins.
- **Currency icons:** set `icon` on each `CurrencyData` (coins and gems use
  `Assets/Icons/coin.svg` / `gem.svg`; the glyph is only a fallback).

## 5. Economy & meta-progression

All in `game_config.tres`:

| What | Where |
|---|---|
| Currencies + starting amounts | `currencies` |
| Shop upgrades (cost curve, max level, value per level) | `upgrades` (`show_in_shop = false` for in-level upgrades) |
| Level rewards (first clear + every clear) | each `LevelData` |
| Achievements (stat id + target + reward) | `achievements` |
| 7-day login streak | `daily_rewards` |
| Energy / lives | `max_energy` (> 0 enables), `energy_regen_seconds`, `LevelData.energy_cost` |

Read upgrades in gameplay: `Profile.upgrades.get_value(upgrade)` with the
`UpgradeData` exported on the level (Porchlight: `starting_sparks_upgrade`,
`starting_lives_upgrade`).
Track stats for achievements: `Profile.stats.increment(Types.STAT_X)`.

## 6. Monetization & analytics (when you ship)

The game already calls `Ads`, `Store` and `Analytics`. They use mock providers
that simulate ads/purchases (purchases only succeed in debug builds).

1. Install the plugin for your store (Meta Horizon Store in-app purchases,
   Steam) and analytics (e.g. GameAnalytics). Interstitial ads are unusual
   in VR; consider `ads_enabled = false`.
2. Subclass the provider in `Scripts/Services/` (`AdsProvider`, `StoreProvider`,
   `AnalyticsProvider`) and implement the virtual methods.
3. Register it at startup, e.g. in `Scenes/Boot/boot.gd`:
   `Ads.set_provider(AdMobProvider.new())`.
4. Product ids in `game_config.tres → products` must match the store consoles.
5. Enable required permissions in the export preset (internet is already on).

## 7. Localization

`Assets/Localization/translations.csv` — English text is the key, add a column per
language and list the locale in `Settings.SUPPORTED_LOCALES`. Godot re-imports the
CSV automatically; UI text set in scenes translates itself, in code use `tr("Text")`.

## 8. Saving custom data

```gdscript
# Any node or object can persist itself:
SaveManager.register_section(&"my_feature", _to_dict, _from_dict)
SaveManager.request_save()   # after changes (debounced)
```

For player-wide data prefer a new `ProfileModule` (see `Scripts/Profile/`) and add
it in `Globals/profile.gd`. Bump `SaveManager.SAVE_VERSION` and handle the old
layout in `_migrate()` when you change saved data after release.

## 9. Before release

- [ ] Remove or hide cheats you don't want testers to see (the Debug overlay is
      already stripped from release builds).
- [ ] Set `ads_enabled`, product ids and real providers.
- [ ] App icons in the export presets; splash color in Project Settings.
- [ ] Play on a standalone headset (Quest) and a PC headset; check comfort,
      reach and the frame rate with the Debug overlay's FPS readout.
- [ ] Run `Tools/smoke_test.sh` and review `Tools/screenshots.sh` output.

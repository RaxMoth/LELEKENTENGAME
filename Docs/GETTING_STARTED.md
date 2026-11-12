# Getting Started

This repository is one game: a VR crime-sim run out of one house (working
title Porchlight VR, [GAME.md](GAME.md)). It is built on a
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
4. Build the stage under **World** (`PlaceholderMesh3D` stand-ins or a
   `HouseShell`, a `WorldEnvironment`), add a `WalkableArea` for where the
   player may stand, move **World/XRPlayerRig** to the start and
   **World/Announcer** into their view.
5. Show status on in-world UI: a `WorldScreen` with a `Control` scene (like
   the House's `SalesBoard`) or a `Label3D`. Never a screen-space HUD.
6. Override the hooks you need:

```gdscript
extends LevelBase

func _on_level_setup() -> void:      # build / connect things (before the intro)
	rig.walkable_area = %WalkableArea
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

## 3. Grow the operation

The house is split into three areas — **defense**, **customers** and the
**house** (lab, office, crew, the shift) — each with its own scene, data,
upgrade catalog and smoke checks, so two people can work at the same time.
Start with [`Scenes/Levels/House/README.md`](../Scenes/Levels/House/README.md)
and the README in your area's folder.

- **Products (house / lab):** an `IngredientData` per new ingredient
  (`Ressources/Ingredients/`, plus an `IngredientCrate` in `Lab.tscn`) and a
  `RecipeData` (`Ressources/Recipes/`) added to `Lab.recipes`. Gate it with
  an unlock upgrade (`unlock_upgrade_id`).
- **Customers:** a `CustomerTypeData` in `Ressources/Customers/` added to
  `CustomerFlow.customer_types` in `Sales/SalesWindow.tscn`.
- **Raiders (defense):** an inherited scene of `Garden/Raider.tscn` (see
  `Swat.tscn`), sent by `AttackerDirector` in `Garden/FrontGarden.tscn`;
  how many come per raid is `RaidData` (`Ressources/Raids/`).
- **Cover (defense):** a `Vector4(x, z, radius, kind)` in the Yard's
  `obstacles` in `Garden/FrontGarden.tscn`.
- **Guns (defense):** a `GunModel` scene in `Armory/Guns/` and a
  `WeaponData` in `Ressources/Weapons/` pointing at it, added to
  `weapon_catalog.tres`.
- **Upgrades:** an `UpgradeData` (`branch`, `required_reputation`, cost
  curve) in your area's `Ressources/Upgrades/<Area>/`, added to that
  folder's catalog (`<area>_upgrades.tres`); its id goes into your area's
  block in `Types`. Read it with `operation.get_upgrade_value(id)`. It shows
  up in the office and the Shop.
- **Pacing:** exports on `AttackerDirector` (defense), `CustomerFlow`
  (customers), `DayCycle` and `Operation` (house).
- Add checks for your change to your area's file in `Tests/Smoke/`, then
  run `Tools/unit_tests.sh` and `Tools/smoke_test.sh`.

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
- **Real art:** CC0 textures in `Assets/Textures/`, shared materials in
  `Assets/Materials/`, models and impostors in `Assets/Models/`; build
  surfaces with `TexturedBox3D` / `GroundPlane3D` / `HouseShell` and scatter
  trees with `PropScatter3D`. Budgets and the workflow are in
  [DESIGN.md](DESIGN.md) ("Real art"); credit every download in
  `Assets/CREDITS.md`.
- **Sounds:** `Audio.play_sfx_at(preload("res://Assets/Audio/hit.ogg"), global_position)`
  (positional, so the player hears where it happened), `Audio.play_music(...)`.
  The synthesized presets (`SfxSynth`) are just stand-ins.
- **Currency icon:** set `icon` on the `CurrencyData` (cash uses
  `Assets/Icons/cash.svg`; the glyph is only a fallback).

## 5. Economy & meta-progression

All in `game_config.tres`:

| What | Where |
|---|---|
| Currencies + starting amounts | `currencies` |
| Shop upgrades (cost curve, max level, value per level) | one catalog per area in `Ressources/Upgrades/<Area>/`, listed in `upgrade_catalogs` (`show_in_shop = false` hides one from the 2D Shop) |
| Level rewards (first clear + every clear) | each `LevelData` |
| Achievements (stat id + target + reward) | `achievements` |
| 7-day login streak | `daily_rewards` |
| Energy / lives | `max_energy` (> 0 enables), `energy_regen_seconds`, `LevelData.energy_cost` |

Read upgrades in gameplay: `operation.get_upgrade_value(Types.UPGRADE_X)`
(or `Profile.upgrades.get_value(upgrade)` outside the house).
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

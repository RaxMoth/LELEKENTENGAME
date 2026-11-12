# Systems Reference

Quick API reference for the game (working title Porchlight VR). Every script
also has a header comment with usage. The game is VR-only: levels are 3D scenes played in a headset
(or the rig's flat simulator without one); only the menus are 2D screens.

## Autoloads (`Globals/`)

Load order matters and is set in Project Settings → Autoload:
`Types → Global → Events → Platform → Settings → SaveManager → Profile → Audio → Pools → Analytics → Ads → Store → UI → SceneManager → Debug`.

### Types
Constants only: `Types.GROUP_*`, `ACTION_*`, `XR_*` (OpenXR interface,
trackers and action names), `CURRENCY_*`, `STAT_*`, `EVENT_*` (StateChart
events), `METHOD_*` (optional duck-typed hooks) and enums (`DamageType`,
`HapticStrength`, `ProductType`, `LevelOutcome`, `Hand`).

### Global
```gdscript
Global.find_component(enemy, HealthComponent) as HealthComponent
Global.get_world_root()                 # where runtime spawns go (LevelBase's World)
await Global.wait(0.5)                  # pausable delay
```

### Events
Global signals; emit or connect from anywhere:
`app_paused`, `app_resumed`, `back_requested`, `safe_area_changed`,
`scene_changed`, `level_started`, `level_finished(result)`, `score_changed`,
`currency_changed`, `item_changed`, `upgrade_purchased`, `stat_changed`,
`achievement_unlocked`, `daily_reward_claimed`, `energy_changed`,
`enemy_defeated`, `setting_changed`, `rewarded_ad_finished`, `purchase_completed`, `purchase_failed`.

### Platform
```gdscript
Platform.is_xr_active()                         # an OpenXR headset session is running
Platform.is_mobile() / is_android() / is_desktop()
Platform.vibrate(Types.HapticStrength.MEDIUM)   # phone stand-in for controller rumble; respects the setting
Platform.safe_margins                           # notch insets for the flat menus, in viewport px
Platform.open_store_page()
```

### Settings
```gdscript
Settings.get_bool(Settings.KEY_HAPTICS_ENABLED)
Settings.set_value(Settings.KEY_MUSIC_VOLUME, 0.5)   # applies + saves + emits
```
Add a setting: a `KEY_` constant + an entry in `DEFAULTS` (+ a case in `_apply` if it changes the engine).
There is deliberately no frame-rate cap and no screen shake: the headset
paces the frames, and camera motion the player does not cause is uncomfortable.

### SaveManager
```gdscript
SaveManager.register_section(&"key", to_dict_callable, from_dict_callable)
SaveManager.request_save()   # debounced 1 s
SaveManager.save_now()       # also runs automatically on app pause / quit
```

### Profile
```gdscript
Profile.wallet.add(Types.CURRENCY_CASH, 50) / spend() / can_afford() / get_amount()   # add(..., false) for refunds
Profile.inventory.add_item(&"revive") / consume_item() / has_item()
Profile.levels.get_stars(id) / get_best_score(id) / is_unlocked(level) / get_total_stars()
Profile.upgrades.get_level(id) / get_value(upgrade) / purchase(upgrade) / is_owned(id)   # needs required_reputation
Profile.operation.day_number / reputation / add_reputation(n) / get_price(id, default)
Profile.stats.increment(Types.STAT_X) / record_max(id, value)
Profile.achievements.is_unlocked(id) / get_progress_ratio(achievement)
Profile.daily_rewards.can_claim() / claim()
Profile.energy.get_current() / consume(1) / seconds_until_next()
Profile.meta.set_flag(&"tutorial_done") / has_flag() / offline_seconds
Profile.grant_rewards({&"cash": 100, &"revive": 1})   # currencies or items
Profile.reset_progress()
```

### Audio
```gdscript
Audio.play_music(stream, fade_seconds)
Audio.play_sfx(stream, pitch_variation, volume_db)
Audio.play_sfx_at(stream, world_position)   # Vector3, spatialized for the headset / 3D camera
Audio.play_ui(Audio.UI_CLICK)    # click / confirm / error / reward
SfxSynth.get_preset(&"coin")     # placeholder sounds: coin hit shoot jump explosion pop
```

### Pools
```gdscript
var bolt: LaneBolt = Pools.spawn(BOLT_SCENE, effects_root, muzzle.global_position) as LaneBolt   # Node3D scenes
Pools.despawn(bolt)              # never queue_free pooled nodes
Pools.prewarm(BOLT_SCENE, 30)
```
Pooled scripts may implement `_on_pool_spawned()` / `_on_pool_despawned()` to reset.
Pools are cleared on every scene change.

### Ads / Store / Analytics
```gdscript
if await Ads.show_rewarded(&"revive"): ...
Ads.maybe_show_interstitial(&"level_end")      # capped, skipped with "no_ads"
if await Store.purchase(&"starter_pack"): ...  # rewards granted automatically
Analytics.log_event(&"tutorial_step", {"step": 2})
Ads.set_provider(MyProvider.new())             # swap mock for a real SDK
```

### UI
```gdscript
var result: Variant = await UI.open_popup(MY_POPUP_SCENE, {"key": value}).closed
if await UI.confirm(tr("Quit?"), "", tr("Yes"), tr("No")): ...
UI.toast("Saved!")
UI.show_loading("Connecting…") / UI.hide_loading()
UI.set_world_space_enabled(true)   # popups render into UI.get_world_viewport(); the rig does this in a headset
```
Popups are 2D `Control` scenes; inside a headset they appear on the rig's
in-world popup screen, so they work unchanged in VR.
Every `BaseButton` automatically gets press scale, click sound and haptics;
set meta `no_juice` on a button to opt out.

New popup: a scene with root `Control` (script `extends BasePopup`), children
`%Backdrop` (ColorRect) and `CenterContainer/%Panel` (PanelContainer). Override
`_on_opened(data)` and call `close(result)`. Copy `ConfirmPopup` as a starter.

### SceneManager
```gdscript
SceneManager.change_scene(path, {Types.PARAM_LEVEL_DATA: level})
SceneManager.go_back() / go_to_main_menu() / reload_current_scene()
```
Inside a headset `go_to_main_menu()` starts `GameConfig.xr_start_level_id`
instead of the (invisible) 2D main menu.
Target scenes receive params through `receive_scene_params(params)` before
`_ready`. Back button order: top popup → scene's `handle_back() -> bool` →
history → quit dialog.

### Debug (debug builds only)
F3 (flat window) or five quick taps in the top-left corner: +1000 cash, +50 reputation, unlock levels,
refill energy, win/lose level, ×3 time scale, reset daily reward / progress.
Add cheats in `Globals/Debug/debug_overlay.gd → _build_cheats()`.

## LevelBase (`Scenes/Game/LevelBase/`)

A `Node3D` scene every level inherits:

```
LevelBase (Node3D)
├── World (Node3D, group world_root)   your stage goes here; pooled spawns default here
│   ├── XRPlayerRig                    move it to where the player stands
│   └── Announcer (Label3D)            big in-world text, place it in the player's view
└── StateChart                         Intro → Playing ⇄ Paused → Won | Lost
```

| Member | Use |
|---|---|
| `level_data`, `score`, `elapsed_seconds`, `phase`, `world`, `rig`, `announcer` | state & nodes |
| `add_score()`, `set_score()`, `win()`, `lose()`, `end_run()`, `get_remaining_seconds()` | flow |
| `announce(text, color, hold_seconds)` | "Wave 2", "Breach!" on the Announcer |
| `pause_level()`, `restart_level()`, `quit_to_menu()`, `go_to_next_level()` | navigation |
| `LevelBase.start_level(level_data)` | start any level (consumes energy) |
| `_on_level_setup`, `_on_level_started`, `_level_process`, `_level_physics_process` | hooks |
| `_on_time_limit_reached`, `_calculate_stars`, `_calculate_rewards`, `_on_level_finished` | hooks |
| exports `show_intro_countdown`, `time_limit_seconds` | config |

The controller menu / B / Y button toggles the pause menu (connected in
`LevelBase.tscn`). There is no screen-space HUD — a headset can't see one.
Show score, timer and status on in-world UI (a `WorldScreen` like
the House's sales and build boards, or a `Label3D`), driven by `score_changed`.

## Components (`Scripts/Components/`)

| Component | Node | Notes |
|---|---|---|
| `HealthComponent` | Node | `apply_damage`, `heal`, `revive`, i-frames; signals `damaged`, `died` |
| `DamageInfo` | RefCounted | amount, type, source, crit, `knockback` (Vector3) for one hit |
| `HitFlash3DComponent` | Node | Flashes every mesh under a Node3D on damage |
| `WaveSpawner` | Node | `WaveData` waves; spawns at `Marker3D`s by default; endless scaling; override `_create_enemy()` for other spawn rules (`LaneWaveSpawner` uses lanes) |

Component wiring in scenes uses exported node references (e.g. a hit
flash's `health_component`), not `get_parent()`.

## XR (`Scripts/XR/`, `Scenes/Entities/XRPlayerRig/`)

Details and setup: [GAME.md](GAME.md).

| Piece | Node | Notes |
|---|---|---|
| `XRPlayerRig` | XROrigin3D | Headset camera + two controllers; falls back to a flat simulator (mouse, WASD) without a headset. Signals `primary_action_pressed(pointer)`, `secondary_action_pressed(pointer)`, `menu_pressed`, `item_grabbed`, `item_placed`; `walkable_area`, `get_tool_pointer()`, `get_wrist_anchor()`, `pulse(pointer, strength)`, `set_world_space_ui()`, `tap_world_point()` (tests) |
| `XRLocomotion` | Node | Teleport (off-hand stick), smooth movement, snap / smooth turning (dominant stick), flat WASD and `travel_spots` (keys 1–4); clamps to the `WalkableArea` |
| `WalkableArea` | Node3D | Floor rectangles the player may stand on; `contains()`, `clamp_move()` |
| `Grabbable` / `ItemSocket` | Node3D | Items a hand or the flat cursor picks up and drops into sockets; sockets decide what they accept (`accept_rule`) and signal `item_inserted` |
| `PointerButton` | Node3D | A 3D button pressed by the pointer ray |
| `InteractionQuery` | static | Finds grab targets, sockets and buttons by sphere math (no physics) |
| `XRPointer` | Node3D | Ray along -Z. Clicks `WorldScreen`s itself; game code reads `ray_origin` / `ray_direction` and reports hits with `set_world_hit_distance()` |
| `WorldScreen` | Node3D | Shows a Control scene (`content_scene`) or an existing viewport (`attach_viewport`) on a panel in the world and forwards pointer input as mouse events |
| `RayMath` (`Scripts/Utils/`) | static | `intersect_plane` / `intersect_ground` / `intersect_sphere` / `distance_to_point`: picking without physics |
| `LaneGrid` (`Scripts/Utils/`) | RefCounted | Lane-defense board: cell ↔ world, occupancy, `get_blocker()` |
| `PlaceholderMesh3D`, `BlobShadow3D` (`Scripts/Utils/`) | MeshInstance3D | 3D art stand-ins with shared meshes / materials and a soft contact shadow |
| `HitFlash3DComponent` | Node | Flashes every mesh under a Node3D on damage |
| `FloatingText3D`, `PopEffect3D` (`Scenes/Entities/`) | pooled | `FloatingText3D.spawn("+25", position, color, parent)`, `PopEffect3D.spawn(position, color, diameter, parent)` |

`GameConfig.xr_start_level_id` names the level Boot starts when a headset is
active and that "Main Menu" returns to (2D menus are not visible inside one). Controller bindings:
`openxr_action_map.tres` (Godot's defaults plus HTC Vive wands); action names
are in `Types.XR_ACTION_*`.

## Reusable entities (`Scenes/Entities/`)

`XRPlayerRig` (part of every level through `LevelBase`), `FloatingText3D`
and `PopEffect3D` (pooled effects).

## UI controls (`Scripts/UI/`)

```gdscript
IconLabel.create(COIN_ICON, "1.2K")                      # icon + text, centered together
reward_list.set_rewards({&"cash": 250})                  # "+250 [cash]"
```

`IconLabel`, `RewardList`, `SafeAreaContainer`, `CurrencyDisplay` (shows
`CurrencyData.icon`), `EnergyDisplay`, `StarsDisplay`, `BasePopup`. These
build the 2D menus and popups, and in-world screens shown on a `WorldScreen`.

## Utilities (`Scripts/Utils/`)

`Palette` (design color tokens — see [DESIGN.md](DESIGN.md)), `NumberFormat`
(1.2K, 1,234, 2:05), `TweenFX` (UI tweens: pop, bounce_in, shake, pulse,
count_label…), `RayMath`, `LaneGrid`, `PlaceholderMesh3D` & `BlobShadow3D`
(3D art stand-ins), `SfxSynth` (generated sounds).

## Data resources (`Scripts/Resources/`)

`GameConfig`, `LevelData`, `CurrencyData`, `UpgradeData` (with `branch` and
`required_reputation`), `ProductData` (in-app products), `AchievementData`,
`RewardBundle`, `WaveData`/`WaveEntry`, and the game's own: `IngredientData`,
`RecipeData`, `CustomerTypeData`, `TowerData`.

## Game rules (`Scripts/Game/`, pure, unit-tested)

```gdscript
var gauge: TimingGauge = TimingGauge.new(0.7, 0.2)   # gauge.advance(delta); gauge.stop() -> 0..1
QualityMath.tier_from_score(QualityMath.combine(accuracies, equipment_bonus))   # 1..4: Cut, Street, Pure, Premium
stash.add(&"glow", tier, units) / take(&"glow", min_tier, amount) / steal(n) / count(id, min_tier)
SalesMath.evaluate(asked_price, max_price, haggles)   # Verdict.ACCEPT / COUNTER / REFUSE
heat.add(n) / cool(delta) / take_pending_raid()
clock.advance(delta) / get_hour() / get_phase() / just_passed_hour(25.0, delta)
```

## The House (`Scenes/Levels/House/`)

```gdscript
operation.stash / heat / get_cash() / spend_cash(n, reason) / complete_sale(order, price)
operation.get_upgrade_value(Types.UPGRADE_BATCH) / get_unlocked_recipes() / bribe()
sales_window.spawn_customer(order) / get_front_customer() / sell_to_front() / accept_counter()
director.spawn_customer() / spawn_attacker(scene) / start_raid(level) / start_boss_wave()
board.place_tower(tower_data, cell) / spawn_enemy(scene) / pick_enemy(ray...)
```
See [GAME.md](GAME.md) for the scene tree and the design.

## Physics

Combat and picking are ray / lane math (`RayMath`, `LaneGrid`), not physics
bodies — cheaper on standalone headsets. If you add 3D physics, name its
layers under `layer_names/3d_physics` in Project Settings and add matching
`Types.LAYER_*` constants.

# Systems Reference

Quick API reference. Every script also has a header comment with usage.

## Autoloads (`Globals/`)

Load order matters and is set in Project Settings → Autoload:
`Types → Global → Events → Platform → Settings → SaveManager → Profile → Audio → Pools → Analytics → Ads → Store → UI → SceneManager → Debug`.

### Types
Constants only: `Types.LAYER_*` (physics bits), `GROUP_*`, `ACTION_*`,
`CURRENCY_*`, `STAT_*`, `ENTITY_STAT_*`, `EVENT_*` (StateChart events),
`METHOD_*` (optional duck-typed hooks) and enums (`DamageType`,
`TargetPriority`, `HapticStrength`, `ProductType`, `SwipeDirection`, `LevelOutcome`).

### Global
```gdscript
Global.find_nearest_in_group(Types.GROUP_ENEMY, global_position, 400.0)
Global.get_group_nodes_in_radius(Types.GROUP_ENEMY, center, radius)
Global.find_component(enemy, HealthComponent) as HealthComponent
Global.get_world_root()                 # where runtime spawns go
Global.screen_to_world(self, touch_position)
await Global.wait(0.5)                  # pausable delay
```

### Events
Global signals; emit or connect from anywhere:
`app_paused`, `app_resumed`, `back_requested`, `safe_area_changed`,
`scene_changed`, `level_started`, `level_finished(result)`, `score_changed`,
`currency_changed`, `item_changed`, `upgrade_purchased`, `stat_changed`,
`achievement_unlocked`, `daily_reward_claimed`, `energy_changed`,
`camera_shake_requested(trauma)`, `pickup_collected`, `enemy_defeated`,
`setting_changed`, `rewarded_ad_finished`, `purchase_completed`, `purchase_failed`.

### Platform
```gdscript
Platform.is_mobile() / is_android() / is_ios() / is_web()
Platform.vibrate(Types.HapticStrength.MEDIUM)   # respects the setting
Platform.safe_margins                           # notch insets in viewport px
Platform.open_store_page()
```

### Settings
```gdscript
Settings.get_bool(Settings.KEY_HAPTICS_ENABLED)
Settings.set_value(Settings.KEY_MUSIC_VOLUME, 0.5)   # applies + saves + emits
```
Add a setting: a `KEY_` constant + an entry in `DEFAULTS` (+ a case in `_apply` if it changes the engine).

### SaveManager
```gdscript
SaveManager.register_section(&"key", to_dict_callable, from_dict_callable)
SaveManager.request_save()   # debounced 1 s
SaveManager.save_now()       # also runs automatically on app pause / quit
```

### Profile
```gdscript
Profile.wallet.add(Types.CURRENCY_COINS, 50) / spend() / can_afford() / get_amount()
Profile.inventory.add_item(&"revive") / consume_item() / has_item()
Profile.levels.get_stars(id) / get_best_score(id) / is_unlocked(level) / get_total_stars()
Profile.upgrades.get_level(id) / get_value(upgrade) / purchase(upgrade)
Profile.stats.increment(Types.STAT_X) / record_max(id, value)
Profile.achievements.is_unlocked(id) / get_progress_ratio(achievement)
Profile.daily_rewards.can_claim() / claim()
Profile.energy.get_current() / consume(1) / seconds_until_next()
Profile.meta.set_flag(&"tutorial_done") / has_flag() / offline_seconds
Profile.grant_rewards({&"coins": 100, &"revive": 1})   # currencies or items
Profile.reset_progress()
```

### Audio
```gdscript
Audio.play_music(stream, fade_seconds)
Audio.play_sfx(stream, pitch_variation, volume_db)
Audio.play_sfx_at(stream, world_position)
Audio.play_sfx_at_3d(stream, world_position)   # Vector3, spatialized for the 3D camera / headset
Audio.play_ui(Audio.UI_CLICK)    # click / confirm / error / reward
SfxSynth.get_preset(&"coin")     # placeholder sounds: coin hit shoot jump explosion pop
```

### Pools
```gdscript
var bullet: Projectile = Pools.spawn(BULLET_SCENE, Global.get_world_root(), position)
var bolt: LaneBolt = Pools.spawn_3d(BOLT_SCENE, effects_root, muzzle.global_position)   # Node3D scenes
Pools.despawn(bullet)            # never queue_free pooled nodes
Pools.prewarm(BULLET_SCENE, 30)
```
Pooled scripts may implement `_on_pool_spawned()` / `_on_pool_despawned()` to reset.
Pools are cleared on every scene change.

### Ads / Store / Analytics
```gdscript
if await Ads.show_rewarded(&"revive"): ...
Ads.maybe_show_interstitial(&"level_end")      # capped, skipped with "no_ads"
if await Store.purchase(&"gems_small"): ...    # rewards granted automatically
Analytics.log_event(&"tutorial_step", {"step": 2})
Ads.set_provider(MyProvider.new())             # swap mock for a real SDK
```

### UI
```gdscript
var result: Variant = await UI.open_popup(MY_POPUP_SCENE, {"key": value}).closed
if await UI.confirm(tr("Quit?"), "", tr("Yes"), tr("No")): ...
UI.toast("Saved!")
UI.show_loading("Connecting…") / UI.hide_loading()
UI.set_world_space_enabled(true)   # 3D / XR: popups render into UI.get_world_viewport()
```
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
Target scenes receive params through `receive_scene_params(params)` before
`_ready`. Back button order: top popup → scene's `handle_back() -> bool` →
history → quit dialog.

### Debug (debug builds only)
F3 or five quick taps in the top-left corner: coins, gems, unlock levels,
refill energy, win/lose level, ×3 time scale, reset daily reward / progress.
Add cheats in `Globals/Debug/debug_overlay.gd → _build_cheats()`.

## LevelBase (`Scenes/Game/LevelBase/`)

StateChart: `Intro → Playing ⇄ Paused → Won | Lost`.

| Member | Use |
|---|---|
| `level_data`, `score`, `elapsed_seconds`, `phase`, `world`, `camera`, `hud` | state & nodes |
| `add_score()`, `set_score()`, `win()`, `lose()`, `end_run()` | flow |
| `pause_level()`, `restart_level()`, `quit_to_menu()`, `go_to_next_level()` | navigation |
| `LevelBase.start_level(level_data)` | start any level (consumes energy) |
| `_on_level_setup`, `_on_level_started`, `_level_process`, `_level_physics_process` | hooks |
| `_on_time_limit_reached`, `_calculate_stars`, `_calculate_rewards`, `_on_level_finished` | hooks |
| exports `show_intro_countdown`, `time_limit_seconds`, `show_elapsed_time`, `show_score` | config |

HUD (`hud`): `set_score`, `set_timer`, `set_progress(value, max, caption)`,
`show_message(text)`, `add_action_button(text)`, `add_action_control(control)`,
`set_currency_visible`.

## Components (`Scripts/Components/`)

| Component | Node | Notes |
|---|---|---|
| `HealthComponent` | Node | `apply_damage`, `heal`, `revive`, i-frames; signals `damaged`, `died` |
| `HurtboxComponent` | Area2D | put on `*_hurtbox` layer; links a HealthComponent |
| `HitboxComponent` | Area2D | mask = hurtbox layer; one-shot or `hit_interval` contact damage, crits, knockback |
| `Projectile` | Area2D | pooled hitbox; speed, lifetime, pierce, homing |
| `ShooterComponent` | Marker2D | fire rate, spread, multi-shot, homing; multipliers for upgrades |
| `TargetingComponent` | Area2D | finds targets by group; priorities nearest/farthest/strongest/weakest/first/last on path |
| `VelocityComponent` | Node | accel/friction top-down movement + knockback |
| `PlatformerMovementComponent` | Node | jump by height/time, coyote, buffer, multi-jump, jump cut |
| `PathMoverComponent` | Node | follows a Path2D; `progress` for TD targeting |
| `WaveSpawner` | Node | `WaveData` waves; markers / ring around player / path start; endless scaling; override `_create_enemy()` for other spawn rules |
| `Pickup` / `CollectorComponent` | Area2D | magnet pickups; broadcast `Events.pickup_collected` |
| `LootDropComponent` | Node | rolls a `LootTable` |
| `StatsComponent` | Node | base stats + `StatModifier`s (flat / percent) |
| `AbilityComponent` | Node | `AbilityData` slots with cooldowns; pair with `CooldownButton` |
| `HitFlashComponent` | Node | flashes a CanvasItem on damage |
| `HealthBarComponent` | ProgressBar | world-space bar bound to health |
| `GameCamera` | Camera2D | follow, trauma shake, optional pan + pinch zoom |
| `TapArea` | Area2D | tappable world objects |
| `GestureDetector` (`Scripts/Input/`) | Node | tap, double tap, long press, swipe, drag, pinch |

Component wiring in scenes uses exported node references (e.g. a hurtbox's
`health_component`), not `get_parent()`.

## 3D / XR (`Scripts/XR/`, `Scenes/Entities/XRPlayerRig/`)

Details and setup: [VR.md](VR.md).

| Piece | Node | Notes |
|---|---|---|
| `XRPlayerRig` | XROrigin3D | Headset camera + two controllers; falls back to a flat simulator (mouse / touch) without a headset. Signals `primary_action_pressed(pointer)`, `secondary_action_pressed(pointer)`, `menu_pressed`, `selection_step_requested(step)`; `get_tool_pointer()`, `pulse(pointer, strength)`, `set_world_space_ui()` |
| `XRPointer` | Node3D | Ray along -Z. Clicks `WorldScreen`s itself; game code reads `ray_origin` / `ray_direction` and reports hits with `set_world_hit_distance()` |
| `WorldScreen` | Node3D | Shows a Control scene (`content_scene`) or an existing viewport (`attach_viewport`) on a panel in the world and forwards pointer input as mouse events |
| `RayMath` (`Scripts/Utils/`) | static | `intersect_plane` / `intersect_ground` / `intersect_sphere` / `distance_to_point`: picking without physics |
| `LaneGrid` (`Scripts/Utils/`) | RefCounted | Lane-defense board: cell ↔ world, occupancy, `get_blocker()` |
| `PlaceholderMesh3D`, `BlobShadow3D` (`Scripts/Utils/`) | MeshInstance3D | 3D art stand-ins with shared meshes / materials and a soft contact shadow |
| `HitFlash3DComponent` | Node | Flashes every mesh under a Node3D on damage |
| `FloatingText3D`, `PopEffect3D` (`Scenes/Entities/`) | pooled | `FloatingText3D.spawn("+25", position, color, parent)`, `PopEffect3D.spawn(position, color, diameter, parent)` |

`GameConfig.xr_start_level_id` names the level Boot starts when a headset is
active (2D menus are not visible inside one). Controller bindings:
`openxr_action_map.tres` (Godot's defaults plus HTC Vive wands); action names
are in `Types.XR_ACTION_*`.

## Reusable entities (`Scenes/Entities/`)

`TopDownPlayer` (joystick/keyboard, auto-aim, stats-driven), `ChaserEnemy`
(pooled melee AI with loot), `Projectile`, `Pickups/XpGem` & `Coin`,
`FloatingText` (`FloatingText.spawn("-12", position, color)`).

## UI controls (`Scripts/UI/`)

```gdscript
IconLabel.create(COIN_ICON, "1.2K")                      # icon + text, centered together
reward_list.set_rewards({&"coins": 20, &"gems": 1})      # "+20 [coin]  +1 [gem]"
```

`IconLabel`, `RewardList`, `SafeAreaContainer`, `CurrencyDisplay` (shows
`CurrencyData.icon`), `EnergyDisplay`, `StarsDisplay`,
`TouchJoystick` (native `VirtualJoystick` set to the `move_*` actions; releases
them on pause, hide and scene change; styled by the theme's `VirtualJoystick`
styles), `CooldownButton`, `BasePopup`.

## Utilities (`Scripts/Utils/`)

`Palette` (design color tokens — see [DESIGN.md](DESIGN.md)), `NumberFormat`
(1.2K, 1,234, 2:05), `TweenFX` (pop, bounce_in, shake, pulse, count_label…),
`RandomUtils` (weighted picks), `GridData` (board games: matches, flood fill,
cell↔world), `PlaceholderShape` (soft-shaded vector shapes: rounded corners,
shading, drop shadow) & `GridBackground` (art stand-ins), `SfxSynth`
(generated sounds).

## Data resources (`Scripts/Resources/`)

`GameConfig`, `LevelData`, `CurrencyData`, `UpgradeData`, `ProductData`,
`AchievementData`, `RewardBundle`, `WaveData`/`WaveEntry`, `LootTable`/`LootEntry`,
`StatModifier`, `PerkData`, `AbilityData` (subclass and override `activate()`).

## Physics layers

| # | Name | Used by |
|---|---|---|
| 1 | world | walls, ground |
| 2 | player | player bodies |
| 3 | enemy | enemy bodies |
| 4 | player_hurtbox | hit by enemy hitboxes |
| 5 | enemy_hurtbox | hit by player projectiles; detected by targeting |
| 6 | pickup | collected by `CollectorComponent` |
| 7 | interactable | `TapArea` |

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
`KEY_FULLSCREEN` (on by default) puts a desktop window in full screen; F11
(`Types.ACTION_TOGGLE_FULLSCREEN`) toggles it. `Settings.has_desktop_window()`
is false headless, on mobile and with `-- windowed=1` (screenshots), so the
popup hides the toggle there.
There is deliberately no frame-rate cap and no screen shake: the headset
paces the frames, and camera motion the player does not cause is uncomfortable.

### SaveManager
```gdscript
SaveManager.register_section(&"key", to_dict_callable, from_dict_callable)
SaveManager.request_save()   # debounced 1 s
SaveManager.save_now()       # also runs automatically on app pause / quit
```

Development builds start every launch fresh: they skip loading the save
while `Settings.KEY_FRESH_START_IN_DEV` is on (default; "Fresh Start Every
Launch" in the settings popup, shown only in debug builds). Exported release
builds always load it.

### Profile
```gdscript
Profile.wallet.add(Types.CURRENCY_CASH, 50) / spend() / can_afford() / get_amount()   # add(..., false) for refunds
Profile.inventory.add_item(&"revive") / consume_item() / has_item()
Profile.levels.get_stars(id) / get_best_score(id) / is_unlocked(level) / get_total_stars()
Profile.upgrades.get_level(id) / get_value(upgrade) / purchase(upgrade) / is_owned(id)   # needs required_reputation
Profile.operation.day_number / reputation / add_reputation(n) / get_price(id, default)
Profile.armory.loadout.owns(weapon) / get_ammo(weapon) / equip(weapon) / get_equipped(catalog) / try_fire(weapon)
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
var tracer: BeamTracer = Pools.spawn(TRACER_SCENE, effects_root, muzzle.global_position) as BeamTracer   # Node3D scenes
Pools.despawn(tracer)            # never queue_free pooled nodes
Pools.prewarm(TRACER_SCENE, 30)
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

### Coop (two players)
```gdscript
Coop.host()                      # opens UDP 7777, announces on the LAN, asks the router (UPnP)
Coop.join("203.0.113.5:7777")    # or a game from Coop.found_games (start_discovery())
Coop.is_host() / is_client() / is_online() / leave()
Coop.is_coop_scene(scene)        # a level two players can share (has a %CoopSync)
```
Players reach it through `CoopPopup` (main menu, pause menu, and the
`CoopBoard` on the House's front room wall). A host may start in a menu: a
guest who joins meanwhile is welcomed once the co-op level runs.
The host's level is the world. A guest's `HouseLevel` is a mirror: its
`HouseCoopSync` shows the host's snapshots and forwards the guest's hand
input (`XRPlayerRig.forwards_hand_input`), which the host runs through a
`HandInteractor` on a `RemotePlayer`. To stream a new spawned scene, add it
to `HouseCoopSync.STREAMED_SCENES` (append only) and optionally give it
`get_net_state()` / `apply_net_state(state)`; a scene node joins
`Types.GROUP_NET_NODE` with the same two methods. In-world boards need
nothing: the host sends each board's look (`ControlMirror`) when it changes.
A front that reacts to the guest's gun trigger listens to
`HouseContext.guest_fired`. Test: `Tools/coop_test.sh`.

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
the House's sales board and armory, or a `Label3D`), driven by `score_changed`.

## Components (`Scripts/Components/`)

| Component | Node | Notes |
|---|---|---|
| `HealthComponent` | Node | `apply_damage`, `heal`, `revive`, i-frames; signals `damaged`, `died` |
| `DamageInfo` | RefCounted | amount, type, source, crit, `knockback` (Vector3) for one hit |
| `HitFlash3DComponent` | Node | Flashes every mesh under a Node3D on damage |
| `HitTarget` | Node3D | Base for small things the player's weapons can hit besides raiders (the rats): joins `Types.GROUP_HIT_TARGET` and overrides `get_hit_center()`, `get_hit_radius()`, `is_alive()`, `take_hit(amount, source)`. The front garden's strikes and shots fall back to them by sphere math |
| `UpgradeReaction` | Node3D | Base of everything that reacts to an upgrade's level; the House level calls `apply_level()` on every one in `Types.GROUP_UPGRADE_LOOK` when upgrades change |
| `UpgradePlacement` | UpgradeReaction | Moves `target` to the `before` marker until the upgrade reaches `min_level` (the office board hangs in the cabin until the house is extended) |
| `ProximityCull` | Node3D | Hides a room's contents (drawing only) while the camera is far from `center` and above `below_height`: the cellar is drawn only near its stairwell or inside it |
| `WalkBlocker` | Node3D | Furniture footprint (`size`, turned with the node) the player can't walk through while it is visible; handed to `WalkableArea.add_obstacle()` |
| `UpgradeLook` | UpgradeReaction | A part that shows once an upgrade reaches `min_level` (iron door straps, a steel frame, real shelves); hides the old look it `replaces` and can restyle meshes with another material. The House level applies every look in `Types.GROUP_UPGRADE_LOOK` when upgrades change |
| `WaveSpawner` | Node | `WaveData` waves; spawns at `Marker3D`s by default; endless scaling; override `_create_enemy()` for other spawn rules |
| `PlayerVitals` | Node | A player's health (`PlayerHealth`: 100 HP, slow regeneration after a quiet spell) in `Types.GROUP_PLAYER_TARGET`; `take_damage()`, signals `hit_taken`, `health_changed`, `died`; `feet_source` tells raiders where the player is; a co-op guest's mirrors the host's numbers (`apply_net_health`) |
| `PlayerSkills` (Profile.skills) | ProfileModule | Crafting, fighting, harvesting experience (`SkillBook`, `SkillTuning` in `Ressources/Skills/`); `Operation.record_craft / record_melee_hit / record_hand_harvest` feed it, `Operation.skill_leveled` tells the level |
| `NpcVoice` | Node3D | An NPC's speech: `say(category, is_important)` plays a `VoiceData` line from its position with a subtitle; `say_last_words()` outlives the NPC; chatter is rationed across NPCs; signal `line_finished` |

Component wiring in scenes uses exported node references (e.g. a hit
flash's `health_component`), not `get_parent()`.

## XR (`Scripts/XR/`, `Scenes/Entities/XRPlayerRig/`)

Details and setup: [GAME.md](GAME.md).

| Piece | Node | Notes |
|---|---|---|
| `XRPlayerRig` | XROrigin3D | Headset camera + two controllers; falls back to a flat simulator (mouse, WASD) without a headset. Signals `primary_action_pressed(pointer)`, `secondary_action_pressed(pointer)`, `menu_pressed`, `item_grabbed`, `item_placed`; `walkable_area`, `get_tool_pointer()`, `get_wrist_anchor()`, `pulse(pointer, strength)`, `set_world_space_ui()`, `tap_world_point()` (tests) |
| `XRLocomotion` | Node | Stick walking like WASD (off-hand stick; never teleports, except a Vive wand's trackpad click, and never through a wall); real steps and leaning stop at walls (furniture can be leaned over), snap / smooth turning (dominant stick), flat WASD and `travel_spots` (keys 1–4); clamps to the `WalkableArea`; `get_walk_stick()` |
| `WalkableArea` | Node3D | Floor rectangles the player may stand on, minus round and rectangular blockers; `contains()`, `clamp_move()`, `add_region()`, `add_blockers()`, `add_rect_blockers()`. More floors: `add_floor(WalkableFloor)` (a cellar at its own height), `add_ramp(WalkableRamp)` (stairs between floors), `add_hole()` (a stairwell in the main floor), `add_obstacle()` (furniture, blocks only its own floor); `find_path(from, to)` routes across rooms, doorways and stairs (waypoints at the joins); `get_floor_height_at()` picks the surface nearest the feet within `MAX_STEP`, and `clamp_move()` returns the new height, so walking down stairs lowers the player |
| `Stairs3D` (`Scripts/Utils/`) | MeshInstance3D | A straight flight of stairs (treads and side boards) as one mesh, textured in meters; `get_ramp()` gives the matching WalkableRamp |
| `GroundHole` (`Scripts/Utils/`) | Node3D | An opening every `GroundPlane3D` leaves out (a stairwell under the lawn and the town's asphalt) |
| `SightMath` (`Scripts/Utils/`) | static | `is_in_view(eye, point, half_angle, max_distance)`: view-cone checks (the ghost) |
| `GhostOdds` (`Scripts/Game/`) | static | `haunts_tonight(day, last_ghost_night, roll, chance, first_night, min_nights_between)`: whether the ghost comes tonight (`OperationProgress.last_ghost_night` remembers the last time) |
| `Grabbable` / `ItemSocket` | Node3D | Items a hand or the flat cursor picks up and drops into sockets; sockets decide what they accept (`accept_rule`) and signal `item_inserted`. A usable item (`is_usable()`, `use(is_pressed, pointer)`, `use_once()`: the extinguisher) takes its holder's trigger |
| `GloveHand`, `WalkingBody` | Node3D | The headset player's gloved hands (fingers follow grip / trigger) and the body under them (procedural gait, knee IK, holster anchors `get_holster_anchor()`); `WalkingBody` also walks the co-op partner's avatar |
| `PointerButton` | Node3D | A 3D button pressed by the pointer ray |
| `HingeHandle` | Grabbable | A handle on a hinged leaf (door, gate): reports the angle the hand pulls it to; a flat click asks to toggle |
| `XRPlayerRig` signals | | `primary_action_released` / `secondary_action_released` (held actions: automatic guns, a turret trigger); `is_grip_down(hand)`, `get_hand_local_transform(hand)` for arm-swing running; `grip_filter` lets a level claim a grip press (holsters); `get_body()` |
| `InteractionQuery` | static | Finds grab targets, sockets and buttons by sphere math (no physics) |
| `XRPointer` | Node3D | Ray along -Z. Clicks `WorldScreen`s itself; game code reads `ray_origin` / `ray_direction` and reports hits with `set_world_hit_distance()`. Controller pointers set `steadying` (0.7): small hand wobbles are smoothed, real aiming is followed at once |
| `WorldScreen` | Node3D | Shows a Control scene (`content_scene`) or an existing viewport (`attach_viewport`) on a panel in the world and forwards pointer input as mouse events. Press and drag on an overflowing `ScrollContainer` scrolls it (past `DRAG_SCROLL_PIXELS` the press is cancelled, so no button fires; `is_drag_scrolling()`). A live board redraws at most `max_redraws_per_second` (24) times a second, a static one only on `request_redraw()`. `uses_house_style` gives the content `HouseBoardStyle`'s theme and recolors scene color overrides, also on controls added later |
| `RayMath` (`Scripts/Utils/`) | static | `intersect_plane` / `intersect_ground` / `intersect_sphere` / `distance_to_point`: picking without physics |
| `YardNavigation` (`Scripts/Game/`) | static | Steering around round obstacles, overlap, line of sight, cover spots, door spots — no physics |
| `PlaceholderMesh3D`, `BlobShadow3D` (`Scripts/Utils/`) | MeshInstance3D | 3D art stand-ins with shared meshes / materials and a soft contact shadow |
| `TexturedBox3D`, `GroundPlane3D` (`Scripts/Utils/`) | MeshInstance3D | A box / a flat patch of ground with a real material (`Assets/Materials/`), UVs in meters so `uv1_scale` = 1 / tile size; the ground can bake soft darker patches into vertex colors |
| `PropScatter3D` (`Scripts/Utils/`) | MultiMeshInstance3D | Many copies of one mesh (impostor trees, weeds) from a list of (x, z, scale, yaw) placements, one draw call |
| `TownMeshBuilder` (`Scripts/Utils/`) | RefCounted | A `TownLayout` as chunked ArrayMeshes (walls, roofs, windows that glow at night, sidewalks, curbs, markings, lamps, cars) |
| `WorldUVMesh` (`Scripts/Utils/`) | static | Box faces, polygons and planes with UVs in meters, normals and tangents (used by `HouseShell` and the two above) |
| `HitFlash3DComponent` | Node | Flashes every mesh under a Node3D on damage |
| `FloatingText3D`, `PopEffect3D` (`Scenes/Entities/`) | pooled | `FloatingText3D.spawn("+25", position, color, parent)`, `PopEffect3D.spawn(position, color, diameter, parent)` |

`GameConfig.xr_start_level_id` names the level Boot starts when a headset is
active and that "Main Menu" returns to (2D menus are not visible inside one). Controller bindings:
`openxr_action_map.tres` (Godot's defaults plus HTC Vive wands); action names
are in `Types.XR_ACTION_*`.

## Reusable entities (`Scenes/Entities/`)

`XRPlayerRig` (part of every level through `LevelBase`; gloved hands
`GloveHand` and the walking body `WalkingBody`), `RemotePlayer` (the co-op
partner, walking on a `WalkingBody` too), `FloatingText3D` and
`PopEffect3D` (pooled effects).

## UI controls (`Scripts/UI/`)

```gdscript
IconLabel.create(COIN_ICON, "1.2K")                      # icon + text, centered together
reward_list.set_rewards({&"cash": 250})                  # "+250 [cash]"
```

`IconLabel`, `RewardList`, `SafeAreaContainer`, `CurrencyDisplay` (shows
`CurrencyData.icon`), `EnergyDisplay`, `StarsDisplay`, `BasePopup`. These
build the 2D menus and popups, and in-world screens shown on a `WorldScreen`.
`SafeAreaContainer.max_content_width` keeps a menu in a centered column on a
wide (full-screen desktop) window. `HouseBoardStyle` (static) builds the
old-house board theme from the main theme (`get_theme()`, `to_house_color()`,
`restyle_tree()`).

## Utilities (`Scripts/Utils/`)

`Palette` (design color tokens — see [DESIGN.md](DESIGN.md)), `NumberFormat`
(1.2K, 1,234, 2:05), `TweenFX` (UI tweens: pop, bounce_in, shake, pulse,
count_label…), `RayMath`, `PlaceholderMesh3D` & `BlobShadow3D`
(3D art stand-ins), `WorldUVMesh`, `TexturedBox3D`, `GroundPlane3D` and
`PropScatter3D` (real-art set dressing, see DESIGN.md), `SfxSynth`
(generated sounds). `Tools/bake_impostor.gd` turns a heavy glTF tree or plant
into a few textured quads for them.

## Data resources (`Scripts/Resources/`)

`GameConfig`, `LevelData`, `CurrencyData`, `UpgradeData` (with `branch` and
`required_reputation`), `UpgradeCatalog` (one per area), `ProductData` (in-app products), `AchievementData`,
`RewardBundle`, `WaveData`/`WaveEntry`, and the game's own: `IngredientData`,
`RecipeData`, `CustomerTypeData` (with its `voice`), `WeaponData` / `WeaponCatalog`, `RaidData`,
`VoiceData` / `VoiceLineData` (an NPC's lines by category, generated by
`Tools/generate_voices.ps1`), `DialogueData` / `DialogueNodeData` /
`DialogueReplyData` (conversations), `TownData` (the town),
`HouseLayout` (one stage of the house: walls, doors, windows, floor, walk regions),
`SnapshotBuffer` (`Scripts/Coop/`: a synced thing's recent transforms, sampled a moment behind so it glides),
`ShellRenovation` (one `HouseShell` surface's material per renovation level;
`HouseShell.apply_renovations(Profile.upgrades)` swaps them without a rebuild).

## Game rules (`Scripts/Game/`, pure, unit-tested)

```gdscript
var gauge: TimingGauge = TimingGauge.new(0.7, 0.2)   # gauge.advance(delta); gauge.stop() -> 0..1
QualityMath.tier_from_score(QualityMath.combine(accuracies, equipment_bonus))   # 1..4: Cut, Street, Pure, Premium
stash.add(&"glow", tier, units) / take(&"glow", min_tier, amount) / steal(n) / count(id, min_tier)
SalesMath.evaluate(asked_price, max_price, haggles)   # Verdict.ACCEPT / COUNTER / REFUSE
AutomationMath.get_missing_ingredients(recipe_ids, present_ids)   # what the hopper still feeds
AutomationMath.find_nearest(from, positions, ready_flags)          # the picker's next ripe plant
heat.add(n) / cool(delta) / get_ratio()
health.take(amount) / recover(delta) / is_down()   # PlayerHealth: hits, regeneration after a quiet spell
book.add_xp(SkillBook.Skill.CRAFTING, xp, tuning) / get_level(skill, tuning)   # skills grow by doing
HolsterRules.assign(catalog, loadout)   # {&"hip": knife, &"back": axe, &"chest": pistol}
MeleeMath.get_speed(last, hand, delta) / get_distance_to_body(hand, tip, feet, height)   # swings and reach
loadout.can_buy(axe, catalog) / is_unlocked(pistol, catalog)   # knife → axe → pistol → the other guns
RaidPlanner.build_raid(data, raid_number, heat_ratio) / is_raid_day(day, data)   # waves of cops, SWAT, rams
YardNavigation.steer(position, target, obstacles) / find_cover_spot(position, door, obstacles)
WeaponBallistics.get_shot_directions(forward, weapon, bloom) / get_damage_at(weapon, distance)   # pellets, cone, falloff
WalkMotion.get_arm_swing_speed(left_velocity, right_velocity) / ease_velocity(v, target, delta)    # arm-swing running
loadout.buy_weapon(gun) / equip(gun) / try_fire(gun) / add_ammo(gun, rounds)   # WeaponLoadout
clock.advance(delta) / get_hour() / get_phase() / just_passed_hour(25.0, delta)
TownLayout.build(town_data)   # blocks, buildings, walkable_regions, corners, lamps, parked_cars
streets.pick_start(house, range, taken, random) / find_route(from, to, variety, random)   # StreetRoutes: police ways
runner.start(chance) / choose(reply_index) / get_replies() / has_outcome(o)   # DialogueRunner
picker.pick(category, count)   # LinePicker: no repeats
```

## The House (`Scenes/Levels/House/`)

Areas — defense (`FrontGarden`), customers (`SalesWindow`), the house
(`Lab`, `Office`, the shift) and the town around it (`Town`) — each a `HouseFront` scene that gets a
`HouseContext` at setup and talks back only through signals; everything shared
goes through `Operation`. See `Scenes/Levels/House/README.md`.

```gdscript
var garden: FrontGarden = house_level.get_front(FrontGarden) as FrontGarden
context.operation.stash / heat / get_cash() / spend_cash(n, reason) / complete_sale(order, price)
context.operation.get_upgrade_value(Types.UPGRADE_BATCH) / get_unlocked_recipes() / bribe()
context.allows_customers() / is_raid_active() / cycle.get_day_in_cycle() / cycle.is_raid_day()
RaidPlanner.build_raid(raid_data, raid_number, heat_ratio) -> Array[RaidWave]
warning_requested.emit(tr("Police raid!"))     # from any front; score_earned / shift_lost likewise
window.spawn_customer(order) / get_front_customer() / sell_to_front() / accept_counter()   # SalesWindow
window.flow.spawn_customer() / is_active                                                   # CustomerFlow
town.start_talk(pedestrian) / choose_reply(i) / end_talk() / get_pedestrians()     # Town
context.operation.refer_customer()   # a buyer talked into it in the street (CustomerFlow sends them)
garden.fire_weapon(pointer) / yard.spawn_raider(scene) / yard.pick_raider(origin, dir, range)   # FrontGarden, Yard
garden.get_turrets() / security_pc.toggle_control() / turret.set_manual_aim(point)             # roof turrets, Security PC
garden.director.queue_wave(wave, raid_data) / spawn_raider(scene, health, squad, spot, route) / get_raiders_left()   # AttackerDirector: hordes through the town, vehicles
raider.march(route, yard) / is_marching()   # Raider: jogging through the streets first; PoliceVehicle (SquadCar, ArmoredVehicle, PoliceHelicopter) extends Raider
garden.tower_field.buy_kit(tower) / build(tower, spot) / upgrade_tower(tower) / get_towers()   # TowerField: towers anywhere outside
garden.monitor_wall.get_monitors()[0].toggle_control() / aim_at_view(uv)   # MonitorWall (office upgrade)
garden.switch_weapon() / loadout.upgrade(weapon) / weapon.get_damage(level)   # switching and weapon upgrades
lab.get_station(&"Cooker") / get_crate(&"glowcap")                                          # Lab
GameConfig.get_default().get_upgrades() / find_upgrade(id)   # all area catalogs
```
See [GAME.md](GAME.md) for the scene tree and the design.

## Physics

Combat, picking and movement are ray / circle math (`RayMath`, `YardNavigation`), not physics
bodies — cheaper on standalone headsets. If you add 3D physics, name its
layers under `layer_names/3d_physics` in Project Settings and add matching
`Types.LAYER_*` constants.

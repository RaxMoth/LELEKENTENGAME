## Game-wide enums, constants and StateChart event names.
##
## Holds no mutable state. Every magic string used across the project
## (groups, input actions, state chart events, currency ids) lives here so a
## typo becomes a compile error instead of a silent bug.
##
## Dependencies: none
extends Node

# ============================================
# ENUMS
# ============================================

enum DamageType { PHYSICAL, FIRE, ICE, POISON, TRUE_DAMAGE }
enum HapticStrength { LIGHT, MEDIUM, HEAVY }
enum ProductType { CONSUMABLE, NON_CONSUMABLE, SUBSCRIPTION }
enum LevelOutcome { NONE, WON, LOST, QUIT }
## Which hand a tracked XR controller belongs to.
enum Hand { LEFT, RIGHT }
## One step of making product in the lab.
enum CraftStep { PROCESS, COMBINE, PACKAGE }
## What a hired crew member does.
enum WorkerRole { CRAFTER, DEALER, GUARD }

# ============================================
# GROUPS
# ============================================

const GROUP_ENEMY: StringName = &"enemy"
## Things a hand or pointer can pick up (Grabbable).
const GROUP_GRABBABLE: StringName = &"grabbable"
## Things that hand out a new item when grabbed (ingredient crates).
const GROUP_GRAB_SOURCE: StringName = &"grab_source"
## Places a held item can be dropped into (ItemSocket).
const GROUP_ITEM_SOCKET: StringName = &"item_socket"
## 3D buttons a pointer can press (PointerButton).
const GROUP_POINTER_BUTTON: StringName = &"pointer_button"
## Node that pooled entities and effects are spawned under (LevelBase's World).
const GROUP_WORLD_ROOT: StringName = &"world_root"
## Every active WorldScreen (2D UI shown in 3D); XRPointer looks its targets up here.
const GROUP_WORLD_SCREEN: StringName = &"world_screen"

# ============================================
# INPUT ACTIONS (defined in Project Settings > Input Map)
# ============================================

const ACTION_PAUSE: StringName = &"pause"
## Flat simulator walking (WASD / arrows).
const ACTION_MOVE_FORWARD: StringName = &"move_forward"
const ACTION_MOVE_BACK: StringName = &"move_back"
const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
## Flat simulator quick travel to the level's travel spots (keys 1-4).
const ACTION_TRAVEL_1: StringName = &"travel_1"
const ACTION_TRAVEL_2: StringName = &"travel_2"
const ACTION_TRAVEL_3: StringName = &"travel_3"
const ACTION_TRAVEL_4: StringName = &"travel_4"
const ACTION_DEBUG_TOGGLE: StringName = &"debug_toggle"

# ============================================
# XR (action names in openxr_action_map.tres: Godot's default set)
# ============================================

const XR_INTERFACE_OPENXR: StringName = &"OpenXR"
const XR_TRACKER_LEFT_HAND: StringName = &"left_hand"
const XR_TRACKER_RIGHT_HAND: StringName = &"right_hand"
## Pose that points where the controller aims (use it for rays and pointers).
const XR_POSE_AIM: StringName = &"aim"
const XR_ACTION_TRIGGER_CLICK: StringName = &"trigger_click"
## Grip button: grab and let go of items.
const XR_ACTION_GRIP_CLICK: StringName = &"grip_click"
const XR_ACTION_MENU_BUTTON: StringName = &"menu_button"
## B / Y button: second way to open the pause menu.
const XR_ACTION_SECONDARY_BUTTON: StringName = &"by_button"
const XR_ACTION_THUMBSTICK: StringName = &"primary"
## Trackpads (HTC Vive wands) are bound to the "secondary" slot.
const XR_ACTION_TRACKPAD: StringName = &"secondary"
const XR_ACTION_TRACKPAD_CLICK: StringName = &"secondary_click"
const XR_ACTION_HAPTIC: StringName = &"haptic"

# ============================================
# ECONOMY IDS (must match ids in Ressources/game_config.tres)
# ============================================

## The operation's money: earned at the sales window, spent on everything.
const CURRENCY_CASH: StringName = &"cash"

# ============================================
# UPGRADE IDS (UpgradeData ids in Ressources/Upgrades, listed in game_config.tres)
# ============================================

## Production: better lab gear (quality bonus, wider sweet zones).
const UPGRADE_EQUIPMENT: StringName = &"prod_equipment"
## Production: more units per packaged batch.
const UPGRADE_BATCH: StringName = &"prod_batch"
const UPGRADE_RECIPE_FIZZ: StringName = &"prod_recipe_fizz"
const UPGRADE_RECIPE_HAZE: StringName = &"prod_recipe_haze"
## Sales: more customers can wait at the window.
const UPGRADE_QUEUE: StringName = &"sales_queue"
## Sales: customers wait longer.
const UPGRADE_PATIENCE: StringName = &"sales_patience"
## Sales: VIP buyers show up at night.
const UPGRADE_VIP: StringName = &"sales_vip"
## Defense: more door health.
const UPGRADE_DOOR: StringName = &"def_door"
## Defense: stronger blaster.
const UPGRADE_BLASTER: StringName = &"def_blaster"
const UPGRADE_HEAVY_GUN: StringName = &"def_heavy_gun"
## Workforce: hired crew (level = how many).
const UPGRADE_CRAFTER: StringName = &"work_crafter"
const UPGRADE_DEALER: StringName = &"work_dealer"
const UPGRADE_GUARD: StringName = &"work_guard"
## Workforce: crew skill.
const UPGRADE_TRAINING: StringName = &"work_training"
## House: bigger stash.
const UPGRADE_STORAGE: StringName = &"house_storage"
## House: locks and cameras make thieves take less.
const UPGRADE_SECURITY: StringName = &"house_security"
const ITEM_NO_ADS: StringName = &"no_ads"

# ============================================
# STATISTIC IDS (tracked by Profile.stats, referenced by achievements)
# ============================================

const STAT_LEVELS_PLAYED: StringName = &"levels_played"
const STAT_LEVELS_WON: StringName = &"levels_won"
const STAT_ENEMIES_DEFEATED: StringName = &"enemies_defeated"
const STAT_CASH_EARNED: StringName = &"cash_earned"
const STAT_UNITS_SOLD: StringName = &"units_sold"
const STAT_UNITS_CRAFTED: StringName = &"units_crafted"

# ============================================
# STATE CHART EVENTS — level flow (Scenes/Game/LevelBase.tscn)
# ============================================

const EVENT_LEVEL_START: StringName = &"level_start"
const EVENT_PAUSE: StringName = &"pause"
const EVENT_RESUME: StringName = &"resume"
const EVENT_WIN: StringName = &"win"
const EVENT_LOSE: StringName = &"lose"

# ============================================
# STATE CHART EVENTS — entities (Scenes/Levels/House)
# ============================================

const EVENT_TARGET_IN_RANGE: StringName = &"target_in_range"
const EVENT_TARGET_OUT_OF_RANGE: StringName = &"target_out_of_range"
const EVENT_DIED: StringName = &"died"
const EVENT_RESPAWN: StringName = &"respawn"
## A customer starts walking to a spot / reached it / was served or gave up.
const EVENT_WALK: StringName = &"walk"
const EVENT_ARRIVED: StringName = &"arrived"
const EVENT_LEAVE: StringName = &"leave"
## A lab workstation has its inputs and starts / finishes its timing step.
const EVENT_STATION_START: StringName = &"station_start"
const EVENT_STATION_DONE: StringName = &"station_done"
## Crew: hired, wage paid on time / missed.
const EVENT_HIRED: StringName = &"hired"
const EVENT_WAGE_PAID: StringName = &"wage_paid"
const EVENT_WAGE_MISSED: StringName = &"wage_missed"
## Day/night cycle of the house.
const EVENT_NIGHTFALL: StringName = &"nightfall"
const EVENT_DAYBREAK: StringName = &"daybreak"

# ============================================
# DUCK-TYPED HOOKS (optional methods nodes may implement)
# ============================================

## Called on a pooled node every time Pools hands it out.
const METHOD_POOL_SPAWNED: StringName = &"_on_pool_spawned"
## Called on a pooled node right before Pools takes it back.
const METHOD_POOL_DESPAWNED: StringName = &"_on_pool_despawned"
## Called on a new scene by SceneManager before it enters the tree.
const METHOD_RECEIVE_SCENE_PARAMS: StringName = &"receive_scene_params"
## Called on the current scene when the Android back button / Esc is pressed
## (a headset's menu button reaches levels through XRPlayerRig.menu_pressed).
## Return true when the scene consumed the request.
const METHOD_HANDLE_BACK: StringName = &"handle_back"
## Called by WaveSpawner after spawning an enemy so it can scale itself.
const METHOD_APPLY_WAVE_MODIFIERS: StringName = &"apply_wave_modifiers"

# ============================================
# SCENE PARAM KEYS (SceneManager.change_scene params dictionary)
# ============================================

const PARAM_LEVEL_DATA: StringName = &"level_data"

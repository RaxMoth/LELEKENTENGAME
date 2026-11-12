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
## Every front of the house (HouseFront): lab, garden, back window, office.
const GROUP_HOUSE_FRONT: StringName = &"house_front"
## Every hired-crew slot (Worker), whichever front it works in.
const GROUP_CREW: StringName = &"crew"
## Node that pooled entities and effects are spawned under (LevelBase's World).
const GROUP_WORLD_ROOT: StringName = &"world_root"
## Every active WorldScreen (2D UI shown in 3D); XRPointer looks its targets up here.
const GROUP_WORLD_SCREEN: StringName = &"world_screen"
## Co-op: spawned things the host streams to the other player (items,
## customers; raiders come through GROUP_ENEMY).
const GROUP_NET_ENTITY: StringName = &"net_entity"
## Co-op: scene nodes whose look the host streams (stations); they offer
## get_net_state() / apply_net_state(state).
const GROUP_NET_NODE: StringName = &"net_node"
## Parts of the house that show with an upgrade's level (UpgradeLook):
## door straps, the steel door frame, stash shelves.
const GROUP_UPGRADE_LOOK: StringName = &"upgrade_look"

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
# UPGRADE IDS — one block per area, matching Ressources/Upgrades/<Area>/.
# Add a new id at the end of your own area's block (keeps merges clean).
# ============================================

# --- Lab (production) ---
## Better lab gear (quality bonus, wider sweet zones).
const UPGRADE_EQUIPMENT: StringName = &"prod_equipment"
## More units per packaged batch.
const UPGRADE_BATCH: StringName = &"prod_batch"
const UPGRADE_RECIPE_FIZZ: StringName = &"prod_recipe_fizz"
const UPGRADE_RECIPE_HAZE: StringName = &"prod_recipe_haze"
## Hired crafters (level = how many).
const UPGRADE_CRAFTER: StringName = &"work_crafter"
## More shroom plants on the grow shelf (level = how many extra).
const UPGRADE_PLANTS: StringName = &"lab_plants"
## The lab's gadgets, bought one after the other.
const UPGRADE_GRINDER: StringName = &"lab_grinder"
const UPGRADE_COOKER: StringName = &"lab_cooker"
const UPGRADE_PRESS: StringName = &"lab_press"

# --- Sales (customers) ---
## More customers can wait at the window.
const UPGRADE_QUEUE: StringName = &"sales_queue"
## Customers wait longer.
const UPGRADE_PATIENCE: StringName = &"sales_patience"
## VIP buyers show up at night.
const UPGRADE_VIP: StringName = &"sales_vip"
## Hired dealers (level = how many).
const UPGRADE_DEALER: StringName = &"work_dealer"

# --- Defense (front garden) ---
## More door health.
const UPGRADE_DOOR: StringName = &"def_door"
## Better rounds: every gun the player fires hits harder.
const UPGRADE_BLASTER: StringName = &"def_blaster"
## Roof turrets on the house front (level = how many).
const UPGRADE_TURRETS: StringName = &"def_turrets"
## The office PC that takes turrets over by hand.
const UPGRADE_SECURITY_PC: StringName = &"def_security_pc"
## Hired guards (level = how many).
const UPGRADE_GUARD: StringName = &"work_guard"

# --- House (crew, storage, security) ---
## Crew skill.
const UPGRADE_TRAINING: StringName = &"work_training"
## Bigger stash.
const UPGRADE_STORAGE: StringName = &"house_storage"
## A steel door frame: raiders do less damage to the front door (value = share).
const UPGRADE_SECURITY: StringName = &"house_security"
## Renovations: each makes one part of the house nicer (shabby -> patched
## up -> well kept) and heat cool down faster (value = percent per level).
## Inside walls (and, at level 2, the ceiling and frames).
const UPGRADE_RENOVATE_WALLS: StringName = &"house_walls"
## The floor boards.
const UPGRADE_RENOVATE_FLOOR: StringName = &"house_floor"
## The outside brickwork.
const UPGRADE_RENOVATE_FACADE: StringName = &"house_facade"
## The roof tiles.
const UPGRADE_RENOVATE_ROOF: StringName = &"house_roof"
## Every renovation (Operation sums their values into the heat cooling bonus).
const RENOVATION_UPGRADES: Array[StringName] = [UPGRADE_RENOVATE_WALLS, UPGRADE_RENOVATE_FLOOR, UPGRADE_RENOVATE_FACADE, UPGRADE_RENOVATE_ROOF]
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
# STATE CHART EVENTS — one block per area (Scenes/Levels/House/<Area>/).
# Add a new event at the end of your own area's block.
# ============================================

# --- Defense: attackers (Garden/Attacker.tscn) ---
const EVENT_TARGET_IN_RANGE: StringName = &"target_in_range"
const EVENT_TARGET_OUT_OF_RANGE: StringName = &"target_out_of_range"
const EVENT_DIED: StringName = &"died"
const EVENT_RESPAWN: StringName = &"respawn"
## Raiders in the yard (Garden/Raider.tscn): leave cover / reach cover.
const EVENT_MOVE: StringName = &"move"
const EVENT_TAKE_COVER: StringName = &"take_cover"
# --- Defense: the front door (Garden/FrontDoor.tscn) ---
## The door swung open / fell shut and latched / was bolted / was unbolted.
const EVENT_DOOR_OPENED: StringName = &"door_opened"
const EVENT_DOOR_CLOSED: StringName = &"door_closed"
const EVENT_DOOR_LOCKED: StringName = &"door_locked"
const EVENT_DOOR_UNLOCKED: StringName = &"door_unlocked"

# --- Sales: customers (Sales/Customer.tscn) ---
## A customer starts walking to a spot / reached it / was served or gave up.
const EVENT_WALK: StringName = &"walk"
const EVENT_ARRIVED: StringName = &"arrived"
const EVENT_LEAVE: StringName = &"leave"

# --- Lab: workstations (Lab/Workstation.tscn) ---
## A station has its inputs and starts / finishes its timing step.
const EVENT_STATION_START: StringName = &"station_start"
const EVENT_STATION_DONE: StringName = &"station_done"
## A shroom plant's crop is ready / was harvested (Lab/ShroomPlant.tscn).
const EVENT_PLANT_RIPE: StringName = &"plant_ripe"
const EVENT_PLANT_HARVESTED: StringName = &"plant_harvested"

# --- House: crew and the day (Workers/Worker.tscn, House.tscn) ---
## Crew: hired, wage paid on time / missed.
const EVENT_HIRED: StringName = &"hired"
const EVENT_WAGE_PAID: StringName = &"wage_paid"
const EVENT_WAGE_MISSED: StringName = &"wage_missed"
## Day/night cycle of the house.
const EVENT_NIGHTFALL: StringName = &"nightfall"
const EVENT_DAYBREAK: StringName = &"daybreak"
## The 3-day cycle (Cycle/HouseCycle.tscn): the raid night begins, a wave
## starts / is beaten, every wave of the raid is beaten.
const EVENT_RAID_START: StringName = &"raid_start"
const EVENT_WAVE_START: StringName = &"wave_start"
const EVENT_WAVE_CLEARED: StringName = &"wave_cleared"
const EVENT_RAID_CLEARED: StringName = &"raid_cleared"

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

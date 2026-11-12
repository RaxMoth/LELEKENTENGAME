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
enum Team { NEUTRAL, PLAYER, ENEMY }
enum TargetPriority { NEAREST, FARTHEST, STRONGEST, WEAKEST, FIRST_ON_PATH, LAST_ON_PATH }
enum HapticStrength { LIGHT, MEDIUM, HEAVY }
enum ProductType { CONSUMABLE, NON_CONSUMABLE, SUBSCRIPTION }
enum SwipeDirection { NONE, UP, DOWN, LEFT, RIGHT }
enum LevelOutcome { NONE, WON, LOST, QUIT }
enum StatModifierKind { FLAT, PERCENT }
## Which hand a tracked XR controller belongs to.
enum Hand { LEFT, RIGHT }

# ============================================
# PHYSICS LAYERS (bit values, keep in sync with [layer_names] in project.godot)
# ============================================

const LAYER_WORLD: int = 1 << 0
const LAYER_PLAYER: int = 1 << 1
const LAYER_ENEMY: int = 1 << 2
const LAYER_PLAYER_HURTBOX: int = 1 << 3
const LAYER_ENEMY_HURTBOX: int = 1 << 4
const LAYER_PICKUP: int = 1 << 5
const LAYER_INTERACTABLE: int = 1 << 6

# ============================================
# GROUPS
# ============================================

const GROUP_PLAYER: StringName = &"player"
const GROUP_ENEMY: StringName = &"enemy"
const GROUP_PICKUP: StringName = &"pickup"
## Node that pooled projectiles, pickups and effects are spawned under.
const GROUP_WORLD_ROOT: StringName = &"world_root"
## Every active WorldScreen (2D UI shown in 3D); XRPointer looks its targets up here.
const GROUP_WORLD_SCREEN: StringName = &"world_screen"

# ============================================
# INPUT ACTIONS (defined in Project Settings > Input Map)
# ============================================

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_UP: StringName = &"move_up"
const ACTION_MOVE_DOWN: StringName = &"move_down"
const ACTION_JUMP: StringName = &"jump"
const ACTION_PAUSE: StringName = &"pause"
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

const CURRENCY_COINS: StringName = &"coins"
const CURRENCY_GEMS: StringName = &"gems"
const ITEM_NO_ADS: StringName = &"no_ads"

# ============================================
# STATISTIC IDS (tracked by Profile.stats, referenced by achievements)
# ============================================

const STAT_LEVELS_PLAYED: StringName = &"levels_played"
const STAT_LEVELS_WON: StringName = &"levels_won"
const STAT_ENEMIES_DEFEATED: StringName = &"enemies_defeated"
const STAT_COINS_EARNED: StringName = &"coins_earned"
const STAT_TAPS: StringName = &"taps"
const STAT_BEST_RUNNER_SCORE: StringName = &"best_runner_score"
const STAT_MATCHES_MADE: StringName = &"matches_made"

# ============================================
# ENTITY STAT IDS (used by StatsComponent / StatModifier / PerkData)
# ============================================

const ENTITY_STAT_MAX_HEALTH: StringName = &"max_health"
const ENTITY_STAT_MOVE_SPEED: StringName = &"move_speed"
const ENTITY_STAT_DAMAGE: StringName = &"damage"
const ENTITY_STAT_FIRE_RATE: StringName = &"fire_rate"
const ENTITY_STAT_PROJECTILE_COUNT: StringName = &"projectile_count"
const ENTITY_STAT_PICKUP_RADIUS: StringName = &"pickup_radius"

# ============================================
# STATE CHART EVENTS — level flow (Scenes/Game/LevelBase.tscn)
# ============================================

const EVENT_LEVEL_START: StringName = &"level_start"
const EVENT_PAUSE: StringName = &"pause"
const EVENT_RESUME: StringName = &"resume"
const EVENT_WIN: StringName = &"win"
const EVENT_LOSE: StringName = &"lose"

# ============================================
# STATE CHART EVENTS — entities (Scenes/Entities/*)
# ============================================

const EVENT_MOVE_STARTED: StringName = &"move_started"
const EVENT_MOVE_STOPPED: StringName = &"move_stopped"
const EVENT_TARGET_ACQUIRED: StringName = &"target_acquired"
const EVENT_TARGET_LOST: StringName = &"target_lost"
const EVENT_TARGET_IN_RANGE: StringName = &"target_in_range"
const EVENT_TARGET_OUT_OF_RANGE: StringName = &"target_out_of_range"
const EVENT_DIED: StringName = &"died"
const EVENT_RESPAWN: StringName = &"respawn"

# ============================================
# DUCK-TYPED HOOKS (optional methods nodes may implement)
# ============================================

## Called on a pooled node every time Pools hands it out.
const METHOD_POOL_SPAWNED: StringName = &"_on_pool_spawned"
## Called on a pooled node right before Pools takes it back.
const METHOD_POOL_DESPAWNED: StringName = &"_on_pool_despawned"
## Called on a new scene by SceneManager before it enters the tree.
const METHOD_RECEIVE_SCENE_PARAMS: StringName = &"receive_scene_params"
## Called on the current scene when the Android back button / Esc is pressed.
## Return true when the scene consumed the request.
const METHOD_HANDLE_BACK: StringName = &"handle_back"
## Called by WaveSpawner after spawning an enemy so it can scale itself.
const METHOD_APPLY_WAVE_MODIFIERS: StringName = &"apply_wave_modifiers"

# ============================================
# SCENE PARAM KEYS (SceneManager.change_scene params dictionary)
# ============================================

const PARAM_LEVEL_DATA: StringName = &"level_data"

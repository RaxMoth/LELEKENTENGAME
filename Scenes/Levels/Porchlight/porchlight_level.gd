## Porchlight: a lane-defense game you stand inside. From the porch you plant
## blooms on the lawn, catch sparks with your pointer and shoot what gets
## through with the blaster in your other hand, while husks walk down five
## lanes toward you. Built for XR headsets; without one it runs in the flat
## simulator of XRPlayerRig (mouse / touch).
##
## XR: dominant trigger plants or clicks the board, off-hand trigger fires
## the blaster, sweeping a beam over a spark catches it, a thumbstick flick
## or trackpad click left / right changes the seed, menu or B / Y pauses.
## Flat: tap a tile to plant, tap an attacker or right-click to shoot, hover
## or tap sparks, drag to look around.
##
## Shows: XRPlayerRig, WorldScreen UI, LaneBoard / LaneGrid math picking,
## pooled 3D entities, LaneWaveSpawner, level-local economy.
##
## Dependencies: LevelBase, XRPlayerRig, LaneBoard, SeedBoard, WaveSpawner,
##               Pools, Audio, UI, Platform autoloads
extends LevelBase

const TRACER_SCENE: PackedScene = preload("res://Scenes/Levels/Porchlight/BeamTracer.tscn")
const PARAMETER_STARTING_SPARKS: StringName = &"starting_sparks"
const PARAMETER_STARTING_LIVES: StringName = &"starting_lives"

@export var defenders: Array[DefenderData] = []
@export var starting_sparks: int = 150
@export var starting_lives: int = 3

@export_group("Sparks")
@export var sky_spark_value: int = 25
@export var sky_spark_interval_seconds: float = 8.0
@export var sky_spark_fall_height: float = 5.0
@export var sky_spark_fall_seconds: float = 3.5

@export_group("Blaster")
@export var blaster_damage: float = 12.0
@export var blaster_interval_seconds: float = 0.3
@export var blaster_range: float = 40.0

@export_group("Score")
@export var score_per_life_left: int = 100

@export_group("Rendering")
## Bloom is a full-screen pass per eye: too expensive on standalone headsets and phones.
@export var glow_on_mobile: bool = false

var sparks: int = 0
var lives: int = 0
var selected_seed: int = 0

## Seconds until each seed can be planted again (same order as defenders).
var _seed_cooldowns: Array[float] = []
var _seconds_until_sky_spark: float = 0.0
var _blaster_cooldown: float = 0.0
var _announce_tween: Tween

@onready var rig: XRPlayerRig = %XRPlayerRig
@onready var board: LaneBoard = %LaneBoard
@onready var wave_spawner: WaveSpawner = %WaveSpawner
@onready var _board_screen: WorldScreen = %BoardScreen
@onready var _announcer: Label3D = %Announcer
@onready var _world_environment: WorldEnvironment = %WorldEnvironment

# ============================================
# LEVEL HOOKS
# ============================================

func _on_level_setup() -> void:
	hud.set_currency_visible(false)
	# A screen-space HUD is not visible inside a headset; the board in the world replaces it.
	hud.visible = not rig.is_xr_active
	score_changed.connect(func(new_score: int) -> void: _get_seed_board().set_score(new_score))
	if Platform.is_mobile() and not glow_on_mobile:
		_world_environment.environment.glow_enabled = false
	if level_data != null:
		starting_sparks = int(level_data.get_parameter(PARAMETER_STARTING_SPARKS, starting_sparks))
		starting_lives = int(level_data.get_parameter(PARAMETER_STARTING_LIVES, starting_lives))
	sparks = starting_sparks
	lives = starting_lives
	_seed_cooldowns.resize(defenders.size())
	_seed_cooldowns.fill(0.0)
	_seconds_until_sky_spark = sky_spark_interval_seconds * 0.5
	_announcer.hide()
	var seed_board: SeedBoard = _get_seed_board()
	seed_board.set_defenders(defenders)
	seed_board.seed_chosen.connect(select_seed)
	seed_board.set_hint(
		tr("Trigger: plant   ·   Other hand: blaster") if rig.is_xr_active
		else tr("Tap a tile to plant   ·   Tap an attacker to shoot"))
	select_seed(0)
	_refresh_status()


func _on_level_started() -> void:
	_announce(tr("Hold the porch!"), Palette.TEXT)
	wave_spawner.start()


func _level_process(delta: float) -> void:
	_blaster_cooldown = maxf(0.0, _blaster_cooldown - delta)
	_update_seed_cooldowns(delta)
	_update_sky_sparks(delta)
	_update_pointers()


func _on_level_finished(_result: LevelResult) -> void:
	wave_spawner.stop()
	board.freeze()
	for pointer: XRPointer in rig.get_active_pointers():
		pointer.set_world_hit_distance(RayMath.NO_HIT)


## Inside a headset there is no 2D menu to return to, so leaving starts a new run.
func quit_to_menu() -> void:
	if rig.is_xr_active:
		restart_level()
	else:
		super()

# ============================================
# PUBLIC API
# ============================================

func select_seed(seed_index: int) -> void:
	if defenders.is_empty():
		return
	selected_seed = posmod(seed_index, defenders.size())
	_get_seed_board().set_selected(selected_seed)


func add_sparks(amount: int) -> void:
	sparks = maxi(0, sparks + amount)
	_refresh_status()


## Plants the selected defender on a cell if it is free, affordable and off cooldown.
func try_plant(cell: Vector2i, pointer: XRPointer = null) -> bool:
	if not is_playing() or not board.grid.is_valid_cell(cell) or defenders.is_empty():
		return false
	var defender_data: DefenderData = defenders[selected_seed]
	var world_position: Vector3 = board.grid.cell_to_position(cell)
	var refusal: String = ""
	if not board.can_place(cell):
		refusal = tr("Taken")
	elif _seed_cooldowns[selected_seed] > 0.0:
		refusal = tr("Not ready")
	elif sparks < defender_data.cost:
		refusal = tr("Need %d") % defender_data.cost
	if not refusal.is_empty():
		Audio.play_ui(Audio.UI_ERROR)
		FloatingText3D.spawn(refusal, world_position + Vector3(0.0, 0.9, 0.0), Palette.DANGER, board.get_effects_root())
		return false
	board.place_defender(defender_data, cell)
	_seed_cooldowns[selected_seed] = defender_data.cooldown_seconds
	add_sparks(-defender_data.cost)
	Audio.play_sfx_at_3d(SfxSynth.get_preset(&"pop"), world_position, 0.05)
	PopEffect3D.spawn(world_position + Vector3(0.0, 0.3, 0.0), defender_data.icon_color, 0.9, board.get_effects_root())
	if pointer != null:
		rig.pulse(pointer, Types.HapticStrength.MEDIUM)
	return true


## Fires the blaster along a pointer's ray. Returns the attacker it hit, or null.
func fire_blaster(pointer: XRPointer) -> LaneEnemy:
	if not is_playing() or _blaster_cooldown > 0.0:
		return null
	_blaster_cooldown = blaster_interval_seconds
	var enemy: LaneEnemy = board.pick_enemy(pointer.ray_origin, pointer.ray_direction, blaster_range)
	var beam_end: Vector3 = pointer.get_point(blaster_range)
	if enemy != null:
		beam_end = enemy.get_hit_center()
		enemy.take_hit(blaster_damage, self)
		PopEffect3D.spawn(beam_end, Palette.PROJECTILE, 0.4, board.get_effects_root())
	else:
		var ground_distance: float = board.get_ground_distance(pointer.ray_origin, pointer.ray_direction)
		if ground_distance != RayMath.NO_HIT and ground_distance < blaster_range:
			beam_end = pointer.get_point(ground_distance)
	var tracer: BeamTracer = Pools.spawn_3d(TRACER_SCENE, board.get_effects_root(), pointer.ray_origin) as BeamTracer
	tracer.fire(_get_muzzle_position(pointer), beam_end)
	Audio.play_sfx_at_3d(SfxSynth.get_preset(&"shoot"), pointer.ray_origin, 0.1, -4.0)
	rig.pulse(pointer, Types.HapticStrength.LIGHT)
	return enemy

# ============================================
# PLAYER INPUT (connected in Porchlight.tscn)
# ============================================

func _on_rig_primary_action_pressed(pointer: XRPointer) -> void:
	if not is_playing():
		return
	# One cursor does everything on a flat screen: sparks first, then attackers, then tiles.
	if not rig.is_xr_active:
		if _catch_spark(pointer):
			return
		if board.pick_enemy(pointer.ray_origin, pointer.ray_direction, blaster_range) != null:
			fire_blaster(pointer)
			return
	try_plant(board.pick_cell(pointer.ray_origin, pointer.ray_direction), pointer)


func _on_rig_secondary_action_pressed(pointer: XRPointer) -> void:
	fire_blaster(pointer)


func _on_rig_menu_pressed() -> void:
	if phase == Phase.PAUSED:
		UI.close_top_popup()
	else:
		pause_level()


func _on_rig_selection_step_requested(step: int) -> void:
	select_seed(selected_seed + step)
	Audio.play_ui(Audio.UI_CLICK)

# ============================================
# BOARD & WAVE EVENTS (connected in Porchlight.tscn)
# ============================================

func _on_board_enemy_defeated(enemy: LaneEnemy) -> void:
	add_score(enemy.score_value)


func _on_board_enemy_reached_home(_enemy: LaneEnemy) -> void:
	if not is_playing():
		return
	lives -= 1
	_refresh_status()
	_announce(tr("Breach!"), Palette.DANGER)
	Audio.play_sfx(SfxSynth.get_preset(&"explosion"))
	for pointer: XRPointer in rig.get_active_pointers():
		rig.pulse(pointer, Types.HapticStrength.HEAVY)
	if lives <= 0:
		lose()


func _on_wave_spawner_wave_started(wave_number: int, _wave: WaveData) -> void:
	_announce(tr("Wave %d") % wave_number, Palette.TEXT)
	_refresh_status()


func _on_wave_spawner_all_waves_cleared() -> void:
	add_score(lives * score_per_life_left)
	win()

# ============================================
# INTERNALS
# ============================================

func _get_seed_board() -> SeedBoard:
	return _board_screen.content as SeedBoard


func _update_seed_cooldowns(delta: float) -> void:
	var seed_board: SeedBoard = _get_seed_board()
	for seed_index: int in _seed_cooldowns.size():
		if _seed_cooldowns[seed_index] <= 0.0:
			continue
		_seed_cooldowns[seed_index] = maxf(0.0, _seed_cooldowns[seed_index] - delta)
		seed_board.set_cooldown_ratio(seed_index, _seed_cooldowns[seed_index] / maxf(0.001, defenders[seed_index].cooldown_seconds))


func _update_sky_sparks(delta: float) -> void:
	_seconds_until_sky_spark -= delta
	if _seconds_until_sky_spark <= 0.0:
		_seconds_until_sky_spark = sky_spark_interval_seconds
		board.drop_sky_spark(sky_spark_value, sky_spark_fall_height, sky_spark_fall_seconds)


## Per frame: catch sparks under any beam, mark the tile under the planting
## pointer and tell each pointer where its beam ends.
func _update_pointers() -> void:
	var tool_pointer: XRPointer = rig.get_tool_pointer()
	for pointer: XRPointer in rig.get_active_pointers():
		if pointer.is_over_screen():
			if pointer == tool_pointer:
				board.show_highlight(LaneGrid.INVALID_CELL, false)
			continue
		_catch_spark(pointer)
		var hit_distance: float = board.get_ground_distance(pointer.ray_origin, pointer.ray_direction)
		if pointer == tool_pointer:
			var cell: Vector2i = board.pick_cell(pointer.ray_origin, pointer.ray_direction)
			board.show_highlight(cell, board.can_place(cell))
			if not board.grid.is_valid_cell(cell):
				hit_distance = RayMath.NO_HIT
		if pointer != tool_pointer or not rig.is_xr_active:
			var enemy: LaneEnemy = board.pick_enemy(pointer.ray_origin, pointer.ray_direction, blaster_range)
			if enemy != null:
				hit_distance = pointer.ray_origin.distance_to(enemy.get_hit_center())
			elif pointer != tool_pointer:
				hit_distance = RayMath.NO_HIT
		pointer.set_world_hit_distance(hit_distance)


func _catch_spark(pointer: XRPointer) -> bool:
	var orb: SparkOrb = board.pick_spark(pointer.ray_origin, pointer.ray_direction)
	if orb == null:
		return false
	orb.collect()
	add_sparks(orb.value)
	FloatingText3D.spawn("+%d" % orb.value, orb.global_position, Palette.GOLD, board.get_effects_root())
	Audio.play_sfx_at_3d(SfxSynth.get_preset(&"coin"), orb.global_position, 0.08)
	rig.pulse(pointer, Types.HapticStrength.LIGHT)
	return true


## The cursor ray of the flat simulator starts in the camera, so its beam is
## drawn from a little below the view instead.
func _get_muzzle_position(pointer: XRPointer) -> Vector3:
	if rig.is_xr_active:
		return pointer.ray_origin
	var head: Transform3D = rig.get_head_transform()
	return head.origin - head.basis.y * 0.25 + head.basis.x * 0.2


func _refresh_status() -> void:
	var total_waves: int = wave_spawner.get_total_waves()
	# The board in the world is the only status display; the flat HUD keeps the pause button.
	var seed_board: SeedBoard = _get_seed_board()
	seed_board.set_sparks(sparks)
	seed_board.set_lives(lives, starting_lives)
	seed_board.set_wave(wave_spawner.current_wave_number, total_waves)


## Big text over the lawn — in the world rather than on the HUD, so it is
## also visible inside a headset.
func _announce(message: String, color: Color) -> void:
	if _announce_tween != null:
		_announce_tween.kill()
	_announcer.text = message
	_announcer.modulate = color
	_announcer.outline_modulate = Color(Palette.BACKGROUND, 0.9)
	_announcer.scale = Vector3.ONE * 0.4
	_announcer.show()
	_announce_tween = create_tween()
	_announce_tween.tween_property(_announcer, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce_tween.tween_interval(1.0)
	_announce_tween.set_parallel(true)
	_announce_tween.tween_property(_announcer, "modulate:a", 0.0, 0.25)
	_announce_tween.tween_property(_announcer, "outline_modulate:a", 0.0, 0.25)
	_announce_tween.set_parallel(false)
	_announce_tween.tween_callback(_announcer.hide)

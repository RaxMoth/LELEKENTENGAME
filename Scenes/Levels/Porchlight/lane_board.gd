## The playing field of a lane-defense level: draws the lawn, owns the
## LaneGrid and everything standing on it, and answers the lane questions
## defenders, attackers and the player's pointers ask (who blocks me, is
## something in my lane, what does this ray hit). All of it is plain math on
## a small roster — no physics bodies.
##
## The node's origin is the middle of the home edge; lanes run toward -Z.
##
## Dependencies: LaneGrid, RayMath, LaneDefender, LaneEnemy, SparkOrb,
##               DefenderData, PlaceholderMesh3D, Palette, Pools autoload
class_name LaneBoard
extends Node3D

signal enemy_defeated(enemy: LaneEnemy)
signal enemy_reached_home(enemy: LaneEnemy)

const SPARK_SCENE: PackedScene = preload("res://Scenes/Levels/Porchlight/SparkOrb.tscn")
const HIGHLIGHT_OPACITY: float = 0.38
const HIGHLIGHT_INSET: float = 0.92
const HIGHLIGHT_HEIGHT: float = 0.02

@export var lane_count: int = 5
@export var column_count: int = 7
## x = lane width, y = column depth (meters).
@export var cell_size: Vector2 = Vector2(1.2, 1.2)
## How far beyond the far edge attackers appear.
@export var spawn_margin: float = 1.6
## Height flying attackers travel at.
@export var flyer_height: float = 2.3
## Attackers stop this far before the middle of an occupied cell.
@export var defender_stop_distance: float = 0.42
## Height sparks hover at, above the ground.
@export var spark_hover_height: float = 1.1

var grid: LaneGrid = null

var _enemies: Array[LaneEnemy] = []
var _orbs: Array[SparkOrb] = []
## Shuffled lane indices, so spawns spread over every lane before repeating.
var _lane_bag: Array[int] = []

@onready var _ground: MeshInstance3D = %Ground
@onready var _highlight: MeshInstance3D = %Highlight
@onready var _defender_root: Node3D = %Defenders
@onready var _enemy_root: Node3D = %Enemies
@onready var _effects_root: Node3D = %Effects


func _ready() -> void:
	grid = LaneGrid.new(lane_count, column_count, cell_size, global_position)
	_build_ground()
	_build_highlight()

# ============================================
# GEOMETRY
# ============================================

func get_home_z() -> float:
	return grid.get_home_z()


## Z where attackers appear (and where stray bolts give up).
func get_spawn_z() -> float:
	return grid.get_far_z() - spawn_margin


func get_effects_root() -> Node3D:
	return _effects_root


## Distance along a ray to the lawn plane, or RayMath.NO_HIT.
func get_ground_distance(ray_origin: Vector3, ray_direction: Vector3) -> float:
	return RayMath.intersect_ground(ray_origin, ray_direction, grid.origin.y)


## Cell a ray lands on, or LaneGrid.INVALID_CELL.
func pick_cell(ray_origin: Vector3, ray_direction: Vector3) -> Vector2i:
	var distance: float = get_ground_distance(ray_origin, ray_direction)
	if distance == RayMath.NO_HIT:
		return LaneGrid.INVALID_CELL
	return grid.position_to_cell(ray_origin + ray_direction * distance)


## Marks a cell as the current placement target; INVALID_CELL hides the marker.
func show_highlight(cell: Vector2i, is_placeable: bool) -> void:
	_highlight.visible = grid.is_valid_cell(cell)
	if not _highlight.visible:
		return
	_highlight.global_position = grid.cell_to_position(cell) + Vector3(0.0, HIGHLIGHT_HEIGHT, 0.0)
	_highlight.material_override = PlaceholderMesh3D.get_shared_material(
		Color(Palette.PRIMARY if is_placeable else Palette.DANGER, HIGHLIGHT_OPACITY), 0.0, true)

# ============================================
# DEFENDERS
# ============================================

func can_place(cell: Vector2i) -> bool:
	return grid.is_free(cell)


## Builds a defender on a free cell. Returns null when the cell is taken.
func place_defender(defender_data: DefenderData, cell: Vector2i) -> LaneDefender:
	if not can_place(cell) or defender_data.scene == null:
		return null
	var defender: LaneDefender = defender_data.scene.instantiate() as LaneDefender
	_defender_root.add_child(defender)
	defender.global_position = grid.cell_to_position(cell)
	defender.setup(defender_data, self, cell)
	defender.destroyed.connect(_on_defender_destroyed)
	grid.set_occupant(cell, defender)
	return defender


## Defender that stops a ground attacker whose front edge is at [param front_z].
func get_blocker(lane: int, front_z: float) -> LaneDefender:
	return grid.get_blocker(lane, front_z, defender_stop_distance) as LaneDefender


func get_defender_count() -> int:
	return grid.get_occupied_cells().size()

# ============================================
# ATTACKERS
# ============================================

## Spawns a (pooled) attacker beyond the far edge of a lane picked from the bag.
func spawn_enemy(enemy_scene: PackedScene) -> LaneEnemy:
	var lane: int = _draw_lane()
	var spawn_position: Vector3 = Vector3(grid.get_lane_x(lane), grid.origin.y, get_spawn_z())
	var enemy: LaneEnemy = Pools.spawn_3d(enemy_scene, _enemy_root, spawn_position) as LaneEnemy
	if enemy.is_flying:
		enemy.global_position.y += flyer_height
	enemy.enter_lane(self, lane)
	if not enemy.defeated.is_connected(_on_enemy_defeated):
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.reached_home.connect(_on_enemy_reached_home)
	_enemies.append(enemy)
	return enemy


func get_enemy_count() -> int:
	return _enemies.size()


## True when a living ground attacker walks in [param lane] beyond [param from_z].
func has_ground_enemy_ahead(lane: int, from_z: float) -> bool:
	for enemy: LaneEnemy in _enemies:
		if enemy.lane == lane and not enemy.is_flying and enemy.is_alive() and enemy.global_position.z < from_z:
			return true
	return false


## First living ground attacker a bolt meets while moving from [param near_z]
## to [param far_z] (toward -Z) in [param lane], or null.
func find_ground_enemy_between(lane: int, near_z: float, far_z: float) -> LaneEnemy:
	var first_enemy: LaneEnemy = null
	for enemy: LaneEnemy in _enemies:
		if enemy.lane != lane or enemy.is_flying or not enemy.is_alive():
			continue
		var enemy_z: float = enemy.global_position.z
		if enemy_z - enemy.hit_radius > near_z or enemy_z + enemy.hit_radius < far_z:
			continue
		if first_enemy == null or enemy_z > first_enemy.global_position.z:
			first_enemy = enemy
	return first_enemy


## Nearest living attacker (walking or flying) a ray hits within [param max_distance].
func pick_enemy(ray_origin: Vector3, ray_direction: Vector3, max_distance: float) -> LaneEnemy:
	var nearest_enemy: LaneEnemy = null
	var nearest_distance: float = max_distance
	for enemy: LaneEnemy in _enemies:
		if not enemy.is_alive():
			continue
		var distance: float = RayMath.intersect_sphere(ray_origin, ray_direction, enemy.get_hit_center(), enemy.hit_radius)
		if distance != RayMath.NO_HIT and distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	return nearest_enemy

# ============================================
# SPARKS
# ============================================

## A spark pops out at [param world_position] and hovers there.
func release_spark(world_position: Vector3, spark_value: int) -> SparkOrb:
	return _spawn_spark(world_position, world_position + Vector3(0.0, 0.25, 0.0), spark_value, 0.35)


## A spark drifts down from the sky onto a random cell.
func drop_sky_spark(spark_value: int, fall_height: float, fall_seconds: float) -> SparkOrb:
	var cell: Vector2i = Vector2i(randi() % lane_count, randi() % column_count)
	var rest_position: Vector3 = grid.cell_to_position(cell) + Vector3(0.0, spark_hover_height, 0.0)
	return _spawn_spark(rest_position + Vector3(0.0, fall_height, 0.0), rest_position, spark_value, fall_seconds)


## Catchable spark closest to a ray, or null. A spark counts when the ray
## passes within its catch radius.
func pick_spark(ray_origin: Vector3, ray_direction: Vector3) -> SparkOrb:
	var nearest_orb: SparkOrb = null
	var nearest_distance: float = INF
	for orb_index: int in range(_orbs.size() - 1, -1, -1):
		var orb: SparkOrb = _orbs[orb_index]
		if not orb.is_catchable:
			_orbs.remove_at(orb_index)
			continue
		if RayMath.distance_to_point(ray_origin, ray_direction, orb.global_position) > orb.catch_radius:
			continue
		var distance: float = ray_origin.distance_to(orb.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_orb = orb
	return nearest_orb

# ============================================
# LEVEL FLOW
# ============================================

## The level is over: everything on the board stops where it stands.
func freeze() -> void:
	show_highlight(LaneGrid.INVALID_CELL, false)
	for container: Node3D in [_defender_root, _enemy_root, _effects_root]:
		container.process_mode = Node.PROCESS_MODE_DISABLED

# ============================================
# INTERNALS
# ============================================

func _draw_lane() -> int:
	if _lane_bag.is_empty():
		for lane: int in lane_count:
			_lane_bag.append(lane)
		_lane_bag.shuffle()
	return _lane_bag.pop_back()


func _spawn_spark(from_position: Vector3, rest_position: Vector3, spark_value: int, fall_seconds: float) -> SparkOrb:
	var orb: SparkOrb = Pools.spawn_3d(SPARK_SCENE, _effects_root, from_position) as SparkOrb
	orb.drop(from_position, rest_position, spark_value, fall_seconds)
	_orbs.append(orb)
	return orb


## One quad with a tiny checker texture (one pixel per cell) instead of a mesh per cell.
func _build_ground() -> void:
	var checker: Image = Image.create(lane_count, column_count, false, Image.FORMAT_RGB8)
	for lane: int in lane_count:
		for column: int in column_count:
			checker.set_pixel(lane, column, Palette.WORLD_DETAIL if (lane + column) % 2 == 0 else Palette.SURFACE_RAISED)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(checker)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.95
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(grid.get_width(), grid.get_depth())
	_ground.mesh = plane
	_ground.material_override = material
	_ground.position = Vector3(0.0, 0.0, -grid.get_depth() * 0.5)


func _build_highlight() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = cell_size * HIGHLIGHT_INSET
	_highlight.mesh = quad
	_highlight.visible = false


func _on_defender_destroyed(defender: LaneDefender) -> void:
	if grid.get_occupant(defender.cell) == defender:
		grid.clear_cell(defender.cell)


func _on_enemy_defeated(enemy: LaneEnemy) -> void:
	_enemies.erase(enemy)
	enemy_defeated.emit(enemy)


func _on_enemy_reached_home(enemy: LaneEnemy) -> void:
	_enemies.erase(enemy)
	enemy_reached_home.emit(enemy)

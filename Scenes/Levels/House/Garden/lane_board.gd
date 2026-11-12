## The front garden: a tower-defense path of a few lanes ending at the front
## door. Owns the LaneGrid and everything standing on it, and answers the
## lane questions towers, attackers and the player's pointers ask (who
## blocks me, is something in my lane, what does this ray hit). All of it is
## plain math on a small roster — no physics bodies.
##
## The node's origin is the middle of the door edge; lanes run toward -Z.
## The board must not be rotated (attackers walk along world +Z).
##
## Dependencies: LaneGrid, RayMath, LaneDefender, LaneEnemy, FrontDoor,
##               TowerData, PlaceholderMesh3D, Palette, Pools autoload
class_name LaneBoard
extends Node3D

signal enemy_defeated(enemy: LaneEnemy)
## A thief reached the door and runs off with stock.
signal enemy_reached_home(enemy: LaneEnemy)

const HIGHLIGHT_OPACITY: float = 0.38
const HIGHLIGHT_INSET: float = 0.92
const HIGHLIGHT_HEIGHT: float = 0.02

@export var lane_count: int = 3
@export var column_count: int = 6
## x = lane width, y = column depth (meters).
@export var cell_size: Vector2 = Vector2(1.4, 1.3)
## How far beyond the far edge attackers appear.
@export var spawn_margin: float = 1.6
## Towers stop attackers this far before the middle of their cell.
@export var defender_stop_distance: float = 0.42
## The door every attacker is heading for.
@export var door: FrontDoor

var grid: LaneGrid = null

var _enemies: Array[LaneEnemy] = []
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


## Distance along a ray to the garden plane, or RayMath.NO_HIT.
func get_ground_distance(ray_origin: Vector3, ray_direction: Vector3) -> float:
	return RayMath.intersect_ground(ray_origin, ray_direction, grid.origin.y)


## Cell a ray lands on, or LaneGrid.INVALID_CELL.
func pick_cell(ray_origin: Vector3, ray_direction: Vector3) -> Vector2i:
	var distance: float = get_ground_distance(ray_origin, ray_direction)
	if distance == RayMath.NO_HIT:
		return LaneGrid.INVALID_CELL
	return grid.position_to_cell(ray_origin + ray_direction * distance)


## Marks a cell as the current build target; INVALID_CELL hides the marker.
func show_highlight(cell: Vector2i, is_placeable: bool) -> void:
	_highlight.visible = grid.is_valid_cell(cell)
	if not _highlight.visible:
		return
	_highlight.global_position = grid.cell_to_position(cell) + Vector3(0.0, HIGHLIGHT_HEIGHT, 0.0)
	_highlight.material_override = PlaceholderMesh3D.get_shared_material(
		Color(Palette.PRIMARY if is_placeable else Palette.DANGER, HIGHLIGHT_OPACITY), 0.0, true)

# ============================================
# TOWERS
# ============================================

func can_place(cell: Vector2i) -> bool:
	return grid.is_free(cell)


## Builds a tower on a free cell. Returns null when the cell is taken.
func place_tower(tower_data: TowerData, cell: Vector2i) -> LaneDefender:
	if not can_place(cell) or tower_data.scene == null:
		return null
	var defender: LaneDefender = tower_data.scene.instantiate() as LaneDefender
	_defender_root.add_child(defender)
	defender.global_position = grid.cell_to_position(cell)
	defender.setup(tower_data, self, cell)
	defender.destroyed.connect(_on_defender_destroyed)
	grid.set_occupant(cell, defender)
	return defender


## Tower that stops an attacker whose front edge is at [param front_z].
func get_blocker(lane: int, front_z: float) -> LaneDefender:
	return grid.get_blocker(lane, front_z, defender_stop_distance) as LaneDefender


func get_tower_count() -> int:
	return grid.get_occupied_cells().size()

# ============================================
# ATTACKERS
# ============================================

## Spawns a (pooled) attacker beyond the far edge of a lane picked from the bag.
func spawn_enemy(enemy_scene: PackedScene) -> LaneEnemy:
	var lane: int = _draw_lane()
	var spawn_position: Vector3 = Vector3(grid.get_lane_x(lane), grid.origin.y, get_spawn_z())
	var enemy: LaneEnemy = Pools.spawn(enemy_scene, _enemy_root, spawn_position) as LaneEnemy
	enemy.enter_lane(self, lane)
	if not enemy.defeated.is_connected(_on_enemy_defeated):
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.reached_home.connect(_on_enemy_reached_home)
	_enemies.append(enemy)
	return enemy


func get_enemy_count() -> int:
	return _enemies.size()


func get_enemies() -> Array[LaneEnemy]:
	return _enemies


## True when a living attacker walks in [param lane] beyond [param from_z].
func has_enemy_ahead(lane: int, from_z: float) -> bool:
	for enemy: LaneEnemy in _enemies:
		if enemy.lane == lane and enemy.is_alive() and enemy.global_position.z < from_z:
			return true
	return false


## First living attacker a bolt meets while moving from [param near_z] to
## [param far_z] (toward -Z) in [param lane], or null.
func find_enemy_between(lane: int, near_z: float, far_z: float) -> LaneEnemy:
	var first_enemy: LaneEnemy = null
	for enemy: LaneEnemy in _enemies:
		if enemy.lane != lane or not enemy.is_alive():
			continue
		var enemy_z: float = enemy.global_position.z
		if enemy_z - enemy.hit_radius > near_z or enemy_z + enemy.hit_radius < far_z:
			continue
		if first_enemy == null or enemy_z > first_enemy.global_position.z:
			first_enemy = enemy
	return first_enemy


## Living attacker closest to the door within [param max_distance] of
## [param point] (guards), or null.
func find_enemy_nearest_door(point: Vector3, max_distance: float) -> LaneEnemy:
	var best_enemy: LaneEnemy = null
	for enemy: LaneEnemy in _enemies:
		if not enemy.is_alive() or enemy.global_position.distance_to(point) > max_distance:
			continue
		if best_enemy == null or enemy.global_position.z > best_enemy.global_position.z:
			best_enemy = enemy
	return best_enemy


## Nearest living attacker a ray hits within [param max_distance].
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
# LEVEL FLOW
# ============================================

## The shift is over: everything in the garden stops where it stands.
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

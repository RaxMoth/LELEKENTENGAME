## The open yard in front of the house: a wide field with trees, rocks,
## bushes and a parked car, fenced at its far edges. Raiders spawn at the
## edges and cross it freely toward the front door, using the obstacles as
## cover (YardNavigation). Everything here is plain math — round obstacles
## on the ground plane, sphere hit tests — no physics bodies.
##
## Obstacles are data (x, z, radius, kind); the visuals are built from them
## at load (and in the editor), like the HouseShell.
##
##   var raider: Raider = yard.spawn_raider(COP_SCENE)
##   var target: Raider = yard.pick_raider(ray_origin, ray_direction, 30.0)
##
## Dependencies: Raider, FrontDoor, YardNavigation, RayMath, PlaceholderMesh3D,
##               Pools autoload, Palette
@tool
class_name Yard
extends Node3D

## A raider went down (score, stats).
signal raider_defeated(raider: Raider)

enum ObstacleKind { PINE, TREE, ROCK, BUSH, CAR }

## Height (meters) each kind of obstacle covers a shot up to.
const COVER_HEIGHTS: Array[float] = [5.0, 4.2, 0.85, 1.0, 1.45]
const FENCE_HEIGHT: float = 1.1
const FENCE_POST_SPACING: float = 2.4

## The house's front door: where every raider wants to go.
@export var door: FrontDoor
## Walkable field (world X / Z): position = (min x, min z).
@export var bounds: Rect2 = Rect2(-14.0, -27.0, 28.0, 21.3):
	set(value):
		bounds = value
		_queue_rebuild()
## Obstacles (x, z, radius, ObstacleKind) — trees, rocks, bushes, a car.
@export var obstacles: Array[Vector4] = []:
	set(value):
		obstacles = value
		_queue_rebuild()
## Distance from the door (along its outside) of the first row of raiders hammering it.
@export var door_spot_distance: float = 0.55
## Raiders enter on the far edge and the far halves of the sides.
@export var side_spawn_share: float = 0.45

var _obstacle_circles: Array[Vector3] = []
var _raiders: Array[Raider] = []
## Living raiders' ground positions, refreshed once per physics frame.
var _positions: PackedVector2Array = PackedVector2Array()
var _visual_root: Node3D = null
var _is_rebuild_queued: bool = false
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _raider_root: Node3D = %Raiders
@onready var _effects_root: Node3D = %Effects


func _ready() -> void:
	_random.randomize()
	rebuild()


# Once per physics frame, before the raiders move: forget the ones back in
# the pool and gather everyone's position for separation.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_forget_despawned()
	_refresh_positions()

# ============================================
# THE FIELD
# ============================================

## Obstacles as (x, z, radius) for YardNavigation.
func get_obstacle_circles() -> Array[Vector3]:
	return _obstacle_circles


## The door on the ground plane.
func get_door_point() -> Vector2:
	return Vector2(door.global_position.x, door.global_position.z) if door != null else Vector2(0.0, bounds.end.y)


## Unit vector on the ground plane pointing from the door out into the yard.
func get_door_outward() -> Vector2:
	if door == null:
		return Vector2(0.0, -1.0)
	var outward: Vector3 = -door.global_transform.basis.z
	return Vector2(outward.x, outward.z).normalized()


## [param count] spots in front of the door where raiders stand to hit it.
func get_door_spots(count: int) -> PackedVector2Array:
	return YardNavigation.get_door_spots(get_door_point(), get_door_outward(), count, door_spot_distance)


## A random point on the yard's far edge or the far half of a side.
func get_spawn_point() -> Vector2:
	var far_z: float = bounds.position.y + 0.5
	var side_depth: float = bounds.size.y * side_spawn_share
	var roll: float = _random.randf()
	if roll < 0.5:
		return Vector2(_random.randf_range(bounds.position.x + 1.0, bounds.end.x - 1.0), far_z)
	var side_x: float = bounds.position.x + 0.5 if roll < 0.75 else bounds.end.x - 0.5
	return Vector2(side_x, _random.randf_range(far_z, far_z + side_depth))


## Keeps a point inside the field.
func clamp_to_bounds(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, bounds.position.x + 0.3, bounds.end.x - 0.3), clampf(point.y, bounds.position.y + 0.3, bounds.end.y))


## True when an obstacle tall enough stands between two points (a shot from
## the house, a turret or a guard at a raider in cover). Heights matter:
## rocks and bushes hide a crouching body but not from above.
func is_shot_blocked(from: Vector3, to: Vector3) -> bool:
	var from_flat: Vector2 = Vector2(from.x, from.z)
	var segment: Vector2 = Vector2(to.x, to.z) - from_flat
	var length_squared: float = segment.length_squared()
	for obstacle: Vector4 in obstacles:
		var center: Vector2 = Vector2(obstacle.x, obstacle.y)
		var radius: float = obstacle.z * 0.9
		if Vector2(to.x, to.z).distance_to(center) <= radius or from_flat.distance_to(center) <= radius:
			continue
		var along: float = 0.0 if length_squared <= 0.0 else clampf((center - from_flat).dot(segment) / length_squared, 0.0, 1.0)
		if center.distance_to(from_flat + segment * along) >= radius:
			continue
		var height_there: float = lerpf(from.y, to.y, along)
		if height_there < COVER_HEIGHTS[clampi(int(obstacle.w), 0, COVER_HEIGHTS.size() - 1)]:
			return true
	return false


## Distance along a ray to the ground (RayMath.NO_HIT when it points up).
func get_ground_distance(ray_origin: Vector3, ray_direction: Vector3) -> float:
	return RayMath.intersect_ground(ray_origin, ray_direction, global_position.y)


func get_effects_root() -> Node3D:
	return _effects_root

# ============================================
# RAIDERS
# ============================================

## Spawns a (pooled) raider at a random edge of the yard, in [param squad]
## (null = on its own) with its own spot [param door_spot] at the door.
func spawn_raider(raider_scene: PackedScene, squad: RaidSquad = null, door_spot: int = 0) -> Raider:
	var entry: Vector2 = get_spawn_point()
	var raider: Raider = Pools.spawn(raider_scene, _raider_root, Vector3(entry.x, global_position.y, entry.y)) as Raider
	raider.door_spot_index = door_spot
	if squad != null:
		squad.add(raider)
	# A pooled raider can come back before the registry noticed it left.
	if not _raiders.has(raider):
		_raiders.append(raider)
	_refresh_positions()
	raider.enter_yard(self)
	if not raider.defeated.is_connected(_on_raider_defeated):
		raider.defeated.connect(_on_raider_defeated)
	return raider


## Every raider in the yard (alive or falling).
func get_raiders() -> Array[Raider]:
	return _raiders


func get_alive_count() -> int:
	var alive: int = 0
	for raider: Raider in get_raiders():
		if raider.is_alive():
			alive += 1
	return alive


## Ground positions of every living raider, gathered once per physics frame
## and shared by all of them (separation; a walker's own spot is ignored by
## YardNavigation.steer because it is at distance 0).
func get_raider_positions() -> PackedVector2Array:
	return _positions


## Cover spots other living raiders are in or heading for (no two share one).
func get_reserved_spots(except: Raider = null) -> PackedVector2Array:
	var spots: PackedVector2Array = PackedVector2Array()
	for raider: Raider in _raiders:
		if raider != except and raider.is_alive():
			spots.append(raider.get_destination())
	return spots


## Nearest living raider whose body a ray hits within [param max_distance]
## and that no cover hides from the ray's origin.
func pick_raider(ray_origin: Vector3, ray_direction: Vector3, max_distance: float) -> Raider:
	var nearest: Raider = null
	var nearest_distance: float = max_distance
	for raider: Raider in get_raiders():
		if not raider.is_alive():
			continue
		var distance: float = RayMath.intersect_sphere(ray_origin, ray_direction, raider.get_hit_center(), raider.hit_radius)
		if distance != RayMath.NO_HIT and distance < nearest_distance and not is_shot_blocked(ray_origin, raider.get_hit_center()):
			nearest_distance = distance
			nearest = raider
	return nearest


## Living raider closest to the door within [param max_distance] of
## [param point] and in its line of fire (guards, turrets).
func find_raider_nearest_door(point: Vector3, max_distance: float) -> Raider:
	var door_point: Vector2 = get_door_point()
	var best: Raider = null
	var best_distance: float = INF
	for raider: Raider in get_raiders():
		if not raider.is_alive() or point.distance_to(raider.get_hit_center()) > max_distance:
			continue
		if is_shot_blocked(point, raider.get_hit_center()):
			continue
		var to_door: float = Vector2(raider.global_position.x, raider.global_position.z).distance_to(door_point)
		if to_door < best_distance:
			best_distance = to_door
			best = raider
	return best


## Stops everyone where they stand (the shift is over).
func freeze() -> void:
	for raider: Raider in get_raiders():
		raider.freeze()

# ============================================
# INTERNALS
# ============================================

func _on_raider_defeated(raider: Raider) -> void:
	raider_defeated.emit(raider)


func _refresh_positions() -> void:
	_positions.clear()
	for raider: Raider in _raiders:
		if raider.is_alive():
			_positions.append(Vector2(raider.global_position.x, raider.global_position.z))


func _forget_despawned() -> void:
	for raider_index: int in range(_raiders.size() - 1, -1, -1):
		var raider: Raider = _raiders[raider_index]
		if not is_instance_valid(raider) or Pools.is_in_pool(raider):
			_raiders.remove_at(raider_index)


func _queue_rebuild() -> void:
	if is_inside_tree() and not _is_rebuild_queued:
		_is_rebuild_queued = true
		rebuild.call_deferred()


## Rebuilds the obstacle list and the visuals (trees, rocks, fence) from the data.
func rebuild() -> void:
	_is_rebuild_queued = false
	_obstacle_circles.clear()
	for obstacle: Vector4 in obstacles:
		_obstacle_circles.append(Vector3(obstacle.x, obstacle.y, obstacle.z))
	if _visual_root != null:
		remove_child(_visual_root)
		_visual_root.queue_free()
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)
	for obstacle: Vector4 in obstacles:
		_build_obstacle(obstacle)
	_build_fence()


func _build_obstacle(obstacle: Vector4) -> void:
	var base: Vector3 = Vector3(obstacle.x, 0.0, obstacle.y) - global_position * Vector3(1.0, 0.0, 1.0)
	var radius: float = obstacle.z
	match int(obstacle.w):
		ObstacleKind.PINE:
			_add_part(base + Vector3(0.0, 0.5, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(radius * 0.35, 1.0, radius * 0.35), Palette.BACKGROUND_RAISED)
			_add_part(base + Vector3(0.0, 2.6, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(radius * 2.2, 4.4, radius * 2.2), Palette.SURFACE_RAISED, 0.0)
		ObstacleKind.TREE:
			_add_part(base + Vector3(0.0, 1.1, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(radius * 0.45, 2.2, radius * 0.45), Palette.BACKGROUND_RAISED)
			_add_part(base + Vector3(0.0, 3.0, 0.0), PlaceholderMesh3D.ShapeKind.SPHERE, Vector3(radius * 2.6, 2.4, radius * 2.6), Palette.STROKE)
		ObstacleKind.ROCK:
			_add_part(base + Vector3(0.0, radius * 0.35, 0.0), PlaceholderMesh3D.ShapeKind.SPHERE, Vector3(radius * 2.0, radius * 1.1, radius * 1.7), Palette.TEXT_FAINT)
		ObstacleKind.BUSH:
			_add_part(base + Vector3(0.0, 0.45, 0.0), PlaceholderMesh3D.ShapeKind.SPHERE, Vector3(radius * 2.0, 0.95, radius * 2.0), Palette.WORLD_DETAIL.lightened(0.15))
		ObstacleKind.CAR:
			_add_part(base + Vector3(0.0, 0.5, 0.0), PlaceholderMesh3D.ShapeKind.BOX, Vector3(radius * 1.1, 0.75, radius * 2.0), Palette.CATEGORY[1].darkened(0.45))
			_add_part(base + Vector3(0.0, 1.1, -radius * 0.1), PlaceholderMesh3D.ShapeKind.BOX, Vector3(radius * 1.0, 0.55, radius * 1.1), Palette.SURFACE)


func _build_fence() -> void:
	var corners: Array[Vector2] = [
		Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.position.x, bounds.position.y),
		Vector2(bounds.end.x, bounds.position.y), Vector2(bounds.end.x, bounds.end.y),
	]
	for side_index: int in corners.size() - 1:
		var from_point: Vector2 = corners[side_index]
		var to_point: Vector2 = corners[side_index + 1]
		var length: float = from_point.distance_to(to_point)
		var middle: Vector2 = (from_point + to_point) * 0.5
		var along_x: bool = is_equal_approx(from_point.y, to_point.y)
		var rail_size: Vector3 = Vector3(length, 0.08, 0.06) if along_x else Vector3(0.06, 0.08, length)
		for rail_height: float in [0.45, 0.95]:
			_add_part(_to_local_flat(middle) + Vector3(0.0, rail_height, 0.0), PlaceholderMesh3D.ShapeKind.BOX, rail_size, Palette.STROKE)
		var posts: int = maxi(1, floori(length / FENCE_POST_SPACING))
		for post_index: int in posts + 1:
			var post: Vector2 = from_point.lerp(to_point, float(post_index) / posts)
			_add_part(_to_local_flat(post) + Vector3(0.0, FENCE_HEIGHT * 0.5, 0.0), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.12, FENCE_HEIGHT, 0.12), Palette.STROKE)


func _to_local_flat(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y) - global_position * Vector3(1.0, 0.0, 1.0)


func _add_part(local_position: Vector3, shape: PlaceholderMesh3D.ShapeKind, part_size: Vector3, color: Color, top_scale: float = 1.0) -> void:
	var part: PlaceholderMesh3D = PlaceholderMesh3D.new()
	part.shape_kind = shape
	part.size = part_size
	part.color = color
	part.top_scale = top_scale
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.position = local_position
	_visual_root.add_child(part)

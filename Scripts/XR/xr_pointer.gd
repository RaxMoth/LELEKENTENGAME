## A pointing ray: the laser of an XR controller, or the cursor ray of the
## flat-screen simulator. It hovers and clicks WorldScreens on its own; game
## code reads ray_origin / ray_direction for its own picking (lawn cells,
## enemies...) and reports what it hit with set_world_hit_distance() so the
## beam ends there.
##
##   if not pointer.is_over_screen():
##       var distance: float = RayMath.intersect_ground(pointer.ray_origin, pointer.ray_direction)
##
## The ray leaves along the node's local -Z (the OpenXR "aim" pose). A
## controller pointer can steady it ([member steadying]): a shaky hand's
## small wobbles move the ray slowly, real aiming moves it at once, so small
## buttons are easy to hit; the beam follows the steadied ray.
##
## Dependencies: WorldScreen, RayMath, PlaceholderMesh3D, Palette, Types autoload
class_name XRPointer
extends Node3D

signal screen_entered(screen: WorldScreen)
signal screen_exited(screen: WorldScreen)

const BEAM_THICKNESS: float = 0.005
const BEAM_OPACITY: float = 0.55
## Reticle diameter per meter of distance, so it keeps its apparent size.
const RETICLE_SIZE_PER_METER: float = 0.012
const MIN_RETICLE_DISTANCE: float = 0.3

@export var max_distance: float = 40.0
## Beam length while pointing at nothing.
@export var idle_beam_length: float = 1.5
@export var beam_color: Color = Palette.PRIMARY
## Off for the flat simulator, where the ray starts at the camera.
@export var is_beam_visible: bool = true
## How much a controller's small wobbles are smoothed out (0 = not at all,
## the flat mouse pointer; 0.7 = a steady laser that still follows real moves).
@export_range(0.0, 0.95, 0.05) var steadying: float = 0.0
## Turns this large (degrees per frame) follow the hand at once.
@export_range(1.0, 30.0, 0.5) var steadying_full_follow_degrees: float = 6.0

## Disabled pointers hide and stop hovering screens.
var is_enabled: bool = true:
	set(value):
		is_enabled = value
		visible = value
		if not value:
			_leave_screen()
var ray_origin: Vector3 = Vector3.ZERO
var ray_direction: Vector3 = Vector3.FORWARD
var hovered_screen: WorldScreen = null
## Where the ray meets the hovered screen (only valid while is_over_screen()).
var screen_hit_point: Vector3 = Vector3.ZERO

var _beam: MeshInstance3D = null
var _reticle: MeshInstance3D = null
var _is_pressing_screen: bool = false
var _screen_hit_distance: float = RayMath.NO_HIT
var _world_hit_distance: float = RayMath.NO_HIT
var _interaction_hit_distance: float = RayMath.NO_HIT
## Beam and reticle hang under this, turned toward the steadied ray.
var _visual_root: Node3D = null
var _steadied_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)
	var beam_mesh: BoxMesh = BoxMesh.new()
	beam_mesh.size = Vector3.ONE
	_beam = _create_visual(beam_mesh, Color(beam_color, BEAM_OPACITY))
	var reticle_mesh: SphereMesh = SphereMesh.new()
	reticle_mesh.radius = 0.5
	reticle_mesh.height = 1.0
	reticle_mesh.radial_segments = 12
	reticle_mesh.rings = 6
	_reticle = _create_visual(reticle_mesh, beam_color)
	update_ray()


func _process(_delta: float) -> void:
	if not is_enabled:
		return
	# A controller that lost tracking hides itself; its pointer must let go too.
	if not is_visible_in_tree():
		_leave_screen()
		return
	update_ray()

# ============================================
# PUBLIC API
# ============================================

func is_over_screen() -> bool:
	return hovered_screen != null


## Point on the ray at [param distance] meters.
func get_point(distance: float) -> Vector3:
	return ray_origin + ray_direction * distance


## Places the ray (flat simulator, tests). XR controllers move the node instead.
func set_ray(origin: Vector3, direction: Vector3) -> void:
	global_position = origin
	var target: Vector3 = origin + direction
	var up_axis: Vector3 = Vector3.UP if absf(direction.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	look_at(target, up_axis)
	update_ray()


## Tells the pointer how far away the game object under the ray is
## (RayMath.NO_HIT for nothing), so the beam and reticle stop there.
func set_world_hit_distance(distance: float) -> void:
	_world_hit_distance = distance


## Tells the pointer how far away the item or 3D button under the ray is
## (set by the rig every frame), so the beam ends on it.
func set_interaction_hit_distance(distance: float) -> void:
	_interaction_hit_distance = distance


## Starts a click. Returns true when a WorldScreen took it; otherwise the
## press belongs to the game world.
func press() -> bool:
	if not is_enabled or hovered_screen == null:
		return false
	_is_pressing_screen = true
	hovered_screen.pointer_press(screen_hit_point)
	return true


## Ends a click started with press(). Returns true when a screen had taken it.
func release() -> bool:
	if not _is_pressing_screen:
		return false
	_is_pressing_screen = false
	if hovered_screen != null:
		hovered_screen.pointer_release(screen_hit_point)
	return true


## Recomputes the ray and what it hovers right now (runs every frame on its own).
func update_ray() -> void:
	ray_origin = global_position
	ray_direction = _steady(-global_transform.basis.z.normalized())
	_update_screen_hover()
	_update_visuals()

# ============================================
# INTERNALS
# ============================================

func _update_screen_hover() -> void:
	var nearest_screen: WorldScreen = null
	var nearest_distance: float = max_distance
	if is_inside_tree():
		for candidate: Node in get_tree().get_nodes_in_group(Types.GROUP_WORLD_SCREEN):
			var screen: WorldScreen = candidate as WorldScreen
			if screen == null:
				continue
			var distance: float = screen.intersect_ray(ray_origin, ray_direction)
			if distance != RayMath.NO_HIT and distance < nearest_distance:
				nearest_distance = distance
				nearest_screen = screen
	if nearest_screen != hovered_screen:
		_leave_screen()
		hovered_screen = nearest_screen
		if hovered_screen != null:
			screen_entered.emit(hovered_screen)
	if hovered_screen != null:
		_screen_hit_distance = nearest_distance
		screen_hit_point = get_point(nearest_distance)
		hovered_screen.pointer_move(screen_hit_point)
	else:
		_screen_hit_distance = RayMath.NO_HIT


func _leave_screen() -> void:
	if hovered_screen == null:
		return
	var previous_screen: WorldScreen = hovered_screen
	hovered_screen = null
	_is_pressing_screen = false
	_screen_hit_distance = RayMath.NO_HIT
	if is_instance_valid(previous_screen):
		previous_screen.pointer_leave()
		screen_exited.emit(previous_screen)


## The aimed direction, its small wobbles smoothed out by [member steadying].
func _steady(aimed: Vector3) -> Vector3:
	if steadying <= 0.0 or _steadied_direction == Vector3.ZERO:
		_steadied_direction = aimed
		return aimed
	var wobble_degrees: float = rad_to_deg(_steadied_direction.angle_to(aimed))
	var follow: float = lerpf(1.0 - steadying, 1.0, clampf(wobble_degrees / steadying_full_follow_degrees, 0.0, 1.0))
	_steadied_direction = _steadied_direction.slerp(aimed, follow).normalized()
	return _steadied_direction


func _update_visuals() -> void:
	if _beam == null:
		return
	var local_direction: Vector3 = (global_transform.basis.inverse() * ray_direction).normalized()
	if local_direction.dot(Vector3.FORWARD) > -0.99:
		_visual_root.basis = Basis(Quaternion(Vector3.FORWARD, local_direction))
	var hit_distance: float = _screen_hit_distance
	if hit_distance == RayMath.NO_HIT:
		hit_distance = _nearest_hit(_interaction_hit_distance, _world_hit_distance)
	var has_hit: bool = hit_distance != RayMath.NO_HIT
	var beam_length: float = hit_distance if has_hit else idle_beam_length
	_beam.visible = is_beam_visible
	_beam.position = Vector3(0.0, 0.0, -beam_length * 0.5)
	_beam.scale = Vector3(BEAM_THICKNESS, BEAM_THICKNESS, beam_length)
	_reticle.visible = has_hit
	if has_hit:
		_reticle.position = Vector3(0.0, 0.0, -hit_distance)
		_reticle.scale = Vector3.ONE * maxf(hit_distance, MIN_RETICLE_DISTANCE) * RETICLE_SIZE_PER_METER


func _nearest_hit(first_distance: float, second_distance: float) -> float:
	if first_distance == RayMath.NO_HIT:
		return second_distance
	if second_distance == RayMath.NO_HIT:
		return first_distance
	return minf(first_distance, second_distance)


func _create_visual(visual_mesh: Mesh, color: Color) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = visual_mesh
	var material: StandardMaterial3D = PlaceholderMesh3D.get_shared_material(color, 0.0, true).duplicate() as StandardMaterial3D
	# Drawn over the scene (transparent pass, no depth test) so the reticle
	# never sinks into what it points at.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.disable_fog = true
	material.render_priority = 10
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(visual)
	return visual

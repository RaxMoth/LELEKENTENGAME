## A flat panel in the 3D world that shows 2D UI (any Control scene) and lets
## XRPointers click it. This is how menus, HUD panels and popups reach the
## player inside a headset, where a screen-space overlay is not visible.
##
##   screen.content_scene = BOARD_SCENE                  # own UI, built at _ready
##   screen.attach_viewport(UI.get_world_viewport())     # or show an existing viewport
##   var board: SalesBoard = screen.content as SalesBoard
##
## The panel faces its local +Z. Pointer input is ray-vs-rectangle math (no
## physics) forwarded to the viewport as mouse events, so normal Buttons work.
##
## Dependencies: RayMath, Types autoload
class_name WorldScreen
extends Node3D

const OFFSCREEN_PIXEL: Vector2 = Vector2(-1000.0, -1000.0)

## Control scene instantiated into this screen's own viewport.
@export var content_scene: PackedScene
## Viewport size in pixels (ignored after attach_viewport()).
@export var resolution: Vector2i = Vector2i(960, 480)
## Width of the panel in meters; the height follows the resolution's aspect.
@export var width_meters: float = 1.0
@export var is_interactive: bool = true
## Keep the panel readable inside distance fog (far-away boards).
@export var ignore_fog: bool = true
## Draw over everything in the world (popups that must never be hidden).
@export var is_always_on_top: bool = false

## Root of the instantiated content_scene (null when showing an attached viewport).
var content: Control = null
## Inactive screens are hidden, stop rendering and ignore pointers.
var is_active: bool = true

var _viewport: SubViewport = null
var _owns_viewport: bool = false
var _quad: MeshInstance3D = null
var _quad_mesh: QuadMesh = null
var _material: StandardMaterial3D = null
var _is_pointer_down: bool = false
var _last_pixel: Vector2 = OFFSCREEN_PIXEL


func _ready() -> void:
	add_to_group(Types.GROUP_WORLD_SCREEN)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.disable_fog = ignore_fog
	if is_always_on_top:
		_material.no_depth_test = true
		_material.render_priority = RenderingServer.MATERIAL_RENDER_PRIORITY_MAX
	_quad_mesh = QuadMesh.new()
	_quad = MeshInstance3D.new()
	_quad.mesh = _quad_mesh
	_quad.material_override = _material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)
	if content_scene != null:
		_create_own_viewport()
	_apply_size()

# ============================================
# PUBLIC API
# ============================================

## Shows an existing viewport (for example UI.get_world_viewport()) instead of own content.
func attach_viewport(viewport: SubViewport) -> void:
	if _owns_viewport and _viewport != null:
		_viewport.queue_free()
	_owns_viewport = false
	content = null
	_viewport = viewport
	resolution = viewport.size
	_material.albedo_texture = viewport.get_texture()
	_apply_size()


func set_active(should_be_active: bool) -> void:
	if should_be_active == is_active:
		return
	is_active = should_be_active
	visible = should_be_active
	if not should_be_active:
		pointer_leave()
	if _owns_viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if should_be_active else SubViewport.UPDATE_DISABLED


## Keeps the panel visible but stops (or resumes) redrawing its own
## viewport — the last frame stays on the panel. Levels pause screens the
## player is far from or facing away from (each redraw costs a render pass).
func set_rendering(should_render: bool) -> void:
	if _owns_viewport and is_active:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if should_render else SubViewport.UPDATE_DISABLED


func is_rendering() -> bool:
	return _owns_viewport and is_active and _viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS


func get_size_meters() -> Vector2:
	return Vector2(width_meters, width_meters * float(resolution.y) / float(maxi(1, resolution.x)))


## Distance along a ray to the front of this screen, or RayMath.NO_HIT.
func intersect_ray(ray_origin: Vector3, ray_direction: Vector3) -> float:
	if not is_active or not is_interactive or _viewport == null or not is_visible_in_tree():
		return RayMath.NO_HIT
	var facing: Vector3 = global_transform.basis.z.normalized()
	if ray_direction.dot(facing) >= 0.0:
		return RayMath.NO_HIT
	var distance: float = RayMath.intersect_plane(ray_origin, ray_direction, global_position, facing)
	if distance == RayMath.NO_HIT:
		return RayMath.NO_HIT
	var local_point: Vector3 = to_local(ray_origin + ray_direction * distance)
	if not RayMath.is_on_screen(Vector2(local_point.x, local_point.y), get_size_meters()):
		return RayMath.NO_HIT
	return distance


## Viewport pixel under a world position on the panel.
func world_to_pixel(world_point: Vector3) -> Vector2:
	var local_point: Vector3 = to_local(world_point)
	return RayMath.screen_point_to_pixel(Vector2(local_point.x, local_point.y), get_size_meters(), resolution)


## World position of a viewport pixel (handy for tutorials and tests).
func pixel_to_world(pixel: Vector2) -> Vector3:
	var local_point: Vector2 = RayMath.pixel_to_screen_point(pixel, get_size_meters(), resolution)
	return to_global(Vector3(local_point.x, local_point.y, 0.0))

# ============================================
# POINTER INPUT (called by XRPointer)
# ============================================

func pointer_move(world_point: Vector3) -> void:
	_send_motion(world_to_pixel(world_point))


func pointer_press(world_point: Vector3) -> void:
	var pixel: Vector2 = world_to_pixel(world_point)
	_send_motion(pixel)
	_is_pointer_down = true
	_send_button(pixel, true)


func pointer_release(world_point: Vector3) -> void:
	if not _is_pointer_down:
		return
	_is_pointer_down = false
	_send_button(world_to_pixel(world_point), false)


## The pointer left the panel: cancels a held press and clears hover states.
func pointer_leave() -> void:
	if _viewport == null or _last_pixel == OFFSCREEN_PIXEL:
		return
	if _is_pointer_down:
		_is_pointer_down = false
		_send_button(OFFSCREEN_PIXEL, false)
	_send_motion(OFFSCREEN_PIXEL)

# ============================================
# INTERNALS
# ============================================

func _create_own_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = resolution
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_owns_viewport = true
	content = content_scene.instantiate() as Control
	_viewport.add_child(content)
	_material.albedo_texture = _viewport.get_texture()


func _apply_size() -> void:
	_quad_mesh.size = get_size_meters()


func _send_motion(pixel: Vector2) -> void:
	if _viewport == null:
		return
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pixel
	motion.global_position = pixel
	motion.relative = pixel - _last_pixel if _last_pixel != OFFSCREEN_PIXEL else Vector2.ZERO
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _is_pointer_down else 0
	_last_pixel = pixel
	_viewport.push_input(motion, true)


func _send_button(pixel: Vector2, is_pressed: bool) -> void:
	if _viewport == null:
		return
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = is_pressed
	button.position = pixel
	button.global_position = pixel
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if is_pressed else 0
	_viewport.push_input(button, true)

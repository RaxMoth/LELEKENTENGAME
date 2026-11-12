## A straight flight of wooden stairs as one mesh (one draw call): treads
## between two closed side boards (stringers), textured in meters like
## TexturedBox3D. The top edge is at the node's origin; the stairs run down
## along +X ([member total_run] long, [member total_rise] deep) and are
## [member width] wide along +Z. The last step is the floor below, so
## [member step_count] - 1 treads are built.
##
## Pair it with a WalkableRamp over the same footprint (get_ramp()), so the
## player walks down it.
##
## Dependencies: WorldUVMesh, WalkableRamp, PlaceholderMesh3D (fallback material), Palette
@tool
class_name Stairs3D
extends MeshInstance3D

@export_range(2, 40) var step_count: int = 13:
	set(value):
		step_count = value
		_rebuild()
@export var total_rise: float = 2.6:
	set(value):
		total_rise = value
		_rebuild()
@export var total_run: float = 3.3:
	set(value):
		total_run = value
		_rebuild()
@export var width: float = 1.0:
	set(value):
		width = value
		_rebuild()
@export var tread_thickness: float = 0.05:
	set(value):
		tread_thickness = value
		_rebuild()
## Side boards: thickness (along Z) and depth (measured straight down).
@export var stringer_size: Vector2 = Vector2(0.05, 0.3):
	set(value):
		stringer_size = value
		_rebuild()
## Shared material from Assets/Materials (uv1_scale = 1 / tile size in meters).
@export var stairs_material: Material:
	set(value):
		stairs_material = value
		_rebuild()
@export var fallback_color: Color = Palette.STROKE


func _ready() -> void:
	_rebuild()


func _validate_property(property: Dictionary) -> void:
	# Generated from the exports above, so never stored in the scene file.
	if property.name == "mesh" or property.name == "material_override":
		property.usage = PROPERTY_USAGE_NONE


## Height of one step.
func get_step_rise() -> float:
	return total_rise / float(step_count)


## Length of one tread.
func get_step_run() -> float:
	return total_run / float(step_count)


## The walkable slope over these (unrotated) stairs in world X / Z, through the
## middle of the treads (half a step below the top floor at the high end,
## the floor below at the low end), [param body_margin] in from each side.
func get_ramp(body_margin: float) -> WalkableRamp:
	var origin: Vector3 = global_position
	var footprint: Rect2 = Rect2(origin.x, origin.z + body_margin, total_run, maxf(0.05, width - body_margin * 2.0))
	return WalkableRamp.create(footprint, origin.y - get_step_rise() * 0.5, origin.y - total_rise, WalkableRamp.Edge.MIN_X)


func _rebuild() -> void:
	if not is_node_ready():
		return
	var surface_tool: SurfaceTool = WorldUVMesh.begin_surface()
	var rise: float = get_step_rise()
	var run: float = get_step_run()
	var tread_width: float = width - stringer_size.x * 2.0
	for step_index: int in range(1, step_count):
		var tread_top: float = -rise * step_index
		var center: Vector3 = Vector3(run * (step_index - 0.5), tread_top - tread_thickness * 0.5, width * 0.5)
		WorldUVMesh.add_box(surface_tool, center, Vector3(run, tread_thickness, tread_width))
	for side_z: float in [stringer_size.x * 0.5, width - stringer_size.x * 0.5]:
		_add_stringer(surface_tool, side_z)
	var stairs_mesh: ArrayMesh = ArrayMesh.new()
	var material: Material = stairs_material if stairs_material != null else PlaceholderMesh3D.get_shared_material(fallback_color)
	WorldUVMesh.commit_surface(surface_tool, stairs_mesh, material)
	mesh = stairs_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## One closed side board along the slope, centered on [param center_z]: a
## little above the tread line, stringer_size.y deep.
func _add_stringer(surface_tool: SurfaceTool, center_z: float) -> void:
	var lift: float = tread_thickness
	var half_thickness: float = stringer_size.x * 0.5
	var top_high: Vector2 = Vector2(0.0, lift)
	var top_low: Vector2 = Vector2(total_run, -total_rise + lift)
	var bottom_low: Vector2 = Vector2(total_run, -total_rise + lift - stringer_size.y)
	var bottom_high: Vector2 = Vector2(0.0, lift - stringer_size.y)
	var outline: Array[Vector2] = [top_high, top_low, bottom_low, bottom_high]
	var near_side: float = center_z - half_thickness
	var far_side: float = center_z + half_thickness
	_add_face(surface_tool, _at_depth(outline, near_side), Vector3.FORWARD)
	_add_face(surface_tool, _at_depth(outline, far_side), Vector3.BACK)
	var slope_up: Vector3 = Vector3(total_rise, total_run, 0.0).normalized()
	_add_face(surface_tool, PackedVector3Array([_point(top_high, near_side), _point(top_low, near_side), _point(top_low, far_side), _point(top_high, far_side)]), slope_up)
	_add_face(surface_tool, PackedVector3Array([_point(bottom_high, near_side), _point(bottom_low, near_side), _point(bottom_low, far_side), _point(bottom_high, far_side)]), -slope_up)
	_add_face(surface_tool, PackedVector3Array([_point(top_low, near_side), _point(bottom_low, near_side), _point(bottom_low, far_side), _point(top_low, far_side)]), Vector3.RIGHT)
	_add_face(surface_tool, PackedVector3Array([_point(top_high, near_side), _point(bottom_high, near_side), _point(bottom_high, far_side), _point(top_high, far_side)]), Vector3.LEFT)


## Adds a flat polygon facing [param outward] (its corners in either order).
func _add_face(surface_tool: SurfaceTool, corners: PackedVector3Array, outward: Vector3) -> void:
	var facing: Vector3 = (corners[2] - corners[0]).cross(corners[1] - corners[0])
	if facing.dot(outward) < 0.0:
		corners.reverse()
	WorldUVMesh.add_polygon(surface_tool, corners)


func _at_depth(outline: Array[Vector2], depth: float) -> PackedVector3Array:
	var corners: PackedVector3Array = PackedVector3Array()
	for corner: Vector2 in outline:
		corners.append(_point(corner, depth))
	return corners


func _point(side_point: Vector2, depth: float) -> Vector3:
	return Vector3(side_point.x, side_point.y, depth)

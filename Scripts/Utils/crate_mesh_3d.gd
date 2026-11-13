@tool
## An open wooden crate of slats as one mesh (one draw call): corner posts,
## a bottom board and gapped slats on all four sides. The bottom sits on the
## node's origin; UVs are in meters (WorldUVMesh), so a shared wood
## material tiles at real scale.
##
##   crate.size = Vector3(0.48, 0.34, 0.38)
##   crate.get_fill_height()   # where its contents heap up
##
## Dependencies: WorldUVMesh, PlaceholderMesh3D (fallback material), Palette
class_name CrateMesh3D
extends MeshInstance3D

## Outer width (X), height (Y) and depth (Z) in meters.
@export var size: Vector3 = Vector3(0.48, 0.34, 0.38):
	set(value):
		size = value
		_rebuild()
## Slats on each side, bottom to top.
@export_range(1, 6) var slat_count: int = 3:
	set(value):
		slat_count = value
		_rebuild()
## Gap between two slats.
@export var slat_gap: float = 0.025:
	set(value):
		slat_gap = value
		_rebuild()
## Thickness of the slats and the bottom board.
@export var board_thickness: float = 0.016:
	set(value):
		board_thickness = value
		_rebuild()
## Corner posts (square).
@export var post_size: float = 0.035:
	set(value):
		post_size = value
		_rebuild()
## Shared material from Assets/Materials (a wood).
@export var crate_material: Material:
	set(value):
		crate_material = value
		_rebuild()
@export var fallback_color: Color = Palette.STROKE


func _ready() -> void:
	_rebuild()


func _validate_property(property: Dictionary) -> void:
	# Generated from the exports above, so never stored in the scene file.
	if property.name == "mesh" or property.name == "material_override":
		property.usage = PROPERTY_USAGE_NONE


## Height of the top of its contents (a little under the rim).
func get_fill_height() -> float:
	return size.y - 0.05


## Inner floor area (X, Z) its contents fill.
func get_inner_size() -> Vector2:
	return Vector2(size.x - board_thickness * 2.0, size.z - board_thickness * 2.0)


func _rebuild() -> void:
	if not is_node_ready():
		return
	var surface_tool: SurfaceTool = WorldUVMesh.begin_surface()
	var half: Vector3 = size * 0.5
	WorldUVMesh.add_box(surface_tool, Vector3(0.0, board_thickness * 0.5 + 0.01, 0.0), Vector3(size.x - board_thickness, board_thickness, size.z - board_thickness))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var post_center: Vector3 = Vector3(corner.x * (half.x - post_size * 0.5), half.y, corner.y * (half.z - post_size * 0.5))
		WorldUVMesh.add_box(surface_tool, post_center, Vector3(post_size, size.y, post_size), [], true)
	var slat_height: float = (size.y - slat_gap * float(slat_count - 1)) / float(slat_count)
	for slat_index: int in slat_count:
		var slat_y: float = slat_height * 0.5 + float(slat_index) * (slat_height + slat_gap)
		for side: float in [-1.0, 1.0]:
			# Long sides run along X, short sides along Z (between the long ones).
			WorldUVMesh.add_box(surface_tool, Vector3(0.0, slat_y, side * (half.z - board_thickness * 0.5)), Vector3(size.x - post_size * 2.0 + 0.004, slat_height, board_thickness))
			WorldUVMesh.add_box(surface_tool, Vector3(side * (half.x - board_thickness * 0.5), slat_y, 0.0), Vector3(board_thickness, slat_height, size.z - post_size * 2.0 + 0.004))
	var crate_mesh: ArrayMesh = ArrayMesh.new()
	WorldUVMesh.commit_surface(surface_tool, crate_mesh, crate_material if crate_material != null else PlaceholderMesh3D.get_shared_material(fallback_color))
	mesh = crate_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

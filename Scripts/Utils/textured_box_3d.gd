## A box with a real material (wood, plaster, a door photo) textured at
## real-world scale: its UVs are in meters, so the material's uv1_scale sets
## the tile size whatever the box's size (see WorldUVMesh). The drop-in
## replacement for a PlaceholderMesh3D box once a surface has real art.
##
## Meshes are cached per size and shared, like PlaceholderMesh3D's. Without a
## material the box falls back to a matte Palette color.
##
## Dependencies: WorldUVMesh, PlaceholderMesh3D (fallback material), Palette
@tool
class_name TexturedBox3D
extends MeshInstance3D

static var _mesh_cache: Dictionary[String, ArrayMesh] = {}

## Width (X), height (Y) and depth (Z) in meters.
@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = value
		_rebuild()
## Shared material from Assets/Materials (its uv1_scale = 1 / tile size in meters).
@export var box_material: Material:
	set(value):
		box_material = value
		_rebuild()
## Used while no material is set.
@export var fallback_color: Color = Palette.SURFACE_RAISED:
	set(value):
		fallback_color = value
		_rebuild()
## Turns the texture a quarter on the sides (wood grain up a post, not across).
@export var is_grain_vertical: bool = false:
	set(value):
		is_grain_vertical = value
		_rebuild()


## Drops the shared meshes (called when the tree shuts down so nothing leaks at exit).
static func clear_cache() -> void:
	_mesh_cache.clear()


func _ready() -> void:
	_rebuild()


func _validate_property(property: Dictionary) -> void:
	# Generated from the exports above, so never stored in the scene file.
	if property.name == "mesh" or property.name == "material_override":
		property.usage = PROPERTY_USAGE_NONE


func _rebuild() -> void:
	if not is_node_ready():
		return
	mesh = _get_shared_mesh()
	material_override = box_material if box_material != null else PlaceholderMesh3D.get_shared_material(fallback_color)


func _get_shared_mesh() -> ArrayMesh:
	var cache_key: String = "%s|%s" % [size, is_grain_vertical]
	var cached_mesh: ArrayMesh = _mesh_cache.get(cache_key)
	if cached_mesh != null:
		return cached_mesh
	var surface_tool: SurfaceTool = WorldUVMesh.begin_surface()
	WorldUVMesh.add_box(surface_tool, Vector3.ZERO, size, [], is_grain_vertical)
	var new_mesh: ArrayMesh = ArrayMesh.new()
	WorldUVMesh.commit_surface(surface_tool, new_mesh, null)
	_mesh_cache[cache_key] = new_mesh
	return new_mesh

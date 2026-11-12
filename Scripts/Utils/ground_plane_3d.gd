## A flat patch of ground (lawn, path, yard) with a real material textured at
## real-world scale: UVs are in meters, so the material's uv1_scale sets the
## tile size whatever the patch's size (see WorldUVMesh). Optional soft
## darker patches, baked into vertex colors from a noise at build time, break
## up the visible repeat of the tile for free (the material must have
## vertex_color_use_as_albedo on). Builds itself in the editor too.
##
## The node's origin is the middle of the patch's top surface.
##
## Dependencies: WorldUVMesh, PlaceholderMesh3D (fallback material), Palette
@tool
class_name GroundPlane3D
extends MeshInstance3D

## Width (X) and depth (Z) in meters.
@export var size: Vector2 = Vector2(10.0, 10.0):
	set(value):
		size = value
		_rebuild()
## Shared material from Assets/Materials (its uv1_scale = 1 / tile size in meters).
@export var ground_material: Material:
	set(value):
		ground_material = value
		_rebuild()
## Used while no material is set.
@export var fallback_color: Color = Palette.WORLD:
	set(value):
		fallback_color = value
		_rebuild()

@export_group("Patches")
## How much darker the darkest patches get (0 = an even surface, no extra vertices).
@export_range(0.0, 0.8, 0.01) var patch_darkening: float = 0.0:
	set(value):
		patch_darkening = value
		_rebuild()
## Rough size of one light or dark patch, in meters.
@export_range(1.0, 60.0, 0.5) var patch_size_meters: float = 9.0:
	set(value):
		patch_size_meters = value
		_rebuild()
## Meters between the vertices that carry the patches.
@export_range(0.5, 20.0, 0.5) var patch_resolution_meters: float = 2.0:
	set(value):
		patch_resolution_meters = value
		_rebuild()
@export var patch_seed: int = 0:
	set(value):
		patch_seed = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _validate_property(property: Dictionary) -> void:
	# Generated from the exports above, so never stored in the scene file.
	if property.name == "mesh" or property.name == "material_override":
		property.usage = PROPERTY_USAGE_NONE


func _rebuild() -> void:
	if not is_node_ready():
		return
	material_override = ground_material if ground_material != null else PlaceholderMesh3D.get_shared_material(fallback_color)
	if patch_darkening <= 0.0:
		mesh = WorldUVMesh.create_plane(size)
		return
	var cells: Vector2i = Vector2i((size / patch_resolution_meters).ceil())
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = patch_seed
	noise.frequency = 1.0 / patch_size_meters
	noise.fractal_octaves = 2
	var origin: Vector2 = Vector2(global_position.x, global_position.z) if is_inside_tree() else Vector2.ZERO
	var shade: Callable = func(point: Vector2) -> Color:
		var darkness: float = clampf(noise.get_noise_2dv(origin + point) * 0.5 + 0.5, 0.0, 1.0)
		return Color.WHITE.darkened(darkness * patch_darkening)
	mesh = WorldUVMesh.create_plane(size, cells, shade)

## 3D twin of PlaceholderShape: a clean primitive (sphere, box, capsule,
## cylinder / cone) with a matte Palette color and optional glow. Good enough
## for a minimalist low-poly look; swap for imported meshes when final art
## arrives.
##
## Meshes and materials are cached and shared between every instance with the
## same settings, so hundreds of shapes cost a handful of resources — which
## matters on standalone VR headsets.
##
## Colors should come from Palette (see Docs/DESIGN.md).
##
## Dependencies: none
@tool
class_name PlaceholderMesh3D
extends MeshInstance3D

enum ShapeKind { SPHERE, BOX, CAPSULE, CYLINDER }

const RADIAL_SEGMENTS: int = 20
const RINGS: int = 10
const ROUGHNESS: float = 0.85

static var _mesh_cache: Dictionary[String, Mesh] = {}
static var _material_cache: Dictionary[String, StandardMaterial3D] = {}

@export var shape_kind: ShapeKind = ShapeKind.SPHERE:
	set(value):
		shape_kind = value
		_rebuild()
## Width (X diameter), height (Y) and depth (Z, boxes only) in meters.
@export var size: Vector3 = Vector3(0.5, 0.5, 0.5):
	set(value):
		size = value
		_rebuild()
@export var color: Color = Color(0.357, 0.486, 0.98):
	set(value):
		color = value
		_rebuild()

@export_group("Style")
## Emission strength; values above 1 bloom when the environment has glow.
@export_range(0.0, 4.0, 0.05) var glow: float = 0.0:
	set(value):
		glow = value
		_rebuild()
## Ignore lighting (beams, markers, UI-like shapes).
@export var unshaded: bool = false:
	set(value):
		unshaded = value
		_rebuild()
## Cylinders only: top radius as a fraction of the bottom radius (0 = cone).
@export_range(0.0, 1.0, 0.01) var top_scale: float = 1.0:
	set(value):
		top_scale = value
		_rebuild()


## Shared material for a color — use it for meshes that are not PlaceholderMesh3D.
static func get_shared_material(material_color: Color, glow_strength: float = 0.0, is_unshaded: bool = false) -> StandardMaterial3D:
	var cache_key: String = "%s|%.2f|%s" % [material_color.to_html(), glow_strength, is_unshaded]
	var cached_material: StandardMaterial3D = _material_cache.get(cache_key)
	if cached_material != null:
		return cached_material
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = material_color
	material.roughness = ROUGHNESS
	if is_unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if material_color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow_strength > 0.0:
		material.emission_enabled = true
		material.emission = material_color
		material.emission_energy_multiplier = glow_strength
	_material_cache[cache_key] = material
	return material


## Drops the shared resources (called when the tree shuts down so nothing leaks at exit).
static func clear_cache() -> void:
	_mesh_cache.clear()
	_material_cache.clear()


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
	material_override = get_shared_material(color, glow, unshaded)


func _get_shared_mesh() -> Mesh:
	var cache_key: String = "%d|%s|%.2f" % [shape_kind, size, top_scale]
	var cached_mesh: Mesh = _mesh_cache.get(cache_key)
	if cached_mesh != null:
		return cached_mesh
	var new_mesh: Mesh = _create_mesh()
	_mesh_cache[cache_key] = new_mesh
	return new_mesh


func _create_mesh() -> Mesh:
	match shape_kind:
		ShapeKind.BOX:
			var box: BoxMesh = BoxMesh.new()
			box.size = size
			return box
		ShapeKind.CAPSULE:
			var capsule: CapsuleMesh = CapsuleMesh.new()
			capsule.radius = size.x * 0.5
			capsule.height = maxf(size.y, size.x)
			capsule.radial_segments = RADIAL_SEGMENTS
			capsule.rings = RINGS / 2
			return capsule
		ShapeKind.CYLINDER:
			var cylinder: CylinderMesh = CylinderMesh.new()
			cylinder.bottom_radius = size.x * 0.5
			cylinder.top_radius = size.x * 0.5 * top_scale
			cylinder.height = size.y
			cylinder.radial_segments = RADIAL_SEGMENTS
			cylinder.rings = 1
			return cylinder
		_:
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = size.x * 0.5
			sphere.height = size.y
			sphere.radial_segments = RADIAL_SEGMENTS
			sphere.rings = RINGS
			return sphere

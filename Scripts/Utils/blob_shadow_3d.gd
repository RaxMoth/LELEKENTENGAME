## Soft round contact shadow under a 3D entity: one shared quad with a radial
## gradient. Grounds placeholder shapes without the cost of real-time shadows
## (mobile / standalone VR).
##
## Put it at the entity's feet; it lifts itself a little to avoid z-fighting.
##
## Dependencies: Palette
@tool
class_name BlobShadow3D
extends MeshInstance3D

const GROUND_CLEARANCE: float = 0.015
const SHADOW_OPACITY: float = 0.55
const TEXTURE_SIZE: int = 64

static var _shared_mesh: QuadMesh = null
static var _shared_material: StandardMaterial3D = null

## Diameter of the shadow in meters.
@export var diameter: float = 0.9:
	set(value):
		diameter = value
		_apply()


## Drops the shared resources (called when the tree shuts down so nothing leaks at exit).
static func clear_cache() -> void:
	_shared_mesh = null
	_shared_material = null


func _ready() -> void:
	_apply()


func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh" or property.name == "material_override":
		property.usage = PROPERTY_USAGE_NONE


func _apply() -> void:
	if not is_node_ready():
		return
	if _shared_mesh == null:
		_shared_mesh = QuadMesh.new()
		_shared_mesh.size = Vector2.ONE
		_shared_mesh.orientation = PlaneMesh.FACE_Y
		_shared_material = _create_material()
	mesh = _shared_mesh
	material_override = _shared_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scale = Vector3(diameter, 1.0, diameter)
	position.y = GROUND_CLEARANCE


static func _create_material() -> StandardMaterial3D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(Palette.BACKGROUND, SHADOW_OPACITY))
	gradient.set_color(1, Color(Palette.BACKGROUND, 0.0))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = TEXTURE_SIZE
	texture.height = TEXTURE_SIZE
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.disable_receive_shadows = true
	return material

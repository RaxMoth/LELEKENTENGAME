## Flashes every mesh below a Node3D white when its HealthComponent takes
## damage (3D twin of HitFlashComponent). Uses a shared overlay material, so
## the entity's own materials stay untouched and batchable.
##
## Dependencies: HealthComponent, Palette
class_name HitFlash3DComponent
extends Node

const FLASH_OPACITY: float = 0.7

static var _overlay_material: StandardMaterial3D = null

@export var flash_root: Node3D
@export var health_component: HealthComponent
@export var flash_seconds: float = 0.09

var _meshes: Array[GeometryInstance3D] = []
var _flash_remaining: float = 0.0


func _ready() -> void:
	set_process(false)
	if flash_root != null:
		_collect_meshes(flash_root)
	if health_component != null:
		health_component.damaged.connect(func(_damage_info: DamageInfo) -> void: flash())


func _process(delta: float) -> void:
	_flash_remaining -= delta
	if _flash_remaining <= 0.0:
		reset()


func flash() -> void:
	if _overlay_material == null:
		_overlay_material = StandardMaterial3D.new()
		_overlay_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay_material.albedo_color = Color(Palette.TEXT, FLASH_OPACITY)
	for mesh: GeometryInstance3D in _meshes:
		mesh.material_overlay = _overlay_material
	_flash_remaining = flash_seconds
	set_process(true)


func reset() -> void:
	for mesh: GeometryInstance3D in _meshes:
		mesh.material_overlay = null
	set_process(false)


func _collect_meshes(node: Node) -> void:
	var mesh: GeometryInstance3D = node as GeometryInstance3D
	if mesh != null and not mesh is BlobShadow3D:
		_meshes.append(mesh)
	for child: Node in node.get_children():
		_collect_meshes(child)

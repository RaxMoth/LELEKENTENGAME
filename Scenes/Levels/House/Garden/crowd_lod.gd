## Draws the far-away part of a police horde cheaply: officers farther than
## far_distance from the camera hide their jointed bodies (about 25 meshes,
## one draw call each) and show up here instead, as simple figures — a body
## and a head — in two MultiMeshes (two draw calls for the whole crowd).
## Close up (under near_distance) they get their real bodies back; the gap
## between the two distances keeps them from flickering at the line.
##
## Lives in FrontGarden.tscn next to the Yard it reads the officers from.
##
## Dependencies: Yard, Raider
class_name CrowdLod
extends Node3D

## Most officers drawn as simple figures at once.
const MAX_FIGURES: int = 128
## Body and head of the simple figure (meters).
const BODY_RADIUS: float = 0.24
const BODY_HEIGHT: float = 1.5
const HEAD_RADIUS: float = 0.14
const HEAD_HEIGHT: float = 1.66
## Walking bob of a far figure (meters) and its pace.
const BOB_HEIGHT: float = 0.05
const BOB_SPEED: float = 9.0

## The yard whose officers are drawn.
@export var yard: Yard
## Officers farther than this (meters) switch to the simple figure...
@export var far_distance: float = 24.0
## ...and back to their real body closer than this.
@export var near_distance: float = 20.0

var _bodies: MultiMesh = null
var _heads: MultiMesh = null
var _time: float = 0.0


func _ready() -> void:
	_bodies = _create_layer(_create_body_mesh())
	_heads = _create_layer(_create_head_mesh())


func _physics_process(delta: float) -> void:
	if yard == null:
		return
	_time += delta
	var camera: Camera3D = get_viewport().get_camera_3d()
	var count: int = 0
	for raider: Raider in yard.get_raiders():
		if not is_instance_valid(raider) or not raider.uses_crowd_figure():
			continue
		var is_alive: bool = raider.is_alive()
		var distance: float = camera.global_position.distance_to(raider.global_position) if camera != null else 0.0
		# Beyond the figure budget an officer keeps its real body (never invisible).
		var should_be_far: bool = is_alive and count < MAX_FIGURES and (distance > far_distance or (raider.is_far_drawn() and distance > near_distance))
		if should_be_far != raider.is_far_drawn():
			# A falling officer gets its body back for its last moment.
			raider.set_far_drawn(should_be_far)
		if not should_be_far:
			continue
		var colors: PackedColorArray = raider.get_crowd_colors()
		var bob: float = absf(sin(_time * BOB_SPEED + raider.get_instance_id() % 7)) * BOB_HEIGHT if raider.is_moving() else 0.0
		var placement: Transform3D = Transform3D(Basis(Vector3.UP, raider.rotation.y), raider.global_position + Vector3(0.0, bob, 0.0))
		_bodies.set_instance_transform(count, placement)
		_bodies.set_instance_color(count, colors[0])
		_heads.set_instance_transform(count, placement)
		_heads.set_instance_color(count, colors[1])
		count += 1
	_bodies.visible_instance_count = count
	_heads.visible_instance_count = count


## Officers drawn as simple figures right now (tests).
func get_figure_count() -> int:
	return _bodies.visible_instance_count if _bodies != null else 0


func _create_layer(mesh: Mesh) -> MultiMesh:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = MAX_FIGURES
	multimesh.visible_instance_count = 0
	var layer: MultiMeshInstance3D = MultiMeshInstance3D.new()
	layer.multimesh = multimesh
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The crowd spreads over the whole town: never culled as one box.
	layer.extra_cull_margin = 16384.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	layer.material_override = material
	add_child(layer)
	return multimesh


static func _create_body_mesh() -> Mesh:
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	capsule.radial_segments = 8
	capsule.rings = 2
	return _shifted(capsule, BODY_HEIGHT * 0.5)


static func _create_head_mesh() -> Mesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = HEAD_RADIUS
	sphere.height = HEAD_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	return _shifted(sphere, HEAD_HEIGHT)


## [param mesh] as an ArrayMesh lifted by [param height] (figures stand on their origin).
static func _shifted(mesh: PrimitiveMesh, height: float) -> ArrayMesh:
	var arrays: Array = mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex_index: int in vertices.size():
		vertices[vertex_index].y += height
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var shifted: ArrayMesh = ArrayMesh.new()
	shifted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return shifted

## Many copies of one cheap mesh (impostor trees, weeds, litter) in a single
## draw call: a MultiMesh built from a list of placements, so dressing a yard
## is editing a few numbers, not placing dozens of nodes. Each placement is
## (x, z, scale, yaw in degrees) on the node's ground plane. Builds itself in
## the editor too. Shadows are off (no real-time shadows on standalone).
##
## Dependencies: none
@tool
class_name PropScatter3D
extends MultiMeshInstance3D

## The mesh every copy shows (e.g. an impostor from Tools/bake_impostor.gd).
@export var scatter_mesh: Mesh:
	set(value):
		scatter_mesh = value
		_rebuild()
## Material for every copy (the mesh's own surface material when null).
@export var scatter_material: Material:
	set(value):
		scatter_material = value
		_rebuild()
## One entry per copy: x, z (meters, local), uniform scale, yaw (degrees).
@export var placements: Array[Vector4] = []:
	set(value):
		placements = value
		_rebuild()


## Local transform of one copy.
static func get_placement_transform(placement: Vector4) -> Transform3D:
	var placement_basis: Basis = Basis(Vector3.UP, deg_to_rad(placement.w)).scaled(Vector3.ONE * placement.z)
	return Transform3D(placement_basis, Vector3(placement.x, 0.0, placement.y))


func _ready() -> void:
	_rebuild()


func _validate_property(property: Dictionary) -> void:
	# Generated from the exports above, so never stored in the scene file.
	if property.name == "multimesh" or property.name == "material_override":
		property.usage = PROPERTY_USAGE_NONE


func _rebuild() -> void:
	if not is_node_ready():
		return
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = scatter_material
	var copies: MultiMesh = MultiMesh.new()
	copies.transform_format = MultiMesh.TRANSFORM_3D
	copies.mesh = scatter_mesh
	copies.instance_count = placements.size()
	for placement_index: int in placements.size():
		copies.set_instance_transform(placement_index, get_placement_transform(placements[placement_index]))
	multimesh = copies

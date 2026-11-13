@tool
## An open burlap sack as one mesh (one draw call): a lumpy, bulging body
## with its top rolled down over the outside, so the cloth's inside shows
## around whatever it holds. The bottom sits on the node's origin. UVs are
## in meters (like TexturedBox3D), so the shared burlap material tiles at
## real scale.
##
##   sack.radius = 0.2
##   sack.height = 0.48
##   sack.get_fill_height()   # where its contents heap up
##
## Dependencies: PlaceholderMesh3D (fallback material), Palette
class_name SackMesh3D
extends MeshInstance3D

## Steps around the sack.
const SEGMENTS: int = 24

## Radius at the bottom (the body bulges a little past it).
@export var radius: float = 0.2:
	set(value):
		radius = value
		_rebuild()
@export var height: float = 0.48:
	set(value):
		height = value
		_rebuild()
## How lumpy the cloth is (0 = a smooth drum).
@export_range(0.0, 0.2, 0.01) var lumpiness: float = 0.06:
	set(value):
		lumpiness = value
		_rebuild()
## Shapes the lumps, so two sacks side by side don't look the same.
@export var lump_seed: int = 0:
	set(value):
		lump_seed = value
		_rebuild()
## Shared material from Assets/Materials (burlap.tres).
@export var sack_material: Material:
	set(value):
		sack_material = value
		_rebuild()
@export var fallback_color: Color = Palette.STROKE


func _ready() -> void:
	_rebuild()


func _validate_property(property: Dictionary) -> void:
	# Generated from the exports above, so never stored in the scene file.
	if property.name == "mesh" or property.name == "material_override":
		property.usage = PROPERTY_USAGE_NONE


## Height of the top of its contents (a little under the rolled rim).
func get_fill_height() -> float:
	return height - 0.07


func _rebuild() -> void:
	if not is_node_ready():
		return
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The body, from the middle of the bottom up to under the fold.
	_add_lathe(surface_tool, PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.8, 0.0), Vector2(0.97, 0.03), Vector2(1.04, 0.22),
		Vector2(1.05, 0.5), Vector2(1.0, 0.75), Vector2(0.96, 0.9)]))
	# The rolled-down top: up the outside of the fold, over, down the inside.
	_add_lathe(surface_tool, PackedVector2Array([
		Vector2(1.05, 0.83), Vector2(1.1, 0.88), Vector2(1.1, 0.95), Vector2(1.04, 1.0),
		Vector2(0.96, 0.99), Vector2(0.92, 0.93), Vector2(0.9, 0.78)]))
	var sack_mesh: ArrayMesh = surface_tool.commit()
	sack_mesh.surface_set_material(0, sack_material if sack_material != null else PlaceholderMesh3D.get_shared_material(fallback_color))
	mesh = sack_mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Turns a profile (x = share of radius, y = share of height) around the Y
## axis. Lumps grow toward the middle of the body and fade at the bottom.
func _add_lathe(surface_tool: SurfaceTool, profile: PackedVector2Array) -> void:
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	var ring_v: PackedFloat32Array = PackedFloat32Array()
	var travelled: float = 0.0
	for point_index: int in profile.size():
		var point: Vector2 = Vector2(profile[point_index].x * radius, profile[point_index].y * height)
		if point_index > 0:
			var previous: Vector2 = Vector2(profile[point_index - 1].x * radius, profile[point_index - 1].y * height)
			travelled += point.distance_to(previous)
		ring_v.append(travelled)
		var before: Vector2 = profile[maxi(0, point_index - 1)] * Vector2(radius, height)
		var after: Vector2 = profile[mini(profile.size() - 1, point_index + 1)] * Vector2(radius, height)
		var tangent: Vector2 = (after - before).normalized()
		# Right of the way along the profile: outward on the body and the
		# fold's outside, toward the middle on its inside (seen from above).
		var outward: Vector2 = Vector2(tangent.y, -tangent.x)
		var positions: PackedVector3Array = PackedVector3Array()
		var normals: PackedVector3Array = PackedVector3Array()
		for segment_index: int in SEGMENTS + 1:
			var angle: float = TAU * float(segment_index) / float(SEGMENTS)
			var lump: float = 1.0 + lumpiness * _lump(angle, profile[point_index].y) * clampf(profile[point_index].y * 4.0, 0.0, 1.0)
			var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
			positions.append(direction * point.x * lump + Vector3(0.0, point.y, 0.0))
			normals.append((direction * outward.x + Vector3(0.0, outward.y, 0.0)).normalized())
		rings.append(positions)
		ring_normals.append(normals)
	var circumference: float = TAU * radius
	for ring_index: int in rings.size() - 1:
		for segment_index: int in SEGMENTS:
			var corners: Array[Vector2i] = [Vector2i(ring_index, segment_index), Vector2i(ring_index, segment_index + 1), Vector2i(ring_index + 1, segment_index + 1), Vector2i(ring_index + 1, segment_index)]
			for corner_index: int in [0, 1, 2, 0, 2, 3]:
				var corner: Vector2i = corners[corner_index]
				surface_tool.set_normal(ring_normals[corner.x][corner.y])
				surface_tool.set_uv(Vector2(circumference * float(corner.y) / float(SEGMENTS), ring_v[corner.x]))
				surface_tool.add_vertex(rings[corner.x][corner.y])


## A smooth, repeatable bump pattern around the sack (-1..1).
func _lump(angle: float, height_share: float) -> float:
	var offset: float = float(lump_seed) * 1.7
	return sin(angle * 3.0 + offset) * 0.6 + sin(angle * 5.0 + offset * 2.3 + height_share * 6.0) * 0.4

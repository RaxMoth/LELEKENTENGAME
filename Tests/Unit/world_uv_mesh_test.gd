## Unit tests for WorldUVMesh (box faces and ground planes with UVs in meters).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite

const TOLERANCE: float = 0.0001


## Every triangle of a surface, as [a, b, c] vertex positions.
func _get_triangles(mesh: ArrayMesh, surface_index: int) -> Array[PackedVector3Array]:
	var arrays: Array = mesh.surface_get_arrays(surface_index)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var triangles: Array[PackedVector3Array] = []
	for first: int in range(0, indices.size(), 3):
		triangles.append(PackedVector3Array([vertices[indices[first]], vertices[indices[first + 1]], vertices[indices[first + 2]]]))
	return triangles


func _get_uv_extent(mesh: ArrayMesh, surface_index: int, uv_array: int) -> Rect2:
	var uvs: PackedVector2Array = mesh.surface_get_arrays(surface_index)[uv_array]
	var extent: Rect2 = Rect2(uvs[0], Vector2.ZERO)
	for uv: Vector2 in uvs:
		extent = extent.expand(uv)
	return extent


func test_face_axes_are_orthogonal_and_right_handed() -> void:
	for face: WorldUVMesh.Face in WorldUVMesh.ALL_FACES:
		var normal: Vector3 = WorldUVMesh.get_face_normal(face)
		var right: Vector3 = WorldUVMesh.get_face_right(face)
		var up: Vector3 = WorldUVMesh.get_face_up(face)
		assert_float(normal.dot(right)).is_equal_approx(0.0, TOLERANCE)
		assert_float(normal.dot(up)).is_equal_approx(0.0, TOLERANCE)
		# Seen from in front (looking along -normal), right x up points back at the viewer.
		assert_vector(right.cross(up)).is_equal_approx(normal, Vector3.ONE * TOLERANCE)


func test_face_center_sits_on_the_box_surface() -> void:
	var center: Vector3 = Vector3(1.0, 2.0, 3.0)
	var box_size: Vector3 = Vector3(4.0, 2.0, 0.2)
	assert_vector(WorldUVMesh.get_face_center(center, box_size, WorldUVMesh.Face.NEGATIVE_Z)).is_equal_approx(Vector3(1.0, 2.0, 2.9), Vector3.ONE * TOLERANCE)
	assert_vector(WorldUVMesh.get_face_center(center, box_size, WorldUVMesh.Face.POSITIVE_X)).is_equal_approx(Vector3(3.0, 2.0, 3.0), Vector3.ONE * TOLERANCE)
	assert_vector(WorldUVMesh.get_face_center(center, box_size, WorldUVMesh.Face.POSITIVE_Y)).is_equal_approx(Vector3(1.0, 3.0, 3.0), Vector3.ONE * TOLERANCE)


func test_box_face_uvs_are_in_meters() -> void:
	var surface_tool: SurfaceTool = WorldUVMesh.begin_surface()
	WorldUVMesh.add_box_face(surface_tool, Vector3(0.0, 1.3, 0.0), Vector3(3.5, 2.6, 0.16), WorldUVMesh.Face.POSITIVE_Z)
	var mesh: ArrayMesh = ArrayMesh.new()
	WorldUVMesh.commit_surface(surface_tool, mesh, null)
	var extent: Rect2 = _get_uv_extent(mesh, 0, Mesh.ARRAY_TEX_UV)
	assert_vector(extent.size).is_equal_approx(Vector2(3.5, 2.6), Vector2.ONE * TOLERANCE)
	# V runs down: the top edge (y = 2.6) has the smallest V.
	assert_float(extent.position.y).is_equal_approx(-2.6, TOLERANCE)


func test_turned_box_face_swaps_its_uv_axes() -> void:
	var surface_tool: SurfaceTool = WorldUVMesh.begin_surface()
	WorldUVMesh.add_box_face(surface_tool, Vector3(0.0, 1.0, 0.0), Vector3(0.2, 2.0, 0.2), WorldUVMesh.Face.NEGATIVE_X, true)
	var mesh: ArrayMesh = ArrayMesh.new()
	WorldUVMesh.commit_surface(surface_tool, mesh, null)
	# A 0.2 m wide, 2 m tall post side: U now runs up the post.
	assert_vector(_get_uv_extent(mesh, 0, Mesh.ARRAY_TEX_UV).size).is_equal_approx(Vector2(2.0, 0.2), Vector2.ONE * TOLERANCE)


func test_box_faces_wind_clockwise_toward_their_normal() -> void:
	var surface_tool: SurfaceTool = WorldUVMesh.begin_surface()
	WorldUVMesh.add_box(surface_tool, Vector3.ZERO, Vector3(2.0, 1.0, 0.5))
	var mesh: ArrayMesh = ArrayMesh.new()
	WorldUVMesh.commit_surface(surface_tool, mesh, null)
	var triangles: Array[PackedVector3Array] = _get_triangles(mesh, 0)
	assert_int(triangles.size()).is_equal(12)
	for triangle: PackedVector3Array in triangles:
		var middle: Vector3 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
		var winding_normal: Vector3 = (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])
		# Godot's front faces are clockwise, so the winding normal points into the box.
		assert_float(winding_normal.dot(middle)).is_less(0.0)


func test_skipped_faces_are_left_out() -> void:
	var surface_tool: SurfaceTool = WorldUVMesh.begin_surface()
	WorldUVMesh.add_box(surface_tool, Vector3.ZERO, Vector3.ONE, [WorldUVMesh.Face.NEGATIVE_Y, WorldUVMesh.Face.POSITIVE_Y])
	var mesh: ArrayMesh = ArrayMesh.new()
	WorldUVMesh.commit_surface(surface_tool, mesh, null)
	assert_int(_get_triangles(mesh, 0).size()).is_equal(8)


func test_polygon_matches_the_box_face_it_covers() -> void:
	var box_tool: SurfaceTool = WorldUVMesh.begin_surface()
	WorldUVMesh.add_box_face(box_tool, Vector3(1.0, 1.0, 0.0), Vector3(2.0, 2.0, 0.0), WorldUVMesh.Face.POSITIVE_Z)
	var polygon_tool: SurfaceTool = WorldUVMesh.begin_surface()
	# Clockwise seen from +Z: top left, top right, bottom right, bottom left.
	WorldUVMesh.add_polygon(polygon_tool, PackedVector3Array([Vector3(0.0, 2.0, 0.0), Vector3(2.0, 2.0, 0.0), Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)]))
	var box_mesh: ArrayMesh = ArrayMesh.new()
	WorldUVMesh.commit_surface(box_tool, box_mesh, null)
	var polygon_mesh: ArrayMesh = ArrayMesh.new()
	WorldUVMesh.commit_surface(polygon_tool, polygon_mesh, null)
	assert_vector(_get_uv_extent(polygon_mesh, 0, Mesh.ARRAY_TEX_UV).position).is_equal_approx(_get_uv_extent(box_mesh, 0, Mesh.ARRAY_TEX_UV).position, Vector2.ONE * TOLERANCE)
	var normals: PackedVector3Array = polygon_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_vector(normals[0]).is_equal_approx(Vector3.BACK, Vector3.ONE * TOLERANCE)


func test_sloped_polygon_uvs_run_along_the_slope() -> void:
	var surface_tool: SurfaceTool = WorldUVMesh.begin_surface()
	# A roof plane rising 3 m over 4 m toward -Z (slope length 5 m), 6 m wide, facing up and +Z.
	WorldUVMesh.add_polygon(surface_tool, PackedVector3Array([Vector3(0.0, 3.0, 0.0), Vector3(6.0, 3.0, 0.0), Vector3(6.0, 0.0, 4.0), Vector3(0.0, 0.0, 4.0)]))
	var mesh: ArrayMesh = ArrayMesh.new()
	WorldUVMesh.commit_surface(surface_tool, mesh, null)
	assert_vector(_get_uv_extent(mesh, 0, Mesh.ARRAY_TEX_UV).size).is_equal_approx(Vector2(6.0, 5.0), Vector2.ONE * TOLERANCE)
	var normal: Vector3 = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
	assert_float(normal.y).is_greater(0.0)
	assert_float(normal.z).is_greater(0.0)
	assert_int(_get_triangles(mesh, 0).size()).is_equal(2)


func test_empty_surface_adds_nothing() -> void:
	var mesh: ArrayMesh = ArrayMesh.new()
	WorldUVMesh.commit_surface(WorldUVMesh.begin_surface(), mesh, null)
	assert_int(mesh.get_surface_count()).is_equal(0)


func test_plane_spans_its_size_with_meter_uvs_and_unit_uv2() -> void:
	var mesh: ArrayMesh = WorldUVMesh.create_plane(Vector2(4.2, 7.8), Vector2i(3, 6))
	assert_vector(mesh.get_aabb().size).is_equal_approx(Vector3(4.2, 0.0, 7.8), Vector3.ONE * TOLERANCE)
	assert_vector(_get_uv_extent(mesh, 0, Mesh.ARRAY_TEX_UV).size).is_equal_approx(Vector2(4.2, 7.8), Vector2.ONE * TOLERANCE)
	assert_vector(_get_uv_extent(mesh, 0, Mesh.ARRAY_TEX_UV2).size).is_equal_approx(Vector2.ONE, Vector2.ONE * TOLERANCE)
	assert_int(_get_triangles(mesh, 0).size()).is_equal(3 * 6 * 2)
	for triangle: PackedVector3Array in _get_triangles(mesh, 0):
		assert_float((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).y).is_less(0.0)


func test_plane_shade_becomes_vertex_colors() -> void:
	var shade: Callable = func(point: Vector2) -> Color: return Color.BLACK if point.x < 0.0 else Color.WHITE
	var mesh: ArrayMesh = WorldUVMesh.create_plane(Vector2(2.0, 2.0), Vector2i(2, 1), shade)
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_int(colors.size()).is_equal(6)
	assert_bool(colors.has(Color.BLACK)).is_true()
	assert_bool(colors.has(Color.WHITE)).is_true()

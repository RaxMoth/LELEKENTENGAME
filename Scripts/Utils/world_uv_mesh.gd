## Geometry for surfaces textured at real-world scale: box faces and ground
## planes whose UVs are in meters. A material's uv1_scale (1 / tile size in
## meters) then tiles the same on a 1 m wall piece and a 90 m lawn, without
## the stretched atlas of a BoxMesh and without triplanar mapping (too
## expensive on a standalone headset). Every face gets a normal and tangents,
## so normal maps work.
##
##   var walls: SurfaceTool = WorldUVMesh.begin_surface()
##   WorldUVMesh.add_box_face(walls, center, size, WorldUVMesh.Face.NEGATIVE_Z)
##   var mesh: ArrayMesh = ArrayMesh.new()
##   WorldUVMesh.commit_surface(walls, mesh, wall_material)
##
## Texture space on every face: U runs to the right and V runs down as seen
## from in front of the face, so photos stay upright and unmirrored, and two
## coplanar faces sample the same texels (overlaps cannot flicker).
##
## Dependencies: none
class_name WorldUVMesh
extends RefCounted

enum Face { POSITIVE_X, NEGATIVE_X, POSITIVE_Y, NEGATIVE_Y, POSITIVE_Z, NEGATIVE_Z }

const ALL_FACES: Array[Face] = [Face.POSITIVE_X, Face.NEGATIVE_X, Face.POSITIVE_Y, Face.NEGATIVE_Y, Face.POSITIVE_Z, Face.NEGATIVE_Z]


## Outward normal of a box face.
static func get_face_normal(face: Face) -> Vector3:
	match face:
		Face.POSITIVE_X:
			return Vector3.RIGHT
		Face.NEGATIVE_X:
			return Vector3.LEFT
		Face.POSITIVE_Y:
			return Vector3.UP
		Face.NEGATIVE_Y:
			return Vector3.DOWN
		Face.POSITIVE_Z:
			return Vector3.BACK
		_:
			return Vector3.FORWARD


## Direction of +U on a face: the viewer's right when looking at it.
static func get_face_right(face: Face) -> Vector3:
	match face:
		Face.POSITIVE_X:
			return Vector3.FORWARD
		Face.NEGATIVE_X:
			return Vector3.BACK
		Face.POSITIVE_Z:
			return Vector3.RIGHT
		Face.NEGATIVE_Z:
			return Vector3.LEFT
		_:
			return Vector3.RIGHT


## Direction of -V on a face: the viewer's up when looking at it (floors
## and ceilings: toward -Z / +Z, so ground textures line up with walls).
static func get_face_up(face: Face) -> Vector3:
	match face:
		Face.POSITIVE_Y:
			return Vector3.FORWARD
		Face.NEGATIVE_Y:
			return Vector3.BACK
		_:
			return Vector3.UP


## Middle of a face of the box [param center] / [param box_size].
static func get_face_center(center: Vector3, box_size: Vector3, face: Face) -> Vector3:
	return center + get_face_normal(face) * (box_size * 0.5).dot(get_face_normal(face).abs())


## Texture coordinate in meters of [param point] on [param face].
static func get_uv(point: Vector3, face: Face) -> Vector2:
	return Vector2(point.dot(get_face_right(face)), -point.dot(get_face_up(face)))


## A triangle-list SurfaceTool ready for add_box_face().
static func begin_surface() -> SurfaceTool:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface_tool


## Adds one face (two clockwise triangles) of the box [param center] /
## [param box_size] with UVs in meters. [param is_turned] gives the texture a
## quarter turn on the sides (not the top and bottom), e.g. so wood grain runs
## up a post instead of across it.
static func add_box_face(surface_tool: SurfaceTool, center: Vector3, box_size: Vector3, face: Face, is_turned: bool = false) -> void:
	var normal: Vector3 = get_face_normal(face)
	var right: Vector3 = get_face_right(face)
	var up: Vector3 = get_face_up(face)
	var face_center: Vector3 = get_face_center(center, box_size, face)
	var half_right: Vector3 = right * (box_size * 0.5).dot(right.abs())
	var half_up: Vector3 = up * (box_size * 0.5).dot(up.abs())
	var top_left: Vector3 = face_center - half_right + half_up
	var top_right: Vector3 = face_center + half_right + half_up
	var bottom_right: Vector3 = face_center + half_right - half_up
	var bottom_left: Vector3 = face_center - half_right - half_up
	var is_side: bool = face != Face.POSITIVE_Y and face != Face.NEGATIVE_Y
	for corner: Vector3 in [top_left, top_right, bottom_right, top_left, bottom_right, bottom_left]:
		var uv: Vector2 = get_uv(corner, face)
		surface_tool.set_normal(normal)
		surface_tool.set_uv(Vector2(uv.y, -uv.x) if is_turned and is_side else uv)
		surface_tool.add_vertex(corner)


## Adds a flat convex polygon (a roof plane, a gable) given clockwise as seen
## from its front. UVs in meters: U runs horizontally to the viewer's right,
## V down the slope (on a vertical polygon: straight down), like box faces.
static func add_polygon(surface_tool: SurfaceTool, points: PackedVector3Array) -> void:
	if points.size() < 3:
		return
	var normal: Vector3 = (points[2] - points[0]).cross(points[1] - points[0]).normalized()
	var right: Vector3 = Vector3.UP.cross(normal).normalized() if absf(normal.y) < 0.999 else Vector3.RIGHT
	var up: Vector3 = normal.cross(right)
	for fan_index: int in range(1, points.size() - 1):
		for corner: Vector3 in [points[0], points[fan_index], points[fan_index + 1]]:
			surface_tool.set_normal(normal)
			surface_tool.set_uv(Vector2(corner.dot(right), -corner.dot(up)))
			surface_tool.add_vertex(corner)


## Adds every face of a box except those in [param skipped_faces]
## ([param is_turned]: see add_box_face()).
static func add_box(surface_tool: SurfaceTool, center: Vector3, box_size: Vector3, skipped_faces: Array[Face] = [], is_turned: bool = false) -> void:
	for face: Face in ALL_FACES:
		if not skipped_faces.has(face):
			add_box_face(surface_tool, center, box_size, face, is_turned)


## Indexes the surface, adds tangents and appends it to [param mesh] with
## [param material]. Does nothing for an empty surface.
static func commit_surface(surface_tool: SurfaceTool, mesh: ArrayMesh, material: Material) -> void:
	# An empty surface has no vertex array at all (null), not an empty one.
	var vertices: Variant = surface_tool.commit_to_arrays()[Mesh.ARRAY_VERTEX]
	if vertices == null or (vertices as PackedVector3Array).is_empty():
		return
	surface_tool.index()
	surface_tool.generate_tangents()
	surface_tool.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


## A horizontal plane facing up, centered on the origin, split into
## [param cells] quads. UV is in meters (U along +X, V along +Z); UV2 runs 0..1
## across the whole plane (for overlays such as a lane checker). When
## [param shade] is valid it is called with each vertex's (x, z) and its
## Color becomes the vertex color (patches that break up tiling).
## [param holes] (x, z rects around the plane's center) are left open, the
## rest is covered exactly (a stairwell into a cellar under a lawn).
static func create_plane(plane_size: Vector2, cells: Vector2i = Vector2i.ONE, shade: Callable = Callable(), holes: Array[Rect2] = []) -> ArrayMesh:
	var cell_count: Vector2i = cells.max(Vector2i.ONE)
	var cell_size: Vector2 = plane_size / Vector2(cell_count)
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertex_count: int = 0
	for piece: Rect2 in subtract_rects(Rect2(-plane_size * 0.5, plane_size), holes):
		var piece_cells: Vector2i = Vector2i((piece.size / cell_size).round()).max(Vector2i.ONE)
		for row: int in piece_cells.y + 1:
			for column: int in piece_cells.x + 1:
				var point: Vector2 = piece.position + piece.size * Vector2(column, row) / Vector2(piece_cells)
				surface_tool.set_normal(Vector3.UP)
				surface_tool.set_uv(point)
				surface_tool.set_uv2(point / plane_size + Vector2(0.5, 0.5))
				if shade.is_valid():
					surface_tool.set_color(shade.call(point))
				surface_tool.add_vertex(Vector3(point.x, 0.0, point.y))
		var row_stride: int = piece_cells.x + 1
		for row: int in piece_cells.y:
			for column: int in piece_cells.x:
				var top_left: int = vertex_count + row * row_stride + column
				var top_right: int = top_left + 1
				var bottom_left: int = top_left + row_stride
				var bottom_right: int = bottom_left + 1
				# Clockwise seen from above (Godot's front-face winding).
				for index: int in [top_left, top_right, bottom_right, top_left, bottom_right, bottom_left]:
					surface_tool.add_index(index)
		vertex_count += row_stride * (piece_cells.y + 1)
	surface_tool.generate_tangents()
	return surface_tool.commit()


## [param base] with every rect in [param cuts] cut out, as rects that
## cover the rest exactly (a floor around a stairwell).
static func subtract_rects(base: Rect2, cuts: Array[Rect2]) -> Array[Rect2]:
	var pieces: Array[Rect2] = [base]
	for cut: Rect2 in cuts:
		var remaining: Array[Rect2] = []
		for piece: Rect2 in pieces:
			remaining.append_array(subtract_rect(piece, cut))
		pieces = remaining
	return pieces


## [param piece] minus [param cut]: up to four rects (the strips before and
## after the cut along Z, then its sides along X), or the piece itself when
## they don't overlap.
static func subtract_rect(piece: Rect2, cut: Rect2) -> Array[Rect2]:
	var overlap: Rect2 = piece.intersection(cut)
	if not overlap.has_area():
		return [piece]
	var candidates: Array[Rect2] = [
		Rect2(piece.position.x, piece.position.y, piece.size.x, overlap.position.y - piece.position.y),
		Rect2(piece.position.x, overlap.end.y, piece.size.x, piece.end.y - overlap.end.y),
		Rect2(piece.position.x, overlap.position.y, overlap.position.x - piece.position.x, overlap.size.y),
		Rect2(overlap.end.x, overlap.position.y, piece.end.x - overlap.end.x, overlap.size.y),
	]
	var pieces: Array[Rect2] = []
	for candidate: Rect2 in candidates:
		if candidate.has_area():
			pieces.append(candidate)
	return pieces

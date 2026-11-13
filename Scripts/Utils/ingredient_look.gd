## Builds the lab's ingredients so they look like the real thing, each as
## one mesh with vertex colors (one draw call, one shared material):
## a mushroom on its stem, a gnarled root, a bundle of leaves, crystal
## chunks, a pile of ground powder on a tin dish — and the heap a sack or a
## crate is filled with (straw, dirt or a mound of the same, pieces on top).
##
##   body.mesh = IngredientLook.get_piece_mesh(data.piece_style, data.color, false)
##   contents.mesh = IngredientLook.build_heap_mesh(data.piece_style, data.color, Vector2(0.4, 0.3), false, 3)
##
## Pure geometry (no autoloads), cached per look.
##
## Dependencies: IngredientData (PieceStyle)
class_name IngredientLook
extends RefCounted

const STEM_COLOR: Color = Color(0.89, 0.85, 0.76)
const GILL_COLOR: Color = Color(0.62, 0.55, 0.46)
const TIN_COLOR: Color = Color(0.55, 0.56, 0.58)
const TWINE_COLOR: Color = Color(0.55, 0.42, 0.26)
const STRAW_COLOR: Color = Color(0.72, 0.62, 0.38)
const DIRT_COLOR: Color = Color(0.3, 0.22, 0.15)
## Height of a heap's mound above the fill line.
const MOUND_HEIGHT: float = 0.06
## How far a piece reaches from its middle (kept that far from the walls).
const PIECE_REACH: float = 0.09
## Low-poly primitives: pieces are small.
const RADIAL_SEGMENTS: int = 10
const RINGS: int = 5

static var _piece_cache: Dictionary[String, ArrayMesh] = {}
static var _material: StandardMaterial3D = null


## The one material every ingredient mesh shares (colors are in the vertices).
static func get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.8
	return _material


## One piece, standing on its origin about 0.1 m tall: raw in its
## [param style], or (when [param is_powder]) ground to a pile on a dish.
static func get_piece_mesh(style: IngredientData.PieceStyle, color: Color, is_powder: bool) -> ArrayMesh:
	var cache_key: String = "%d|%s|%s" % [style, color.to_html(), is_powder]
	var cached: ArrayMesh = _piece_cache.get(cache_key)
	if cached != null:
		return cached
	var builder: MeshBuilder = MeshBuilder.new()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 1
	if is_powder:
		_add_powder(builder, color)
	else:
		_add_piece(builder, style, color, Transform3D.IDENTITY, random)
	var piece_mesh: ArrayMesh = builder.commit(get_material())
	_piece_cache[cache_key] = piece_mesh
	return piece_mesh


## What a sack or crate holds, its origin on the fill line: a mound (straw
## under mushrooms, dirt under roots, more of the same otherwise) filling
## [param area] (X, Z; round when [param is_round]) and pieces heaped on it.
## [param seed] varies the heap.
static func build_heap_mesh(style: IngredientData.PieceStyle, color: Color, area: Vector2, is_round: bool, seed: int) -> ArrayMesh:
	var builder: MeshBuilder = MeshBuilder.new()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed
	var mound: SphereMesh = _sphere(0.5, 1.0)
	builder.add(mound, Transform3D(Basis.from_scale(Vector3(area.x, MOUND_HEIGHT * 2.0, area.y)), Vector3.ZERO), _get_mound_color(style, color))
	var piece_count: int = 14 if style == IngredientData.PieceStyle.CRYSTAL else (7 if is_round else 10)
	for piece_index: int in piece_count:
		var spot: Vector2 = _random_spot(random, area * 0.5 - Vector2.ONE * PIECE_REACH, is_round)
		var normalized: Vector2 = Vector2(spot.x / (area.x * 0.5), spot.y / (area.y * 0.5))
		var surface: float = MOUND_HEIGHT * sqrt(maxf(0.0, 1.0 - normalized.length_squared())) - 0.012
		var tilt: Basis = Basis(Vector3.RIGHT, random.randf_range(-0.35, 0.35)) * Basis(Vector3.FORWARD, random.randf_range(-0.35, 0.35))
		var turn: Basis = Basis(Vector3.UP, random.randf_range(0.0, TAU))
		var piece_scale: float = random.randf_range(0.85, 1.15)
		var placement: Transform3D = Transform3D((turn * tilt).scaled(Vector3.ONE * piece_scale), Vector3(spot.x, surface, spot.y))
		_add_piece(builder, style, color.darkened(random.randf_range(0.0, 0.12)), placement, random)
	return builder.commit(get_material())


## Drops cached meshes (tests, or after the ingredients changed).
static func clear_cache() -> void:
	_piece_cache.clear()
	_material = null


static func _add_piece(builder: MeshBuilder, style: IngredientData.PieceStyle, color: Color, placement: Transform3D, random: RandomNumberGenerator) -> void:
	match style:
		IngredientData.PieceStyle.MUSHROOM:
			builder.add(_cylinder(0.016, 0.02, 0.06), placement * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0)), STEM_COLOR)
			builder.add(_cylinder(0.047, 0.047, 0.004), placement * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.06, 0.0)), GILL_COLOR)
			builder.add(_sphere(0.05, 0.05), placement * Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 1.0)), Vector3(0.0, 0.062, 0.0)), color)
		IngredientData.PieceStyle.ROOT:
			builder.add(_capsule(0.022, 0.17), placement * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.0, 0.022, 0.0)), color)
			builder.add(_capsule(0.011, 0.08), placement * Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.FORWARD, PI * 0.42), Vector3(0.035, 0.024, 0.02)), color.darkened(0.2))
			builder.add(_capsule(0.009, 0.06), placement * Transform3D(Basis(Vector3.UP, -0.9) * Basis(Vector3.FORWARD, PI * 0.45), Vector3(-0.03, 0.022, -0.018)), color.darkened(0.15))
		IngredientData.PieceStyle.LEAF:
			for leaf_index: int in 3:
				var fan: float = (float(leaf_index) - 1.0) * 0.45
				var leaf_basis: Basis = Basis(Vector3.UP, fan) * Basis(Vector3.RIGHT, 0.12) * Basis.from_scale(Vector3(1.0, 1.0, 0.45))
				var leaf_center: Vector3 = Basis(Vector3.UP, fan) * Vector3(0.045, 0.0, 0.0) + Vector3(-0.04, 0.008 + leaf_index * 0.006, 0.0)
				builder.add(_sphere(0.065, 0.012), placement * Transform3D(leaf_basis, leaf_center), color.darkened(float(leaf_index) * 0.08))
			builder.add(_cylinder(0.011, 0.011, 0.022), placement * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.045, 0.012, 0.0)), TWINE_COLOR)
		_:
			for chunk_index: int in 8:
				var chunk_size: float = random.randf_range(0.014, 0.03)
				var offset: Vector2 = Vector2(random.randf_range(-0.04, 0.04), random.randf_range(-0.04, 0.04))
				var chunk_basis: Basis = Basis.from_euler(Vector3(random.randf_range(0.0, TAU), random.randf_range(0.0, TAU), random.randf_range(0.0, TAU)))
				builder.add(_box(chunk_size), placement * Transform3D(chunk_basis, Vector3(offset.x, chunk_size * 0.5, offset.y)), color.lerp(Color.WHITE, random.randf_range(0.0, 0.25)).darkened(random.randf_range(0.0, 0.1)))


static func _add_powder(builder: MeshBuilder, color: Color) -> void:
	builder.add(_cylinder(0.065, 0.065, 0.01), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.005, 0.0)), TIN_COLOR)
	builder.add(_cylinder(0.012, 0.055, 0.045), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0325, 0.0)), color)


static func _get_mound_color(style: IngredientData.PieceStyle, color: Color) -> Color:
	match style:
		IngredientData.PieceStyle.MUSHROOM:
			return STRAW_COLOR
		IngredientData.PieceStyle.ROOT:
			return DIRT_COLOR
		IngredientData.PieceStyle.CRYSTAL:
			return color.darkened(0.05)
		_:
			return color.darkened(0.35)


static func _random_spot(random: RandomNumberGenerator, half_area: Vector2, is_round: bool) -> Vector2:
	if is_round:
		var angle: float = random.randf_range(0.0, TAU)
		var reach: float = sqrt(random.randf())
		return Vector2(cos(angle) * half_area.x * reach, sin(angle) * half_area.y * reach)
	return Vector2(random.randf_range(-half_area.x, half_area.x), random.randf_range(-half_area.y, half_area.y))


static func _sphere(radius: float, height: float) -> SphereMesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = RADIAL_SEGMENTS
	sphere.rings = RINGS
	return sphere


static func _cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = RADIAL_SEGMENTS
	cylinder.rings = 1
	return cylinder


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	capsule.radial_segments = RADIAL_SEGMENTS
	capsule.rings = 2
	return capsule


static func _box(edge: float) -> BoxMesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * edge
	return box


## Collects primitives (placed and colored) into one mesh.
class MeshBuilder:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	## Adds [param primitive] placed by [param placement], all in [param color].
	func add(primitive: PrimitiveMesh, placement: Transform3D, color: Color) -> void:
		var arrays: Array = primitive.get_mesh_arrays()
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normal_basis: Basis = placement.basis.inverse().transposed()
		var first_index: int = vertices.size()
		for vertex_index: int in source_vertices.size():
			vertices.append(placement * source_vertices[vertex_index])
			normals.append((normal_basis * source_normals[vertex_index]).normalized())
			colors.append(color)
		for source_index: int in source_indices:
			indices.append(first_index + source_index)

	## The finished mesh with [param material].
	func commit(material: Material) -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var built: ArrayMesh = ArrayMesh.new()
		built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		built.surface_set_material(0, material)
		return built

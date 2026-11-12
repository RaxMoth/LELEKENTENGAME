## Turns a TownLayout into a handful of static meshes: building walls (brick,
## plaster, concrete), flat roofs with parapets, windows (glass that lights
## up at night), sidewalks, curbs, lane markings and crosswalks, street lamps
## and parked cars. The town is split into square chunks, each one mesh with
## a few surfaces, so whatever is behind the player is culled and the whole
## town costs a few dozen draw calls on a standalone headset. Geometry goes
## straight into packed arrays (no SurfaceTool), so building the town at
## load takes a fraction of a second.
##
##   var builder: TownMeshBuilder = TownMeshBuilder.new(layout, data, materials)
##   for chunk: ArrayMesh in builder.build_chunks(): ...
##
## UVs are in meters (like WorldUVMesh), so the shared materials tile at real
## scale. Window glass samples a small generated atlas (dark, curtained, lit
## warm, lit cool) whose emission turns on at night.
##
## Dependencies: TownLayout, TownData
class_name TownMeshBuilder
extends RefCounted

## Surfaces of a chunk mesh, in this order.
enum Layer { BRICK, PLASTER, CONCRETE, ROOF, WINDOWS, SIDEWALK, PROPS, GLOW }

const FLOOR_HEIGHT: float = 3.0
## Windows sit this far in front of their wall (no flicker at a distance).
const WINDOW_OFFSET: float = 0.04
const PARAPET_HEIGHT: float = 0.7
const PARAPET_WIDTH: float = 0.3
const SIDEWALK_TOP: float = -0.02
const CURB_HEIGHT: float = 0.1
const CURB_WIDTH: float = 0.18
const MARKING_TOP: float = -0.035
const ASPHALT_TOP: float = -0.05
## Share of windows lit at night.
const LIT_SHARE: float = 0.38

const ATLAS_CELL_PIXELS: int = 32

## Vertex colors of the untextured props.
const MARKING_COLOR: Color = Color(0.82, 0.82, 0.78)
const CURB_COLOR: Color = Color(0.55, 0.55, 0.56)
const POLE_COLOR: Color = Color(0.16, 0.17, 0.19)
const ROOF_UNIT_COLOR: Color = Color(0.42, 0.43, 0.45)
const TIRE_COLOR: Color = Color(0.06, 0.06, 0.07)
const CAR_GLASS_COLOR: Color = Color(0.1, 0.12, 0.16)
const CAR_COLORS: Array[Color] = [
	Color(0.55, 0.56, 0.58), Color(0.12, 0.13, 0.15), Color(0.82, 0.83, 0.84), Color(0.42, 0.08, 0.09),
	Color(0.11, 0.2, 0.36), Color(0.27, 0.29, 0.25), Color(0.6, 0.47, 0.25),
]

static var _window_atlas: Texture2D = null
static var _window_glow: Texture2D = null

var chunk_size: float = 96.0

var _layout: TownLayout = null
var _data: TownData = null
var _materials: Array[Material] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## Chunk key -> Array of one MeshBucket per Layer.
var _chunks: Dictionary = {}


## [param layer_materials]: one material per Layer (BRICK..SIDEWALK) — the
## builder makes its own for WINDOWS, PROPS and GLOW when null.
func _init(town_layout: TownLayout, town_data: TownData, layer_materials: Array[Material]) -> void:
	_layout = town_layout
	_data = town_data
	_materials = layer_materials.duplicate()
	_materials.resize(Layer.size())
	_random.seed = town_data.layout_seed + 101
	if _materials[Layer.WINDOWS] == null:
		_materials[Layer.WINDOWS] = create_window_material()
	if _materials[Layer.PROPS] == null:
		_materials[Layer.PROPS] = _create_vertex_color_material()
	if _materials[Layer.GLOW] == null:
		_materials[Layer.GLOW] = create_glow_material()


## Builds the whole town: one ArrayMesh per chunk, each placed in world space.
func build_chunks() -> Array[ArrayMesh]:
	_chunks.clear()
	for building_index: int in _layout.building_footprints.size():
		_add_building(_layout.building_footprints[building_index], _layout.building_heights[building_index], _layout.building_styles[building_index])
	for block_index: int in _layout.blocks.size():
		if _layout.block_kinds[block_index] != TownLayout.BlockKind.OUTSKIRTS:
			_add_sidewalk(_layout.blocks[block_index])
	_add_street_markings()
	for lamp: Vector3 in _layout.lamps:
		_add_lamp(lamp)
	for car: Vector3 in _layout.parked_cars:
		_add_car(car)
	var meshes: Array[ArrayMesh] = []
	for key: Vector2i in _chunks:
		var mesh: ArrayMesh = ArrayMesh.new()
		var buckets: Array = _chunks[key]
		for layer: int in Layer.size():
			(buckets[layer] as MeshBucket).commit(mesh, _materials[layer])
		if mesh.get_surface_count() > 0:
			meshes.append(mesh)
	return meshes


## The material of the windows (its emission is what lights them at night).
func get_window_material() -> StandardMaterial3D:
	return _materials[Layer.WINDOWS] as StandardMaterial3D


## The material of the street lamps' heads.
func get_glow_material() -> StandardMaterial3D:
	return _materials[Layer.GLOW] as StandardMaterial3D


## Window glass: the generated atlas, emission (night light) off by default.
static func create_window_material() -> StandardMaterial3D:
	_ensure_window_atlas()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = "TownWindows"
	material.albedo_texture = _window_atlas
	material.metallic_specular = 0.7
	material.roughness = 0.25
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.emission_enabled = true
	material.emission_texture = _window_glow
	material.emission = Color.WHITE
	material.emission_energy_multiplier = 0.0
	return material


## Street lamp heads: unshaded light that brightens at night.
static func create_glow_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = "TownLampGlow"
	material.albedo_color = Color(0.86, 0.84, 0.78)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.86, 0.6)
	material.emission_energy_multiplier = 0.2
	return material


## The right-hand direction of someone looking at a wall facing [param normal].
static func get_viewer_right(normal: Vector3) -> Vector3:
	return Vector3(normal.z, 0.0, -normal.x)


static func clear_cache() -> void:
	_window_atlas = null
	_window_glow = null

# ============================================
# BUILDINGS
# ============================================

func _add_building(footprint: Rect2, height: float, style: TownLayout.BuildingStyle) -> void:
	var buckets: Array = _get_buckets(footprint.get_center())
	var wall_layer: Layer = Layer.BRICK
	match style:
		TownLayout.BuildingStyle.PLASTER:
			wall_layer = Layer.PLASTER
		TownLayout.BuildingStyle.OFFICE:
			wall_layer = Layer.CONCRETE
	var walls: MeshBucket = buckets[wall_layer]
	# A slight tint per building so a street of the same brick doesn't look cloned.
	var tint: Color = Color.WHITE.darkened(_random.randf_range(0.0, 0.22))
	if style == TownLayout.BuildingStyle.PLASTER:
		tint = tint.lerp(CAR_COLORS[_random.randi_range(0, CAR_COLORS.size() - 1)].lightened(0.55), 0.25)
	var center: Vector3 = Vector3(footprint.get_center().x, height * 0.5, footprint.get_center().y)
	var box_size: Vector3 = Vector3(footprint.size.x, height, footprint.size.y)
	walls.add_box(center, box_size, tint, false)
	(buckets[Layer.ROOF] as MeshBucket).add_quad_up(Rect2(footprint.position, footprint.size), height, Color.WHITE)
	# Parapet around the flat roof.
	var parapet_y: float = height + PARAPET_HEIGHT * 0.5
	walls.add_box(Vector3(center.x, parapet_y, footprint.position.y + PARAPET_WIDTH * 0.5), Vector3(footprint.size.x, PARAPET_HEIGHT, PARAPET_WIDTH), tint, false)
	walls.add_box(Vector3(center.x, parapet_y, footprint.end.y - PARAPET_WIDTH * 0.5), Vector3(footprint.size.x, PARAPET_HEIGHT, PARAPET_WIDTH), tint, false)
	walls.add_box(Vector3(footprint.position.x + PARAPET_WIDTH * 0.5, parapet_y, center.z), Vector3(PARAPET_WIDTH, PARAPET_HEIGHT, footprint.size.y - PARAPET_WIDTH * 2.0), tint, false)
	walls.add_box(Vector3(footprint.end.x - PARAPET_WIDTH * 0.5, parapet_y, center.z), Vector3(PARAPET_WIDTH, PARAPET_HEIGHT, footprint.size.y - PARAPET_WIDTH * 2.0), tint, false)
	# A rooftop unit or two (air conditioning, a stair house).
	var props: MeshBucket = buckets[Layer.PROPS]
	for unit_index: int in _random.randi_range(1, 2):
		var unit_size: Vector3 = Vector3(_random.randf_range(1.4, 3.0), _random.randf_range(0.9, 2.2), _random.randf_range(1.4, 3.0))
		var spot: Vector2 = Vector2(_random.randf_range(footprint.position.x + 2.0, footprint.end.x - 2.0), _random.randf_range(footprint.position.y + 2.0, footprint.end.y - 2.0))
		if footprint.size.x > 5.0 and footprint.size.y > 5.0:
			props.add_box(Vector3(spot.x, height + unit_size.y * 0.5, spot.y), unit_size, ROOF_UNIT_COLOR, true)
	_add_windows(buckets[Layer.WINDOWS], footprint, height, style)


## Rows of windows on all four sides, one row per floor; offices get wide
## glass bands, other buildings single windows and wider shop windows on the
## ground floor.
func _add_windows(windows: MeshBucket, footprint: Rect2, height: float, style: TownLayout.BuildingStyle) -> void:
	var is_office: bool = style == TownLayout.BuildingStyle.OFFICE
	var pitch: float = 3.0 if is_office else 2.8
	var window_size: Vector2 = Vector2(2.6, 2.3) if is_office else Vector2(1.25, 1.55)
	var floors: int = floori((height - 0.6) / FLOOR_HEIGHT)
	var sides: Array[Array] = [
		[Vector3(footprint.position.x, 0.0, footprint.position.y - WINDOW_OFFSET), Vector3.RIGHT, Vector3.FORWARD, footprint.size.x],
		[Vector3(footprint.end.x, 0.0, footprint.end.y + WINDOW_OFFSET), Vector3.LEFT, Vector3.BACK, footprint.size.x],
		[Vector3(footprint.position.x - WINDOW_OFFSET, 0.0, footprint.end.y), Vector3.FORWARD, Vector3.LEFT, footprint.size.y],
		[Vector3(footprint.end.x + WINDOW_OFFSET, 0.0, footprint.position.y), Vector3.BACK, Vector3.RIGHT, footprint.size.y],
	]
	for side: Array in sides:
		var origin: Vector3 = side[0]
		var along: Vector3 = side[1]
		var normal: Vector3 = side[2]
		var length: float = side[3]
		var columns: int = floori((length - 1.0) / pitch)
		if columns <= 0:
			continue
		var start: float = (length - columns * pitch) * 0.5 + pitch * 0.5
		for floor_index: int in floors:
			var is_shop_floor: bool = floor_index == 0 and not is_office
			var size: Vector2 = Vector2(minf(pitch - 0.5, 2.3), 2.2) if is_shop_floor else window_size
			var bottom: float = 0.45 if is_shop_floor else floor_index * FLOOR_HEIGHT + (FLOOR_HEIGHT - size.y) * 0.55
			for column: int in columns:
				var middle: Vector3 = origin + along * (start + column * pitch) + Vector3(0.0, bottom + size.y * 0.5, 0.0)
				var cell: int = 0
				var roll: float = _random.randf()
				if roll < LIT_SHARE:
					cell = 2 if roll < LIT_SHARE * 0.7 else 3
				elif roll < LIT_SHARE + 0.2:
					cell = 1
				windows.add_window(middle, normal, size, cell)

# ============================================
# STREETS
# ============================================

## A sidewalk ring along the block's edge, with a curb on its street side.
func _add_sidewalk(block: Rect2) -> void:
	var buckets: Array = _get_buckets(block.get_center())
	var sidewalk: MeshBucket = buckets[Layer.SIDEWALK]
	var props: MeshBucket = buckets[Layer.PROPS]
	var width: float = _data.sidewalk_width
	var strips: Array[Rect2] = [
		Rect2(block.position.x, block.position.y, block.size.x, width),
		Rect2(block.position.x, block.end.y - width, block.size.x, width),
		Rect2(block.position.x, block.position.y + width, width, block.size.y - width * 2.0),
		Rect2(block.end.x - width, block.position.y + width, width, block.size.y - width * 2.0),
	]
	for strip: Rect2 in strips:
		sidewalk.add_quad_up(strip, SIDEWALK_TOP, Color.WHITE)
	var curb_y: float = ASPHALT_TOP + CURB_HEIGHT * 0.5
	props.add_box(Vector3(block.get_center().x, curb_y, block.position.y), Vector3(block.size.x, CURB_HEIGHT, CURB_WIDTH), CURB_COLOR, true)
	props.add_box(Vector3(block.get_center().x, curb_y, block.end.y), Vector3(block.size.x, CURB_HEIGHT, CURB_WIDTH), CURB_COLOR, true)
	props.add_box(Vector3(block.position.x, curb_y, block.get_center().y), Vector3(CURB_WIDTH, CURB_HEIGHT, block.size.y), CURB_COLOR, true)
	props.add_box(Vector3(block.end.x, curb_y, block.get_center().y), Vector3(CURB_WIDTH, CURB_HEIGHT, block.size.y), CURB_COLOR, true)


## Dashed centre lines along every street between crossings, and zebra
## crossings at each end.
func _add_street_markings() -> void:
	var half_street: float = _data.street_width * 0.5
	var xs: PackedFloat32Array = _data.street_x
	var zs: PackedFloat32Array = _data.street_z
	for x_index: int in xs.size():
		for z_index: int in zs.size() - 1:
			_add_dashes(Vector2(xs[x_index], zs[z_index] + half_street), Vector2(xs[x_index], zs[z_index + 1] - half_street))
	for z_index: int in zs.size():
		for x_index: int in xs.size() - 1:
			_add_dashes(Vector2(xs[x_index] + half_street, zs[z_index]), Vector2(xs[x_index + 1] - half_street, zs[z_index]))


func _add_dashes(from_point: Vector2, to_point: Vector2) -> void:
	var props: MeshBucket = _get_buckets((from_point + to_point) * 0.5)[Layer.PROPS]
	var length: float = from_point.distance_to(to_point)
	var direction: Vector2 = (to_point - from_point) / length
	var along_x: bool = absf(direction.x) > 0.5
	# Zebra crossings at both ends.
	var stripe_length: float = _data.street_width - 1.0
	for end_index: int in 2:
		var crossing_center: Vector2 = from_point + direction * 1.6 if end_index == 0 else to_point - direction * 1.6
		for stripe_index: int in 6:
			var offset: float = (stripe_index - 2.5) * (stripe_length / 6.0)
			var stripe_center: Vector2 = crossing_center + (Vector2(0.0, offset) if along_x else Vector2(offset, 0.0))
			var stripe_size: Vector2 = Vector2(2.2, 0.5) if along_x else Vector2(0.5, 2.2)
			props.add_quad_up(Rect2(stripe_center - stripe_size * 0.5, stripe_size), MARKING_TOP, MARKING_COLOR)
	var along: float = 5.0
	while along < length - 5.0:
		var dash_center: Vector2 = from_point + direction * (along + 1.0)
		var dash_size: Vector2 = Vector2(2.0, 0.14) if along_x else Vector2(0.14, 2.0)
		props.add_quad_up(Rect2(dash_center - dash_size * 0.5, dash_size), MARKING_TOP, MARKING_COLOR)
		along += 5.0


func _add_lamp(lamp: Vector3) -> void:
	var buckets: Array = _get_buckets(Vector2(lamp.x, lamp.y))
	var props: MeshBucket = buckets[Layer.PROPS]
	var base: Vector3 = Vector3(lamp.x, 0.0, lamp.y)
	var reach: Vector3 = Vector3(sin(lamp.z), 0.0, cos(lamp.z))
	props.add_box(base + Vector3(0.0, 2.8, 0.0), Vector3(0.14, 5.6, 0.14), POLE_COLOR, true)
	var arm_center: Vector3 = base + reach * 0.7 + Vector3(0.0, 5.55, 0.0)
	var arm_size: Vector3 = Vector3(0.09, 0.09, 1.5) if absf(reach.z) > 0.5 else Vector3(1.5, 0.09, 0.09)
	props.add_box(arm_center, arm_size, POLE_COLOR, true)
	var head_size: Vector3 = Vector3(0.32, 0.12, 0.6) if absf(reach.z) > 0.5 else Vector3(0.6, 0.12, 0.32)
	(buckets[Layer.GLOW] as MeshBucket).add_box(base + reach * 1.35 + Vector3(0.0, 5.45, 0.0), head_size, Color.WHITE, true)


func _add_car(car: Vector3) -> void:
	var props: MeshBucket = _get_buckets(Vector2(car.x, car.y))[Layer.PROPS]
	var nose: Vector3 = Vector3(sin(car.z), 0.0, cos(car.z)).round()
	var side: Vector3 = Vector3(nose.z, 0.0, -nose.x)
	var base: Vector3 = Vector3(car.x, 0.0, car.y)
	var paint: Color = CAR_COLORS[_random.randi_range(0, CAR_COLORS.size() - 1)]
	var length: float = TownLayout.CAR_LENGTH
	var width: float = TownLayout.CAR_WIDTH
	props.add_box(base + Vector3(0.0, 0.62, 0.0), _oriented(nose, Vector3(width, 0.62, length)), paint, true)
	props.add_box(base + Vector3(0.0, 1.2, 0.0) - nose * 0.2, _oriented(nose, Vector3(width * 0.86, 0.55, length * 0.5)), CAR_GLASS_COLOR, true)
	props.add_box(base + Vector3(0.0, 1.49, 0.0) - nose * 0.2, _oriented(nose, Vector3(width * 0.84, 0.04, length * 0.46)), paint, true)
	for axle: float in [-1.0, 1.0]:
		for wheel_side: float in [-1.0, 1.0]:
			var wheel: Vector3 = base + nose * (length * 0.32 * axle) + side * (width * 0.47 * wheel_side) + Vector3(0.0, 0.32, 0.0)
			props.add_box(wheel, _oriented(nose, Vector3(0.24, 0.64, 0.64)), TIRE_COLOR, true)


## [param box_size] given with Z along the car's nose, turned to world axes.
func _oriented(nose: Vector3, box_size: Vector3) -> Vector3:
	return box_size if absf(nose.z) > 0.5 else Vector3(box_size.z, box_size.y, box_size.x)

# ============================================
# INTERNALS
# ============================================

func _get_buckets(point: Vector2) -> Array:
	var key: Vector2i = Vector2i(floori(point.x / chunk_size), floori(point.y / chunk_size))
	if not _chunks.has(key):
		var buckets: Array = []
		for layer: int in Layer.size():
			buckets.append(MeshBucket.new())
		_chunks[key] = buckets
	return _chunks[key]


static func _create_vertex_color_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = "TownProps"
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.8
	return material


## The window atlas: 2 x 2 cells (dark glass, curtained, lit warm, lit cool),
## each a frame around glass; the glow texture lights only the lit cells.
static func _ensure_window_atlas() -> void:
	if _window_atlas != null:
		return
	var size: int = ATLAS_CELL_PIXELS * 2
	var albedo: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var glow: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
	var frame: Color = Color(0.78, 0.79, 0.8)
	var glass_tops: Array[Color] = [Color(0.2, 0.25, 0.32), Color(0.62, 0.56, 0.46), Color(0.98, 0.8, 0.5), Color(0.82, 0.88, 0.95)]
	var glass_bottoms: Array[Color] = [Color(0.08, 0.1, 0.14), Color(0.16, 0.18, 0.22), Color(0.86, 0.6, 0.32), Color(0.62, 0.7, 0.8)]
	var border: int = 3
	for cell: int in 4:
		var cell_x: int = (cell % 2) * ATLAS_CELL_PIXELS
		var cell_y: int = floori(cell / 2.0) * ATLAS_CELL_PIXELS
		for pixel_y: int in ATLAS_CELL_PIXELS:
			for pixel_x: int in ATLAS_CELL_PIXELS:
				var is_frame: bool = pixel_x < border or pixel_y < border or pixel_x >= ATLAS_CELL_PIXELS - border or pixel_y >= ATLAS_CELL_PIXELS - border
				# A mullion down the middle and a transom near the top.
				is_frame = is_frame or absi(pixel_x - ATLAS_CELL_PIXELS / 2) < 1 or absi(pixel_y - ATLAS_CELL_PIXELS / 3) < 1
				var shade: float = float(pixel_y) / ATLAS_CELL_PIXELS
				var glass: Color = glass_tops[cell].lerp(glass_bottoms[cell], shade)
				albedo.set_pixel(cell_x + pixel_x, cell_y + pixel_y, frame if is_frame else glass)
				var is_lit: bool = cell >= 2 and not is_frame
				glow.set_pixel(cell_x + pixel_x, cell_y + pixel_y, glass if is_lit else Color.BLACK)
	albedo.generate_mipmaps()
	glow.generate_mipmaps()
	_window_atlas = ImageTexture.create_from_image(albedo)
	_window_glow = ImageTexture.create_from_image(glow)


## Geometry of one surface in packed arrays: quads and boxes with UVs in
## meters (or atlas cells for windows) and vertex colors.
class MeshBucket:
	extends RefCounted

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	## A quad from four corners given clockwise as seen from the front.
	func add_quad(corners: PackedVector3Array, normal: Vector3, quad_uvs: PackedVector2Array, color: Color) -> void:
		var first: int = vertices.size()
		for corner_index: int in 4:
			vertices.append(corners[corner_index])
			normals.append(normal)
			uvs.append(quad_uvs[corner_index])
			colors.append(color)
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))

	## A flat, upward-facing rectangle (world X / Z) at [param height].
	func add_quad_up(rect: Rect2, height: float, color: Color) -> void:
		var corners: PackedVector3Array = PackedVector3Array([
			Vector3(rect.position.x, height, rect.position.y), Vector3(rect.end.x, height, rect.position.y),
			Vector3(rect.end.x, height, rect.end.y), Vector3(rect.position.x, height, rect.end.y),
		])
		var quad_uvs: PackedVector2Array = PackedVector2Array()
		for corner: Vector3 in corners:
			quad_uvs.append(Vector2(corner.x, corner.z))
		add_quad(corners, Vector3.UP, quad_uvs, color)

	## An axis-aligned box's four sides (and its top; [param has_bottom] adds
	## the bottom too, for things off the ground).
	func add_box(center: Vector3, box_size: Vector3, color: Color, has_top: bool = true) -> void:
		var half: Vector3 = box_size * 0.5
		for normal: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var face_center: Vector3 = center + normal * absf(half.dot(normal))
			var half_width: float = absf(half.dot(TownMeshBuilder.get_viewer_right(normal)))
			add_side(face_center, normal, Vector2(half_width * 2.0, box_size.y), color)
		if has_top:
			add_quad_up(Rect2(center.x - half.x, center.z - half.z, box_size.x, box_size.z), center.y + half.y, color)

	## A vertical quad centred on [param face_center] facing [param normal],
	## [param size] wide and tall, UVs in meters.
	func add_side(face_center: Vector3, normal: Vector3, size: Vector2, color: Color) -> void:
		var right: Vector3 = TownMeshBuilder.get_viewer_right(normal)
		var half_right: Vector3 = right * size.x * 0.5
		var half_up: Vector3 = Vector3(0.0, size.y * 0.5, 0.0)
		var corners: PackedVector3Array = PackedVector3Array([face_center - half_right + half_up, face_center + half_right + half_up, face_center + half_right - half_up, face_center - half_right - half_up])
		var quad_uvs: PackedVector2Array = PackedVector2Array()
		for corner: Vector3 in corners:
			quad_uvs.append(Vector2(corner.dot(right), -corner.y))
		add_quad(corners, normal, quad_uvs, color)

	## A window quad facing [param normal], centred on [param middle], using atlas cell [param cell].
	func add_window(middle: Vector3, normal: Vector3, size: Vector2, cell: int) -> void:
		var half_right: Vector3 = TownMeshBuilder.get_viewer_right(normal) * size.x * 0.5
		var half_up: Vector3 = Vector3(0.0, size.y * 0.5, 0.0)
		var cell_origin: Vector2 = Vector2((cell % 2) * 0.5, floori(cell / 2.0) * 0.5)
		var corners: PackedVector3Array = PackedVector3Array([middle - half_right + half_up, middle + half_right + half_up, middle + half_right - half_up, middle - half_right - half_up])
		var quad_uvs: PackedVector2Array = PackedVector2Array([cell_origin, cell_origin + Vector2(0.5, 0.0), cell_origin + Vector2(0.5, 0.5), cell_origin + Vector2(0.0, 0.5)])
		add_quad(corners, normal, quad_uvs, Color.WHITE)

	## Appends this geometry to [param mesh] as one surface (nothing when empty).
	func commit(mesh: ArrayMesh, material: Material) -> void:
		if vertices.is_empty():
			return
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)

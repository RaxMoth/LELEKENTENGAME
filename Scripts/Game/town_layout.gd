## The town worked out from TownData: blocks between the streets, building
## lots (taller toward downtown), the walkable floor (streets, sidewalks,
## parks, alleys, the house's lawn — everything but buildings and the
## house's walls), street lamps, parked cars, park trees and the sidewalk
## corners people walk between. The same data and seed always give the same
## town (co-op players see the same streets).
##
##   var layout: TownLayout = TownLayout.build(town_data)
##   walkable.regions.append_array(layout.walkable_regions)
##   walkable.add_rect_blockers(layout.building_footprints)
##
## Pure logic (unit-tested in Tests/Unit/town_layout_test.gd).
##
## Dependencies: TownData
class_name TownLayout
extends RefCounted

enum BlockKind { CITY, HOME, PARK, PLAZA, OUTSKIRTS }
## How a building looks (TownMeshBuilder picks the facade).
enum BuildingStyle { BRICK, PLASTER, OFFICE }

## A parked car's size on the ground (meters).
const CAR_LENGTH: float = 4.3
const CAR_WIDTH: float = 1.85

## The walkable town: outer edges of the outermost streets.
var bounds: Rect2 = Rect2()
## Every block (the area between street curbs, sidewalks included).
var blocks: Array[Rect2] = []
var block_kinds: Array[BlockKind] = []
## Grid position (column, row) of each block; outskirts get (-1, -1).
var block_cells: Array[Vector2i] = []
## One entry per building: footprint (world X / Z), height and style.
var building_footprints: Array[Rect2] = []
var building_heights: PackedFloat32Array = PackedFloat32Array()
var building_styles: Array[BuildingStyle] = []
## Floor rectangles (world X / Z) the player may walk on.
var walkable_regions: Array[Rect2] = []
## Street lamps: (x, z, yaw) — the arm reaches toward +Z of the yaw.
var lamps: PackedVector3Array = PackedVector3Array()
## Parked cars: (x, z, yaw; nose along +Z of the yaw), and their footprints.
var parked_cars: PackedVector3Array = PackedVector3Array()
var car_blockers: Array[Rect2] = []
## Park trees: (x, z, scale, yaw degrees), and their trunks as blockers.
var park_trees: Array[Vector4] = []
var tree_blockers: Array[Vector3] = []
## Plaza fountains: (x, z, radius).
var fountains: Array[Vector3] = []
## Sidewalk corners people walk between, and the corners each one leads to
## (around its block, or across a street).
var corners: PackedVector2Array = PackedVector2Array()
var corner_links: Array[PackedInt32Array] = []

var _data: TownData = null
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


## Works out the whole town from [param data].
static func build(data: TownData) -> TownLayout:
	var layout: TownLayout = TownLayout.new()
	layout._data = data
	layout._random.seed = data.layout_seed
	layout._build()
	return layout


## The block (column, row) a point lies in, or (-1, -1) on a street / outside.
func get_block_cell_at(point: Vector2) -> Vector2i:
	for block_index: int in blocks.size():
		if block_kinds[block_index] != BlockKind.OUTSKIRTS and blocks[block_index].has_point(point):
			return block_cells[block_index]
	return Vector2i(-1, -1)


## The block rectangle at grid cell [param cell] (empty Rect2 if none).
func get_block(cell: Vector2i) -> Rect2:
	for block_index: int in blocks.size():
		if block_cells[block_index] == cell:
			return blocks[block_index]
	return Rect2()


## The inner part of a block, inside its sidewalk.
func get_block_inner(block: Rect2) -> Rect2:
	return block.grow(-_data.sidewalk_width)


## Index of the sidewalk corner nearest to [param point].
func get_nearest_corner(point: Vector2) -> int:
	var nearest: int = -1
	var nearest_distance: float = INF
	for corner_index: int in corners.size():
		var distance: float = corners[corner_index].distance_squared_to(point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = corner_index
	return nearest

# ============================================
# BUILDING THE TOWN
# ============================================

func _build() -> void:
	var half_street: float = _data.street_width * 0.5
	var xs: PackedFloat32Array = _data.street_x
	var zs: PackedFloat32Array = _data.street_z
	bounds = Rect2(xs[0] - half_street, zs[0] - half_street, xs[xs.size() - 1] - xs[0] + _data.street_width, zs[zs.size() - 1] - zs[0] + _data.street_width)
	for row: int in zs.size() - 1:
		for column: int in xs.size() - 1:
			var block: Rect2 = Rect2(xs[column] + half_street, zs[row] + half_street, xs[column + 1] - xs[column] - _data.street_width, zs[row + 1] - zs[row] - _data.street_width)
			var cell: Vector2i = Vector2i(column, row)
			var kind: BlockKind = BlockKind.CITY
			if cell == _data.home_block:
				kind = BlockKind.HOME
			elif _data.park_blocks.has(cell):
				kind = BlockKind.PARK
			elif _data.plaza_blocks.has(cell):
				kind = BlockKind.PLAZA
			_add_block(block, kind, cell)
	_build_outskirts()
	_build_walkable_regions()
	_build_corners()


func _add_block(block: Rect2, kind: BlockKind, cell: Vector2i) -> void:
	blocks.append(block)
	block_kinds.append(kind)
	block_cells.append(cell)
	var inner: Rect2 = get_block_inner(block)
	match kind:
		BlockKind.CITY:
			_fill_with_buildings(inner)
		BlockKind.PARK:
			_plant_park(inner)
		BlockKind.PLAZA:
			fountains.append(Vector3(inner.get_center().x, inner.get_center().y, 3.2))
		BlockKind.OUTSKIRTS:
			_fill_with_buildings(block)
	if kind != BlockKind.OUTSKIRTS:
		_place_lamps(block)
		if kind != BlockKind.HOME:
			_park_cars(block)


## Splits a block's inside into lots along its longer side (two rows when it
## is deep) and puts one building on each, alleys between them.
func _fill_with_buildings(area: Rect2) -> void:
	var is_wide: bool = area.size.x >= area.size.y
	var length: float = area.size.x if is_wide else area.size.y
	var depth: float = area.size.y if is_wide else area.size.x
	var rows: int = 2 if depth > _data.two_row_depth else 1
	var row_depth: float = depth / rows
	for row: int in rows:
		var cursor: float = 0.0
		while cursor < length - 0.01:
			var remaining: float = length - cursor
			var lot_width: float = remaining
			if remaining > _data.min_lot_width * 2.0:
				lot_width = _random.randf_range(_data.min_lot_width, minf(remaining - _data.min_lot_width, _data.min_lot_width * 2.4))
			var lot: Rect2
			if is_wide:
				lot = Rect2(area.position.x + cursor, area.position.y + row * row_depth, lot_width, row_depth)
			else:
				lot = Rect2(area.position.x + row * row_depth, area.position.y + cursor, row_depth, lot_width)
			_add_building(lot)
			cursor += lot_width


func _add_building(lot: Rect2) -> void:
	var footprint: Rect2 = lot.grow(-_data.alley_width * 0.5)
	if footprint.size.x < 2.0 or footprint.size.y < 2.0:
		return
	var downtown: float = clampf(1.0 - footprint.get_center().distance_to(_data.downtown_center) / _data.downtown_radius, 0.0, 1.0)
	var low: float = _random.randf_range(_data.low_height.x, _data.low_height.y)
	var high: float = _random.randf_range(_data.high_height.x, _data.high_height.y)
	var height: float = lerpf(low, high, downtown * downtown)
	var style: BuildingStyle = BuildingStyle.OFFICE
	if downtown < 0.45 or _random.randf() < 0.15:
		style = BuildingStyle.BRICK if _random.randf() < 0.55 else BuildingStyle.PLASTER
	building_footprints.append(footprint)
	building_heights.append(snappedf(height, 0.5))
	building_styles.append(style)


func _plant_park(area: Rect2) -> void:
	var tree_count: int = roundi(area.get_area() / 100.0 * _data.park_tree_density)
	for tree_index: int in tree_count:
		var spot: Vector2 = Vector2(_random.randf_range(area.position.x + 2.0, area.end.x - 2.0), _random.randf_range(area.position.y + 2.0, area.end.y - 2.0))
		# Keep a cross of paths through the park clear.
		if absf(spot.x - area.get_center().x) < 2.5 or absf(spot.y - area.get_center().y) < 2.5:
			continue
		park_trees.append(Vector4(spot.x, spot.y, _random.randf_range(1.0, 1.5), _random.randf_range(0.0, 360.0)))
		tree_blockers.append(Vector3(spot.x, spot.y, 0.45))


## Lamps along every edge of a block, at the curb, facing the street.
func _place_lamps(block: Rect2) -> void:
	var inset: float = 0.5
	var edges: Array[Array] = [
		[Vector2(block.position.x, block.position.y + inset), Vector2(block.end.x, block.position.y + inset), PI],
		[Vector2(block.position.x, block.end.y - inset), Vector2(block.end.x, block.end.y - inset), 0.0],
		[Vector2(block.position.x + inset, block.position.y), Vector2(block.position.x + inset, block.end.y), -PI * 0.5],
		[Vector2(block.end.x - inset, block.position.y), Vector2(block.end.x - inset, block.end.y), PI * 0.5],
	]
	for edge: Array in edges:
		var from_point: Vector2 = edge[0]
		var to_point: Vector2 = edge[1]
		var count: int = maxi(1, floori(from_point.distance_to(to_point) / _data.lamp_spacing))
		for lamp_index: int in count:
			var spot: Vector2 = from_point.lerp(to_point, (lamp_index + 0.5) / count)
			lamps.append(Vector3(spot.x, spot.y, edge[2]))


## Cars parked along the curbs, nose along the street, none near corners.
func _park_cars(block: Rect2) -> void:
	var offset: float = 1.3
	var corner_clearance: float = 7.0
	var edges: Array[Array] = [
		[Vector2(block.position.x, block.position.y - offset), Vector2(block.end.x, block.position.y - offset), PI * 0.5],
		[Vector2(block.position.x, block.end.y + offset), Vector2(block.end.x, block.end.y + offset), -PI * 0.5],
		[Vector2(block.position.x - offset, block.position.y), Vector2(block.position.x - offset, block.end.y), 0.0],
		[Vector2(block.end.x + offset, block.position.y), Vector2(block.end.x + offset, block.end.y), PI],
	]
	for edge: Array in edges:
		var from_point: Vector2 = edge[0]
		var to_point: Vector2 = edge[1]
		var length: float = from_point.distance_to(to_point)
		var direction: Vector2 = (to_point - from_point) / length
		var along: float = corner_clearance
		while along < length - corner_clearance:
			if _random.randf() < _data.parked_car_chance:
				var spot: Vector2 = from_point + direction * along
				parked_cars.append(Vector3(spot.x, spot.y, edge[2]))
				var car_size: Vector2 = Vector2(CAR_LENGTH, CAR_WIDTH) if absf(direction.x) > 0.5 else Vector2(CAR_WIDTH, CAR_LENGTH)
				car_blockers.append(Rect2(spot - car_size * 0.5, car_size))
			along += _data.parking_spacing


## A ring of buildings beyond the outer streets so the town doesn't end in
## an empty plain.
func _build_outskirts() -> void:
	var depth: float = _data.outskirts_depth
	var outer: Rect2 = bounds.grow(depth)
	var ring: Array[Rect2] = [
		Rect2(outer.position.x, outer.position.y, outer.size.x, depth),
		Rect2(outer.position.x, bounds.end.y, outer.size.x, depth),
		Rect2(outer.position.x, bounds.position.y, depth, bounds.size.y),
		Rect2(bounds.end.x, bounds.position.y, depth, bounds.size.y),
	]
	for strip: Rect2 in ring:
		_add_block(strip, BlockKind.OUTSKIRTS, Vector2i(-1, -1))


## The whole town is floor except the house's own walls (its rooms are the
## house's regions); buildings and trees are blockers on top.
func _build_walkable_regions() -> void:
	var house: Rect2 = _data.house_footprint
	walkable_regions.append(Rect2(bounds.position.x, bounds.position.y, house.position.x - bounds.position.x, bounds.size.y))
	walkable_regions.append(Rect2(house.end.x, bounds.position.y, bounds.end.x - house.end.x, bounds.size.y))
	walkable_regions.append(Rect2(house.position.x, bounds.position.y, house.size.x, house.position.y - bounds.position.y))
	walkable_regions.append(Rect2(house.position.x, house.end.y, house.size.x, bounds.end.y - house.end.y))


## Four corners per block in the middle of its sidewalk; each leads around
## the block and across the street to the facing corner of the next block.
func _build_corners() -> void:
	var inset: float = _data.sidewalk_width * 0.5
	var first_corner_of_block: PackedInt32Array = PackedInt32Array()
	for block_index: int in blocks.size():
		first_corner_of_block.append(corners.size())
		if block_kinds[block_index] == BlockKind.OUTSKIRTS:
			continue
		var ring: Rect2 = blocks[block_index].grow(-inset)
		corners.append(ring.position)
		corners.append(Vector2(ring.end.x, ring.position.y))
		corners.append(ring.end)
		corners.append(Vector2(ring.position.x, ring.end.y))
		for corner_offset: int in 4:
			corner_links.append(PackedInt32Array())
	var crossing: float = _data.street_width + _data.sidewalk_width + 0.01
	for block_index: int in blocks.size():
		if block_kinds[block_index] == BlockKind.OUTSKIRTS:
			continue
		var first: int = first_corner_of_block[block_index]
		for corner_offset: int in 4:
			var corner_index: int = first + corner_offset
			corner_links[corner_index].append(first + (corner_offset + 1) % 4)
			corner_links[corner_index].append(first + (corner_offset + 3) % 4)
	for corner_index: int in corners.size():
		for other_index: int in corners.size():
			if other_index == corner_index or floori(other_index / 4.0) == floori(corner_index / 4.0):
				continue
			var from_corner: Vector2 = corners[corner_index]
			var to_corner: Vector2 = corners[other_index]
			var is_aligned: bool = is_equal_approx(from_corner.x, to_corner.x) or is_equal_approx(from_corner.y, to_corner.y)
			if is_aligned and from_corner.distance_to(to_corner) <= crossing:
				corner_links[corner_index].append(other_index)

## The phone's map: a north-up, dark map of the town centered on the player
## — streets, blocks, buildings and parks, the house, the field towers, the
## police on foot and their vehicles, and the player as an arrow pointing
## where they look. Police off the map sit as dots on its edge, so the
## player sees where a raid comes from. Draws only what it is told; the
## Phone feeds it a few times a second while it is open.
##
##   map.set_town(layout, house_rect)
##   map.set_markers(player, heading, officers, vehicles, towers)
##   map.zoom(1)   # closer
##
## Dependencies: MapProjection, TownLayout, Palette
class_name PhoneMapView
extends Control

## Meters across the map, nearest first (zoom steps).
const SPANS: PackedFloat32Array = [70.0, 160.0, 380.0, 640.0]
const OFFICER_RADIUS: float = 10.0
const VEHICLE_SIZE: float = 26.0
const TOWER_SIZE: float = 22.0
const PLAYER_SIZE: float = 40.0
const EDGE_MARGIN: float = 16.0

## The zoom step the map opens at (index into SPANS: 0 nearest).
@export var start_zoom_step: int = 1

var _projection: MapProjection = MapProjection.new()
var _zoom_step: int = 1
var _layout: TownLayout = null
var _house: Rect2 = Rect2()
var _player: Vector2 = Vector2.ZERO
var _heading: float = 0.0
var _officers: PackedVector2Array = PackedVector2Array()
var _vehicles: PackedVector2Array = PackedVector2Array()
var _towers: PackedVector2Array = PackedVector2Array()

var _street_color: Color = Palette.STROKE
var _block_color: Color = Palette.BACKGROUND_RAISED
var _building_color: Color = Palette.SURFACE_RAISED
var _park_color: Color = Palette.SUCCESS.darkened(0.72)


func _ready() -> void:
	_zoom_step = clampi(start_zoom_step, 0, SPANS.size() - 1)
	clip_contents = true
	resized.connect(queue_redraw)


## The town to draw and the house's footprint (world X / Z).
func set_town(layout: TownLayout, house_rect: Rect2) -> void:
	_layout = layout
	_house = house_rect
	queue_redraw()


## Where everything is now (world X / Z): [param player] looking along
## [param heading] (MapProjection.heading_angle), officers on foot,
## vehicles and field towers.
func set_markers(player: Vector2, heading: float, officers: PackedVector2Array, vehicles: PackedVector2Array, towers: PackedVector2Array) -> void:
	_player = player
	_heading = heading
	_officers = officers
	_vehicles = vehicles
	_towers = towers
	queue_redraw()


## Zooms [param step] steps closer (+1) or farther (-1). Returns the meters now shown.
func zoom(step: int) -> float:
	_zoom_step = clampi(_zoom_step - step, 0, SPANS.size() - 1)
	queue_redraw()
	return SPANS[_zoom_step]


## True when the map can zoom further in [param step]'s direction.
func can_zoom(step: int) -> bool:
	var next_step: int = _zoom_step - step
	return next_step >= 0 and next_step < SPANS.size()


## Meters across the map at the current zoom.
func get_span_meters() -> float:
	return SPANS[_zoom_step]


## The map pixel of world point [param world] (X, Z) — tests check markers.
func world_to_map(world: Vector2) -> Vector2:
	_update_projection()
	return _projection.to_map(world)


func _draw() -> void:
	_update_projection()
	draw_rect(Rect2(Vector2.ZERO, size), _street_color)
	_draw_town()
	if _house.has_area():
		draw_rect(_projection.rect_to_map(_house), Palette.PRIMARY)
	for tower: Vector2 in _towers:
		_draw_tower(tower)
	for vehicle: Vector2 in _vehicles:
		_draw_vehicle(vehicle)
	for officer: Vector2 in _officers:
		_draw_officer(officer)
	_draw_player()


func _update_projection() -> void:
	_projection.view_size = size
	_projection.span_meters = SPANS[_zoom_step]
	_projection.center = _player


func _draw_town() -> void:
	if _layout == null:
		return
	var visible_world: Rect2 = _projection.get_visible_world_rect()
	for block_index: int in _layout.blocks.size():
		var block: Rect2 = _layout.blocks[block_index]
		if not block.intersects(visible_world):
			continue
		var kind: TownLayout.BlockKind = _layout.block_kinds[block_index]
		if kind == TownLayout.BlockKind.OUTSKIRTS:
			continue
		var color: Color = _park_color if kind == TownLayout.BlockKind.PARK else _block_color
		draw_rect(_projection.rect_to_map(block), color)
	for footprint: Rect2 in _layout.building_footprints:
		if footprint.intersects(visible_world):
			draw_rect(_projection.rect_to_map(footprint), _building_color)


func _draw_tower(world: Vector2) -> void:
	var pixel: Vector2 = _projection.to_map(world)
	if not _projection.is_on_map(pixel, -TOWER_SIZE):
		return
	var half: float = TOWER_SIZE * 0.5
	var diamond: PackedVector2Array = PackedVector2Array([pixel + Vector2(0.0, -half), pixel + Vector2(half, 0.0), pixel + Vector2(0.0, half), pixel + Vector2(-half, 0.0)])
	draw_colored_polygon(diamond, Palette.GOLD)


func _draw_vehicle(world: Vector2) -> void:
	var pixel: Vector2 = _projection.clamp_to_edge(_projection.to_map(world), EDGE_MARGIN)
	var half: Vector2 = Vector2(VEHICLE_SIZE, VEHICLE_SIZE) * 0.5
	draw_rect(Rect2(pixel - half, half * 2.0), Palette.DANGER)
	draw_rect(Rect2(pixel - half, half * 2.0), Palette.TEXT, false, 2.0)


func _draw_officer(world: Vector2) -> void:
	var pixel: Vector2 = _projection.to_map(world)
	var is_on_map: bool = _projection.is_on_map(pixel, EDGE_MARGIN)
	pixel = _projection.clamp_to_edge(pixel, EDGE_MARGIN)
	draw_circle(pixel, OFFICER_RADIUS, Palette.DANGER if is_on_map else Color(Palette.DANGER, 0.55))


func _draw_player() -> void:
	var pixel: Vector2 = _projection.to_map(_player)
	var direction: Vector2 = Vector2.UP.rotated(_heading)
	var side: Vector2 = direction.orthogonal()
	var arrow: PackedVector2Array = PackedVector2Array([
		pixel + direction * PLAYER_SIZE * 0.6,
		pixel - direction * PLAYER_SIZE * 0.4 + side * PLAYER_SIZE * 0.42,
		pixel - direction * PLAYER_SIZE * 0.15,
		pixel - direction * PLAYER_SIZE * 0.4 - side * PLAYER_SIZE * 0.42,
	])
	draw_circle(pixel, PLAYER_SIZE * 0.85, Color(Palette.PRIMARY, 0.25))
	draw_colored_polygon(arrow, Palette.TEXT)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), Palette.PRIMARY, 4.0, true)

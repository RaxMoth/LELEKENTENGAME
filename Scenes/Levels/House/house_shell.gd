## The house's walls, floor and ceiling, built from a few numbers at load:
## move a wall, a door or a window by editing the lists, not dozens of nodes.
## Walls run along X or Z between two floor points; doors and windows are
## gaps on a wall line (doors from the floor up, windows from the sill up),
## and every gap gets a wooden frame. A gable roof (ridge along X, eaves
## over the front and back walls) sits on top. Also runs in the editor, so
## the house shows while you design around it.
##
## Everything is one mesh with a surface per material (inside walls, outside
## walls and gables, floor, ceiling, wood for frames and eaves, roof): six
## draw calls for the whole shell. UVs
## are in meters (WorldUVMesh), so each material's uv1_scale sets its tile
## size in meters. A wall face is "outside" when it lies beyond floor_rect.
## Without a material a surface falls back to its matte Palette color.
##
## Renovations: the materials above are the shabby house a new operation
## moves into. Each ShellRenovation in [member renovations] gives one surface
## a better material per level of a renovation upgrade; the level calls
## apply_renovations() whenever upgrades change, which only swaps the
## surfaces' materials (no rebuild).
##
##   shell.apply_renovations(Profile.upgrades)
##   shell.get_surface_material(HouseShell.SurfaceKind.FLOOR)
##
## Dependencies: WorldUVMesh, ShellRenovation, UpgradeLevels, HouseLayout,
##               PlaceholderMesh3D (fallback materials), Palette
@tool
class_name HouseShell
extends Node3D

enum SurfaceKind { INSIDE_WALL, OUTSIDE_WALL, FLOOR, CEILING, FRAME, ROOF }

## Walls reach this far below the floor so no gap shows at the ground line.
const FOOTING_DEPTH: float = 0.05
## Faces this far beyond floor_rect count as the outside of the house.
const OUTSIDE_TOLERANCE: float = 0.01

## The walls, doors, windows, floor and floor openings as one resource (a
## HouseLayout: the cabin or the full house). Set, it fills the lists below,
## which then aren't stored in the scene.
@export var layout: HouseLayout:
	set(value):
		layout = value
		if value != null:
			_take_layout(value)
		notify_property_list_changed()
## Wall segments (x1, z1, x2, z2) on the floor plane; must be axis-aligned.
@export var walls: Array[Vector4] = []:
	set(value):
		walls = value
		_queue_rebuild()
## Door gaps (x1, z1, x2, z2) lying on a wall line.
@export var doors: Array[Vector4] = []:
	set(value):
		doors = value
		_queue_rebuild()
## Window gaps (x1, z1, x2, z2) lying on a wall line.
@export var windows: Array[Vector4] = []:
	set(value):
		windows = value
		_queue_rebuild()
## Interior floor (and ceiling) rectangle: position = (min x, min z).
@export var floor_rect: Rect2 = Rect2(-5.0, -5.0, 10.0, 10.0):
	set(value):
		floor_rect = value
		_queue_rebuild()
## Openings cut out of the floor (x, z rects): the stairwell down to the cellar.
@export var floor_openings: Array[Rect2] = []:
	set(value):
		floor_openings = value
		_queue_rebuild()
## Openings cut out of the ceiling: a cellar's stairwell up into the house.
@export var ceiling_openings: Array[Rect2] = []:
	set(value):
		ceiling_openings = value
		_queue_rebuild()
@export var wall_height: float = 2.6
@export var wall_thickness: float = 0.16
@export var door_height: float = 2.1
@export var window_sill: float = 1.0
@export var window_top: float = 2.1
@export var has_ceiling: bool = true

@export_group("Frames")
## Width of the wooden frame around every door and window (0 = no frames).
@export var frame_width: float = 0.07
## How far a frame stands out of the wall on each side.
@export var frame_protrusion: float = 0.015

@export_group("Roof")
@export var has_roof: bool = true
## Height of the ridge above the top of the walls.
@export var roof_rise: float = 2.0
## How far the roof reaches past the outside of the walls.
@export var roof_overhang: float = 0.4
@export var roof_thickness: float = 0.14

@export_group("Materials")
## Shared materials from Assets/Materials; uv1_scale = 1 / tile size in meters.
@export var inside_wall_material: Material
@export var outside_wall_material: Material
@export var floor_material: Material
@export var ceiling_material: Material
@export var frame_material: Material
@export var roof_material: Material

@export_group("Renovations")
## Better materials per renovation level (walls, floor, facade, roof...).
@export var renovations: Array[ShellRenovation] = []

@export_group("Fallback colors")
@export var wall_color: Color = Palette.SURFACE_RAISED
@export var floor_color: Color = Palette.STROKE
@export var ceiling_color: Color = Palette.SURFACE
@export var frame_color: Color = Palette.STROKE
@export var roof_color: Color = Palette.WORLD_DETAIL

var _is_rebuild_queued: bool = false
var _surfaces: Dictionary[SurfaceKind, SurfaceTool] = {}
## Materials set by renovations, in place of the exported ones.
var _material_overrides: Dictionary[SurfaceKind, Material] = {}
## Where each non-empty surface ended up in the shell mesh.
var _surface_indices: Dictionary[SurfaceKind, int] = {}
var _shell_mesh: ArrayMesh = null


func _ready() -> void:
	rebuild()


## Drops the generated geometry and builds it again from the lists.
func rebuild() -> void:
	_is_rebuild_queued = false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_surfaces.clear()
	for kind: SurfaceKind in SurfaceKind.values():
		_surfaces[kind] = WorldUVMesh.begin_surface()
	for floor_piece: Rect2 in WorldUVMesh.subtract_rects(floor_rect, floor_openings):
		_add_slab(_surfaces[SurfaceKind.FLOOR], floor_piece, 0.0, WorldUVMesh.Face.POSITIVE_Y)
	if has_ceiling:
		for ceiling_piece: Rect2 in WorldUVMesh.subtract_rects(floor_rect, ceiling_openings):
			_add_slab(_surfaces[SurfaceKind.CEILING], ceiling_piece, wall_height, WorldUVMesh.Face.NEGATIVE_Y)
	for wall: Vector4 in walls:
		_build_wall(wall)
	if has_roof:
		_build_roof()
	_shell_mesh = ArrayMesh.new()
	_surface_indices.clear()
	for kind: SurfaceKind in SurfaceKind.values():
		var surface_count: int = _shell_mesh.get_surface_count()
		WorldUVMesh.commit_surface(_surfaces[kind], _shell_mesh, _get_material(kind))
		if _shell_mesh.get_surface_count() > surface_count:
			_surface_indices[kind] = surface_count
	_surfaces.clear()
	var shell: MeshInstance3D = MeshInstance3D.new()
	shell.name = "ShellMesh"
	shell.mesh = _shell_mesh
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)


## Puts every renovated surface in the look its upgrade's bought level gives
## (the exported shabby material at level 0).
func apply_renovations(upgrade_levels: UpgradeLevels) -> void:
	for renovation: ShellRenovation in renovations:
		if renovation != null:
			set_surface_material(renovation.surface, renovation.get_material(upgrade_levels.get_level(renovation.upgrade_id)))


## Takes [param new_layout]'s walls, doors, windows, floor and floor
## openings and rebuilds once, right away (the house grows from the cabin).
func apply_layout(new_layout: HouseLayout) -> void:
	# The setters would queue a rebuild each.
	_is_rebuild_queued = true
	layout = new_layout
	rebuild()


func _take_layout(source: HouseLayout) -> void:
	walls = source.walls
	doors = source.doors
	windows = source.windows
	floor_rect = source.floor_rect
	floor_openings = source.floor_openings


func _validate_property(property: Dictionary) -> void:
	# A layout is the source: its lists are shown but not stored twice.
	if layout != null and property.name in [&"walls", &"doors", &"windows", &"floor_rect", &"floor_openings"]:
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY


## Gives one surface [param material] in place of its exported one; null
## brings the exported material back. Swaps the material only (no rebuild).
func set_surface_material(kind: SurfaceKind, material: Material) -> void:
	if material != null:
		_material_overrides[kind] = material
	else:
		_material_overrides.erase(kind)
	if _shell_mesh != null and _surface_indices.has(kind):
		_shell_mesh.surface_set_material(_surface_indices[kind], _get_material(kind))


## The material a surface shows right now (renovated or exported).
func get_surface_material(kind: SurfaceKind) -> Material:
	return _get_material(kind)


## A horizontal face over [param area] (x, z) at [param height].
func _add_slab(surface_tool: SurfaceTool, area: Rect2, height: float, face: WorldUVMesh.Face) -> void:
	var center: Vector3 = Vector3(area.get_center().x, height, area.get_center().y)
	WorldUVMesh.add_box_face(surface_tool, center, Vector3(area.size.x, 0.0, area.size.y), face)


func _queue_rebuild() -> void:
	if is_inside_tree() and not _is_rebuild_queued:
		_is_rebuild_queued = true
		rebuild.call_deferred()


func _get_material(kind: SurfaceKind) -> Material:
	if _material_overrides.has(kind):
		return _material_overrides[kind]
	match kind:
		SurfaceKind.INSIDE_WALL:
			return inside_wall_material if inside_wall_material != null else PlaceholderMesh3D.get_shared_material(wall_color)
		SurfaceKind.OUTSIDE_WALL:
			if outside_wall_material != null:
				return outside_wall_material
			return _get_material(SurfaceKind.INSIDE_WALL)
		SurfaceKind.FLOOR:
			return floor_material if floor_material != null else PlaceholderMesh3D.get_shared_material(floor_color)
		SurfaceKind.CEILING:
			return ceiling_material if ceiling_material != null else PlaceholderMesh3D.get_shared_material(ceiling_color)
		SurfaceKind.ROOF:
			return roof_material if roof_material != null else PlaceholderMesh3D.get_shared_material(roof_color)
		_:
			return frame_material if frame_material != null else PlaceholderMesh3D.get_shared_material(frame_color)


func _build_wall(wall: Vector4) -> void:
	var runs_along_x: bool = is_equal_approx(wall.y, wall.w)
	var line_value: float = wall.y if runs_along_x else wall.x
	var start: float = minf(wall.x, wall.z) if runs_along_x else minf(wall.y, wall.w)
	var end: float = maxf(wall.x, wall.z) if runs_along_x else maxf(wall.y, wall.w)
	# Gaps on this wall: [from, to, bottom, top], sorted along the wall.
	var gaps: Array[Vector4] = []
	for door: Vector4 in doors:
		var door_span: Vector2 = _get_span_on_line(door, runs_along_x, line_value)
		if door_span != Vector2.INF:
			gaps.append(Vector4(door_span.x, door_span.y, 0.0, door_height))
	for window: Vector4 in windows:
		var window_span: Vector2 = _get_span_on_line(window, runs_along_x, line_value)
		if window_span != Vector2.INF:
			gaps.append(Vector4(window_span.x, window_span.y, window_sill, window_top))
	gaps.sort_custom(func(first: Vector4, second: Vector4) -> bool: return first.x < second.x)
	# Wall ends run on by half a thickness so corners and T-joints close up.
	var half_thickness: float = wall_thickness * 0.5
	# A frame covers the faces that line an opening, so those are left out.
	var has_frames: bool = frame_width > 0.0
	var start_face: WorldUVMesh.Face = WorldUVMesh.Face.NEGATIVE_X if runs_along_x else WorldUVMesh.Face.NEGATIVE_Z
	var end_face: WorldUVMesh.Face = WorldUVMesh.Face.POSITIVE_X if runs_along_x else WorldUVMesh.Face.POSITIVE_Z
	var below_window_hidden: Array[WorldUVMesh.Face] = []
	var above_gap_hidden: Array[WorldUVMesh.Face] = []
	if has_frames:
		below_window_hidden.append(WorldUVMesh.Face.POSITIVE_Y)
		above_gap_hidden.append(WorldUVMesh.Face.NEGATIVE_Y)
	var cursor: float = start - half_thickness
	var is_after_gap: bool = false
	for gap: Vector4 in gaps:
		var gap_start: float = clampf(gap.x, start, end)
		var gap_end: float = clampf(gap.y, start, end)
		if gap_start > cursor:
			_add_wall_piece(runs_along_x, line_value, cursor, gap_start, 0.0, wall_height, _get_hidden_ends(has_frames and is_after_gap, has_frames, start_face, end_face))
		if gap.z > 0.0:
			_add_wall_piece(runs_along_x, line_value, gap_start, gap_end, 0.0, gap.z, below_window_hidden)
		_add_wall_piece(runs_along_x, line_value, gap_start, gap_end, gap.w, wall_height, above_gap_hidden)
		_add_frame(runs_along_x, line_value, gap_start, gap_end, gap.z, gap.w)
		cursor = maxf(cursor, gap_end)
		is_after_gap = true
	if cursor < end:
		_add_wall_piece(runs_along_x, line_value, cursor, end + half_thickness, 0.0, wall_height, _get_hidden_ends(has_frames and is_after_gap, false, start_face, end_face))


## The end faces of a wall piece that a frame covers.
func _get_hidden_ends(is_start_hidden: bool, is_end_hidden: bool, start_face: WorldUVMesh.Face, end_face: WorldUVMesh.Face) -> Array[WorldUVMesh.Face]:
	var hidden_faces: Array[WorldUVMesh.Face] = []
	if is_start_hidden:
		hidden_faces.append(start_face)
	if is_end_hidden:
		hidden_faces.append(end_face)
	return hidden_faces


## The part of [param gap] along a wall line, or Vector2.INF when it isn't on it.
func _get_span_on_line(gap: Vector4, runs_along_x: bool, line_value: float) -> Vector2:
	if runs_along_x:
		if not is_equal_approx(gap.y, line_value) or not is_equal_approx(gap.w, line_value):
			return Vector2.INF
		return Vector2(minf(gap.x, gap.z), maxf(gap.x, gap.z))
	if not is_equal_approx(gap.x, line_value) or not is_equal_approx(gap.z, line_value):
		return Vector2.INF
	return Vector2(minf(gap.y, gap.w), maxf(gap.y, gap.w))


func _add_wall_piece(runs_along_x: bool, line_value: float, from_value: float, to_value: float, bottom: float, top: float, hidden_faces: Array[WorldUVMesh.Face]) -> void:
	var piece_bottom: float = -FOOTING_DEPTH if bottom <= 0.0 else bottom
	var length: float = to_value - from_value
	var height: float = top - piece_bottom
	if length <= 0.001 or height <= 0.001:
		return
	var center: Vector3 = _get_wall_point(runs_along_x, line_value, (from_value + to_value) * 0.5, piece_bottom + height * 0.5)
	var piece_size: Vector3 = _get_wall_box_size(runs_along_x, length, height, wall_thickness)
	for face: WorldUVMesh.Face in WorldUVMesh.ALL_FACES:
		if hidden_faces.has(face):
			continue
		# The underside only shows above an opening, the top only below a
		# window (the ceiling covers the rest).
		if face == WorldUVMesh.Face.NEGATIVE_Y and bottom <= 0.0:
			continue
		if face == WorldUVMesh.Face.POSITIVE_Y and has_ceiling and top >= wall_height:
			continue
		var face_center: Vector3 = WorldUVMesh.get_face_center(center, piece_size, face)
		var kind: SurfaceKind = SurfaceKind.OUTSIDE_WALL if _is_outside(face_center) else SurfaceKind.INSIDE_WALL
		WorldUVMesh.add_box_face(_surfaces[kind], center, piece_size, face)


## A wooden frame lining a gap: two jambs, a head and (windows) a sill, set
## into the wall around the opening (the opening keeps its size) and standing
## a little proud of both wall faces.
func _add_frame(runs_along_x: bool, line_value: float, from_value: float, to_value: float, bottom: float, top: float) -> void:
	if frame_width <= 0.0:
		return
	var depth: float = wall_thickness + frame_protrusion * 2.0
	var jamb_bottom: float = -FOOTING_DEPTH if bottom <= 0.0 else bottom - frame_width
	var jamb_height: float = top + frame_width - jamb_bottom
	for jamb_middle: float in [from_value - frame_width * 0.5, to_value + frame_width * 0.5]:
		var jamb_center: Vector3 = _get_wall_point(runs_along_x, line_value, jamb_middle, jamb_bottom + jamb_height * 0.5)
		# Jambs get their grain running up, like real door and window casings.
		WorldUVMesh.add_box(_surfaces[SurfaceKind.FRAME], jamb_center, _get_wall_box_size(runs_along_x, frame_width, jamb_height, depth), [WorldUVMesh.Face.NEGATIVE_Y], true)
	var span: float = to_value - from_value
	var middle: float = (from_value + to_value) * 0.5
	WorldUVMesh.add_box(_surfaces[SurfaceKind.FRAME], _get_wall_point(runs_along_x, line_value, middle, top + frame_width * 0.5), _get_wall_box_size(runs_along_x, span, frame_width, depth))
	if bottom > 0.0:
		WorldUVMesh.add_box(_surfaces[SurfaceKind.FRAME], _get_wall_point(runs_along_x, line_value, middle, bottom - frame_width * 0.5), _get_wall_box_size(runs_along_x, span, frame_width, depth))


func _get_wall_point(runs_along_x: bool, line_value: float, along: float, height: float) -> Vector3:
	return Vector3(along, height, line_value) if runs_along_x else Vector3(line_value, height, along)


func _get_wall_box_size(runs_along_x: bool, length: float, height: float, depth: float) -> Vector3:
	return Vector3(length, height, depth) if runs_along_x else Vector3(depth, height, length)


func _is_outside(point: Vector3) -> bool:
	return point.x < floor_rect.position.x - OUTSIDE_TOLERANCE or point.x > floor_rect.end.x + OUTSIDE_TOLERANCE \
		or point.z < floor_rect.position.y - OUTSIDE_TOLERANCE or point.z > floor_rect.end.y + OUTSIDE_TOLERANCE


## A gable roof over the outside of the walls: two sloped slabs meeting at a
## ridge along X, wooden eaves (fascia, verges, undersides) and brick gables
## closing the ends. The attic above the ceiling stays empty.
func _build_roof() -> void:
	var half_thickness: float = wall_thickness * 0.5
	var outer: Rect2 = floor_rect.grow(half_thickness)
	var ridge_z: float = outer.get_center().y
	var slope: float = roof_rise / (outer.size.y * 0.5)
	var ridge_y: float = wall_height + roof_rise
	var eave_y: float = wall_height - roof_overhang * slope
	var left: float = outer.position.x - roof_overhang
	var right: float = outer.end.x + roof_overhang
	var lift: Vector3 = Vector3.UP * roof_thickness
	for eave_z: float in [outer.position.y - roof_overhang, outer.end.y + roof_overhang]:
		var outward: Vector3 = Vector3(0.0, 1.0, signf(eave_z - ridge_z))
		var ridge_left: Vector3 = Vector3(left, ridge_y, ridge_z)
		var ridge_right: Vector3 = Vector3(right, ridge_y, ridge_z)
		var eave_left: Vector3 = Vector3(left, eave_y, eave_z)
		var eave_right: Vector3 = Vector3(right, eave_y, eave_z)
		_add_facing_polygon(SurfaceKind.ROOF, [ridge_left + lift, ridge_right + lift, eave_right + lift, eave_left + lift], outward)
		_add_facing_polygon(SurfaceKind.FRAME, [ridge_left, ridge_right, eave_right, eave_left], -outward)
		_add_facing_polygon(SurfaceKind.FRAME, [eave_left, eave_right, eave_right + lift, eave_left + lift], Vector3(0.0, 0.0, outward.z))
		for verge_x: float in [left, right]:
			var ridge_point: Vector3 = Vector3(verge_x, ridge_y, ridge_z)
			var eave_point: Vector3 = Vector3(verge_x, eave_y, eave_z)
			_add_facing_polygon(SurfaceKind.FRAME, [ridge_point, ridge_point + lift, eave_point + lift, eave_point], Vector3(signf(verge_x - outer.get_center().x), 0.0, 0.0))
	for gable_x: float in [outer.position.x, outer.end.x]:
		var gable: Array[Vector3] = [Vector3(gable_x, wall_height, outer.position.y), Vector3(gable_x, ridge_y, ridge_z), Vector3(gable_x, wall_height, outer.end.y)]
		_add_facing_polygon(SurfaceKind.OUTSIDE_WALL, gable, Vector3(signf(gable_x - outer.get_center().x), 0.0, 0.0))


## Adds a convex polygon to a surface, wound so its front faces [param outward].
func _add_facing_polygon(kind: SurfaceKind, corners: Array[Vector3], outward: Vector3) -> void:
	var points: PackedVector3Array = PackedVector3Array(corners)
	# WorldUVMesh treats the order as clockwise from the front; flip it when that front faces in.
	if (points[2] - points[0]).cross(points[1] - points[0]).dot(outward) < 0.0:
		points.reverse()
	WorldUVMesh.add_polygon(_surfaces[kind], points)

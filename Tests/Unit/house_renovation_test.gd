## Unit tests for how upgrades change the house's look: ShellRenovation
## (a surface's material per renovation level), HouseShell swapping those
## materials without a rebuild, and UpgradeLook (parts that show from a level
## and replace or restyle the old look).
##
## Dependencies: gdUnit4, ShellRenovation, HouseShell, UpgradeLevels, UpgradeLook
extends GdUnitTestSuite

const WALLS_ID: StringName = &"house_walls"


func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _make_renovation(surface: HouseShell.SurfaceKind, materials: Array[Material]) -> ShellRenovation:
	var renovation: ShellRenovation = ShellRenovation.new()
	renovation.upgrade_id = WALLS_ID
	renovation.surface = surface
	renovation.level_materials = materials
	return renovation


func _make_levels(level: int) -> UpgradeLevels:
	var levels: UpgradeLevels = UpgradeLevels.new(null)
	levels.from_dict({WALLS_ID: level})
	return levels


## A one-room shell with a floor, walls and a ceiling, built without a tree.
func _make_shell() -> HouseShell:
	var shell: HouseShell = auto_free(HouseShell.new()) as HouseShell
	shell.walls = [Vector4(-2.0, -2.0, 2.0, -2.0), Vector4(-2.0, 2.0, 2.0, 2.0), Vector4(-2.0, -2.0, -2.0, 2.0), Vector4(2.0, -2.0, 2.0, 2.0)]
	shell.floor_rect = Rect2(-2.0, -2.0, 4.0, 4.0)
	shell.has_roof = false
	shell.inside_wall_material = _make_material(Color.DARK_OLIVE_GREEN)
	shell.outside_wall_material = _make_material(Color.FIREBRICK)
	shell.rebuild()
	return shell


func _get_shell_mesh(shell: HouseShell) -> ArrayMesh:
	return (shell.get_child(0) as MeshInstance3D).mesh as ArrayMesh


func test_renovation_keeps_the_shabby_look_at_level_zero() -> void:
	var patched: Material = _make_material(Color.GRAY)
	var renovation: ShellRenovation = _make_renovation(HouseShell.SurfaceKind.INSIDE_WALL, [patched])
	assert_object(renovation.get_material(0)).is_null()
	assert_object(_make_renovation(HouseShell.SurfaceKind.INSIDE_WALL, []).get_material(2)).is_null()


func test_renovation_picks_the_material_of_each_level() -> void:
	var patched: Material = _make_material(Color.GRAY)
	var painted: Material = _make_material(Color.WHEAT)
	var renovation: ShellRenovation = _make_renovation(HouseShell.SurfaceKind.INSIDE_WALL, [patched, painted])
	assert_object(renovation.get_material(1)).is_same(patched)
	assert_object(renovation.get_material(2)).is_same(painted)
	assert_object(renovation.get_material(5)).is_same(painted)


func test_renovation_can_skip_a_level() -> void:
	var painted: Material = _make_material(Color.WHEAT)
	var renovation: ShellRenovation = _make_renovation(HouseShell.SurfaceKind.CEILING, [null, painted])
	assert_object(renovation.get_material(1)).is_null()
	assert_object(renovation.get_material(2)).is_same(painted)


func test_shell_swaps_a_surface_material_and_back() -> void:
	var shell: HouseShell = _make_shell()
	var shabby: Material = shell.inside_wall_material
	var painted: Material = _make_material(Color.WHEAT)
	var mesh_before: ArrayMesh = _get_shell_mesh(shell)
	shell.set_surface_material(HouseShell.SurfaceKind.INSIDE_WALL, painted)
	assert_object(shell.get_surface_material(HouseShell.SurfaceKind.INSIDE_WALL)).is_same(painted)
	# Swapped in place: the same mesh, its inside-wall surface now painted.
	assert_object(_get_shell_mesh(shell)).is_same(mesh_before)
	var surface_materials: Array[Material] = []
	for surface_index: int in mesh_before.get_surface_count():
		surface_materials.append(mesh_before.surface_get_material(surface_index))
	assert_bool(surface_materials.has(painted)).is_true()
	assert_bool(surface_materials.has(shabby)).is_false()
	shell.set_surface_material(HouseShell.SurfaceKind.INSIDE_WALL, null)
	assert_object(shell.get_surface_material(HouseShell.SurfaceKind.INSIDE_WALL)).is_same(shabby)


func test_shell_applies_renovations_by_upgrade_level() -> void:
	var shell: HouseShell = _make_shell()
	var shabby: Material = shell.inside_wall_material
	var patched: Material = _make_material(Color.GRAY)
	var painted: Material = _make_material(Color.WHEAT)
	shell.renovations = [_make_renovation(HouseShell.SurfaceKind.INSIDE_WALL, [patched, painted])]
	shell.apply_renovations(_make_levels(1))
	assert_object(shell.get_surface_material(HouseShell.SurfaceKind.INSIDE_WALL)).is_same(patched)
	shell.apply_renovations(_make_levels(2))
	assert_object(shell.get_surface_material(HouseShell.SurfaceKind.INSIDE_WALL)).is_same(painted)
	shell.apply_renovations(_make_levels(0))
	assert_object(shell.get_surface_material(HouseShell.SurfaceKind.INSIDE_WALL)).is_same(shabby)


func test_renovated_material_survives_a_rebuild() -> void:
	var shell: HouseShell = _make_shell()
	var painted: Material = _make_material(Color.WHEAT)
	shell.set_surface_material(HouseShell.SurfaceKind.INSIDE_WALL, painted)
	shell.rebuild()
	assert_object(shell.get_surface_material(HouseShell.SurfaceKind.INSIDE_WALL)).is_same(painted)


func test_look_shows_from_its_level_and_hides_the_old_look() -> void:
	var look: UpgradeLook = auto_free(UpgradeLook.new()) as UpgradeLook
	var old_look: Node3D = auto_free(Node3D.new()) as Node3D
	look.min_level = 2
	look.replaces = [old_look]
	look.apply_level(1)
	assert_bool(look.visible).is_false()
	assert_bool(look.is_shown()).is_false()
	assert_bool(old_look.visible).is_true()
	look.apply_level(2)
	assert_bool(look.visible).is_true()
	assert_bool(old_look.visible).is_false()
	look.apply_level(0)
	assert_bool(look.visible).is_false()
	assert_bool(old_look.visible).is_true()


func test_look_restyles_meshes_and_restores_them() -> void:
	var look: UpgradeLook = auto_free(UpgradeLook.new()) as UpgradeLook
	var board: MeshInstance3D = auto_free(MeshInstance3D.new()) as MeshInstance3D
	var bare: Material = _make_material(Color.SLATE_GRAY)
	var wood: Material = _make_material(Color.SADDLE_BROWN)
	board.material_override = bare
	look.restyled = [board]
	look.restyle_material = wood
	look.apply_level(1)
	assert_object(board.material_override).is_same(wood)
	look.apply_level(0)
	assert_object(board.material_override).is_same(bare)


func test_look_level_threshold() -> void:
	assert_bool(UpgradeLook.is_reached(0, 1)).is_false()
	assert_bool(UpgradeLook.is_reached(1, 1)).is_true()
	assert_bool(UpgradeLook.is_reached(3, 2)).is_true()


func test_subtracting_a_hole_leaves_four_pieces_with_the_same_area() -> void:
	var floor_area: Rect2 = Rect2(0.0, 0.0, 6.0, 4.0)
	var stairwell: Rect2 = Rect2(1.0, 1.0, 3.0, 1.0)
	var pieces: Array[Rect2] = WorldUVMesh.subtract_rects(floor_area, [stairwell])
	assert_int(pieces.size()).is_equal(4)
	var covered: float = 0.0
	for piece: Rect2 in pieces:
		covered += piece.get_area()
		assert_bool(piece.intersection(stairwell).has_area()).is_false()
	assert_float(covered).is_equal_approx(floor_area.get_area() - stairwell.get_area(), 0.0001)


func test_a_hole_on_the_edge_or_outside_cuts_less() -> void:
	var floor_area: Rect2 = Rect2(0.0, 0.0, 6.0, 4.0)
	assert_int(WorldUVMesh.subtract_rects(floor_area, [Rect2(0.0, 0.0, 2.0, 1.0)]).size()).is_equal(2)
	var untouched: Array[Rect2] = WorldUVMesh.subtract_rects(floor_area, [Rect2(10.0, 10.0, 1.0, 1.0)])
	assert_int(untouched.size()).is_equal(1)
	assert_bool(untouched[0] == floor_area).is_true()


func test_placement_moves_the_target_until_the_upgrade_is_bought() -> void:
	var root: Node3D = auto_free(Node3D.new()) as Node3D
	var board: Node3D = Node3D.new()
	var cabin_spot: Node3D = Node3D.new()
	# Placements work on global transforms: in the tree.
	add_child(root)
	root.add_child(board)
	root.add_child(cabin_spot)
	board.position = Vector3(4.9, 1.5, 0.0)
	cabin_spot.position = Vector3(0.9, 1.5, 0.0)
	var placement: UpgradePlacement = auto_free(UpgradePlacement.new()) as UpgradePlacement
	placement.target = board
	placement.before = cabin_spot
	placement.apply_level(0)
	assert_vector(board.position).is_equal(Vector3(0.9, 1.5, 0.0))
	assert_bool(placement.is_home()).is_false()
	placement.apply_level(1)
	assert_vector(board.position).is_equal(Vector3(4.9, 1.5, 0.0))
	assert_bool(placement.is_home()).is_true()


func test_look_also_shows_nodes_elsewhere() -> void:
	var look: UpgradeLook = auto_free(UpgradeLook.new()) as UpgradeLook
	var sign_node: Node3D = auto_free(Node3D.new()) as Node3D
	look.also_shows = [sign_node]
	look.apply_level(0)
	assert_bool(sign_node.visible).is_false()
	look.apply_level(1)
	assert_bool(sign_node.visible).is_true()


func test_shell_takes_a_layout_and_builds_it() -> void:
	var shell: HouseShell = _make_shell()
	var cabin: HouseLayout = HouseLayout.new()
	cabin.walls = [Vector4(-1.0, -1.0, 1.0, -1.0), Vector4(-1.0, 1.0, 1.0, 1.0)]
	cabin.floor_rect = Rect2(-1.0, -1.0, 2.0, 2.0)
	shell.apply_layout(cabin)
	assert_int(shell.walls.size()).is_equal(2)
	assert_bool(shell.floor_rect == Rect2(-1.0, -1.0, 2.0, 2.0)).is_true()
	assert_int(_get_shell_mesh(shell).get_surface_count()).is_greater(0)

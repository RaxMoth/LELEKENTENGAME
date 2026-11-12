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

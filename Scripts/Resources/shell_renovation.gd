## How one surface of the house shell (inside walls, floor, facade, roof...)
## looks at each level of a renovation upgrade: level 0 keeps the shell's own
## shabby material, level 1 the first material here ("patched up"), level 2
## the second ("well kept") and so on. A level past the end keeps the last
## material. HouseShell.apply_renovations() reads these.
##
##   var renovation: ShellRenovation = ShellRenovation.new()
##   renovation.upgrade_id = Types.UPGRADE_RENOVATE_WALLS
##   renovation.surface = HouseShell.SurfaceKind.INSIDE_WALL
##   renovation.level_materials = [patched_plaster, painted_plaster]
##   renovation.get_material(2)   # painted_plaster; null at level 0
##
## Dependencies: HouseShell (SurfaceKind)
class_name ShellRenovation
extends Resource

## The renovation upgrade (UpgradeData.id) that changes this surface.
@export var upgrade_id: StringName = &""
## Which part of the shell it changes.
@export var surface: HouseShell.SurfaceKind = HouseShell.SurfaceKind.INSIDE_WALL
## The surface's material from level 1 on (index 0 = level 1). Shared
## materials from Assets/Materials (uv1_scale = 1 / tile size in meters).
@export var level_materials: Array[Material] = []


## The material for [param level], or null when the shell's own (shabby)
## material stays: level 0, or nothing set for this renovation.
func get_material(level: int) -> Material:
	if level <= 0 or level_materials.is_empty():
		return null
	return level_materials[mini(level, level_materials.size()) - 1]

## A part of the house that shows once an upgrade reaches a level: iron
## straps on a reinforced front door, a steel door frame, real shelves and
## crates in the stash room, the rooms of the extended house. Its children
## appear at [member min_level] (and hide again below it), together with
## [member also_shows] (nodes elsewhere, like room signs); [member replaces]
## are hidden in their place (the shabby look it replaces), and
## [member restyled] meshes take [member restyle_material] instead of their own.
##
## One node per look and level: three straps that come one per level are
## three UpgradeLooks with min_level 1, 2 and 3. Applied by the House level
## like every UpgradeReaction.
##
##   look.apply_level(Profile.upgrades.get_level(look.upgrade_id))
##
## Dependencies: UpgradeReaction
class_name UpgradeLook
extends UpgradeReaction

## The bought level from which this look shows.
@export_range(1, 10) var min_level: int = 1
## Shown only while this look is not (the old look it replaces).
@export var replaces: Array[Node3D] = []
## Shown together with this look, though elsewhere in the scene.
@export var also_shows: Array[Node3D] = []
## Meshes that take restyle_material once the look shows (their own
## material comes back below min_level).
@export var restyled: Array[GeometryInstance3D] = []
## The material the restyled meshes take while the look shows.
@export var restyle_material: Material

## Each restyled mesh's own material_override, kept while the look shows.
var _base_materials: Dictionary[GeometryInstance3D, Material] = {}
var _is_shown: bool = true


## Shows or hides the look for the upgrade's bought [param level].
func apply_level(level: int) -> void:
	_is_shown = is_reached(level, min_level)
	visible = _is_shown
	for old_look: Node3D in replaces:
		if old_look != null:
			old_look.visible = not _is_shown
	for companion: Node3D in also_shows:
		if companion != null:
			companion.visible = _is_shown
	for mesh: GeometryInstance3D in restyled:
		if mesh == null:
			continue
		if not _base_materials.has(mesh):
			_base_materials[mesh] = mesh.material_override
		mesh.material_override = restyle_material if _is_shown and restyle_material != null else _base_materials[mesh]


## True once the last apply_level() reached min_level.
func is_shown() -> bool:
	return _is_shown


## True when a [param level] of the upgrade shows a look that needs [param needed_level].
static func is_reached(level: int, needed_level: int) -> bool:
	return level >= needed_level

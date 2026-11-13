## Base of every part of the house that reacts to the level of one upgrade:
## a look that shows (UpgradeLook), a thing that moves when the house grows
## (UpgradePlacement), the house's stages (HouseStages). The House level
## calls apply_level() on every reaction in Types.GROUP_UPGRADE_LOOK
## whenever upgrades change (also on a co-op guest, from the host's levels),
## so a reaction never polls.
##
##   reaction.apply_level(Profile.upgrades.get_level(reaction.upgrade_id))
##
## Dependencies: Types autoload
class_name UpgradeReaction
extends Node3D

## The upgrade (UpgradeData.id) this reacts to.
@export var upgrade_id: StringName = &""


func _ready() -> void:
	add_to_group(Types.GROUP_UPGRADE_LOOK)


## @virtual Shows the state for the upgrade's bought [param level].
func apply_level(_level: int) -> void:
	pass

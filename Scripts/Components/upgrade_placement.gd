## Moves a thing somewhere else until an upgrade is bought: the office board
## hangs on the cabin's wall until the house is extended, then it moves to
## the office. Below [member min_level] the target stands at
## [member before]'s transform; from it on, at its own place in the scene.
## Applied by the House level like every UpgradeReaction.
##
##   placement.apply_level(Profile.upgrades.get_level(placement.upgrade_id))
##
## Dependencies: UpgradeReaction
class_name UpgradePlacement
extends UpgradeReaction

## What moves.
@export var target: Node3D
## The bought level from which the target stands at its own place.
@export_range(1, 10) var min_level: int = 1
## Where the target stands below min_level (a Marker3D).
@export var before: Node3D

## The target's own place in its parent, kept the first time it moves.
var _home: Transform3D = Transform3D.IDENTITY
var _has_home: bool = false


func apply_level(level: int) -> void:
	if target == null or before == null:
		return
	if not _has_home:
		_home = target.transform
		_has_home = true
	if level < min_level:
		target.global_transform = before.global_transform
	else:
		target.transform = _home


## True while the target stands at its own place (not at [member before]).
func is_home() -> bool:
	return not _has_home or target.transform.is_equal_approx(_home)

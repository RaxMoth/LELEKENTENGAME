## How big the house is: level 0 of "Extend the House" is the one-room
## cabin a new operation starts in (the left side of the house: front door,
## lab corner, sales window, stash and office board in one room), level 1
## the full house with the office, the stash room and the hallway. The
## cellar comes after, as its own upgrade. Hands the stage's HouseLayout to
## the HouseShell (it rebuilds) and swaps the stage's walk regions in the
## player's WalkableArea, leaving what the fronts added (porch, garden,
## doorway) alone. Things that live elsewhere in the cabin move with
## UpgradePlacements; rooms that only the house has show with UpgradeLooks.
##
## Dependencies: UpgradeReaction, HouseLayout, HouseShell, WalkableArea
class_name HouseStages
extends UpgradeReaction

@export var shell: HouseShell
@export var walkable: WalkableArea
## The layout for each level (index = level; higher levels keep the last).
@export var layouts: Array[HouseLayout] = []

var _current: HouseLayout = null


func apply_level(level: int) -> void:
	if layouts.is_empty():
		return
	var layout: HouseLayout = layouts[clampi(level, 0, layouts.size() - 1)]
	if layout == _current:
		return
	if _current != null:
		for region: Rect2 in _current.walk_regions:
			walkable.remove_region(region)
	_current = layout
	shell.apply_layout(layout)
	for region: Rect2 in layout.walk_regions:
		walkable.add_region(region)


## The stage the house is at now (null before the first apply_level()).
func get_layout() -> HouseLayout:
	return _current

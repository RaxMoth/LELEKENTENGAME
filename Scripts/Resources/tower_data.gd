## Definition of one thing the player builds in the front garden (a turret,
## a heavy gun, a barricade): what it costs, how often it can be built and
## which scene to place.
##
## Dependencies: none
class_name TowerData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Tower"
@export var icon: Texture2D
## Tint for the (white) icon — a Palette color.
@export var icon_color: Color = Color.WHITE
## Scene whose root extends LaneDefender.
@export var scene: PackedScene
## Cash per build.
@export var cost: int = 100
## Seconds before another one can be built.
@export var cooldown_seconds: float = 5.0
@export var max_health: float = 120.0
## UpgradeData id that unlocks it (empty = available from the start).
@export var unlock_upgrade_id: StringName = &""

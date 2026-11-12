## Definition of one placeable defender in a lane-defense game: what it
## costs, how often it can be placed and which scene to build.
##
## Dependencies: none
class_name DefenderData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Defender"
@export var icon: Texture2D
## Tint for the (white) icon — a Palette color.
@export var icon_color: Color = Color.WHITE
## Scene whose root extends LaneDefender.
@export var scene: PackedScene
@export var cost: int = 50
## Seconds before another one can be placed.
@export var cooldown_seconds: float = 5.0
@export var max_health: float = 120.0

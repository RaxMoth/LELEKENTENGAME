## An opening every GroundPlane3D leaves out: where a stairwell goes down
## into the cellar, the lawn and the town's asphalt (which both run under
## the house) must not cover it. Place it at the opening's center; its size
## is the opening in X / Z. Ground planes look the holes up when they build,
## so the area that owns the opening needs no reference to the grounds.
##
## Dependencies: none
@tool
class_name GroundHole
extends Node3D

## Ground planes find holes in this group.
const GROUP_NAME: StringName = &"ground_hole"

## Width (X) and depth (Z) of the opening in meters.
@export var size: Vector2 = Vector2.ONE


func _notification(what: int) -> void:
	# Before any _ready(): ground planes in the same scene see it when they build.
	if what == NOTIFICATION_ENTER_TREE:
		add_to_group(GROUP_NAME)


## The opening in world X / Z (position = min x, min z).
func get_world_rect() -> Rect2:
	return Rect2(Vector2(global_position.x, global_position.z) - size * 0.5, size)

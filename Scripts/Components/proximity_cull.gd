## Hides a room's contents while the camera is far from it, to save draw
## calls (the renderer has no occlusion culling here): the cellar is drawn
## only while the player is down there or near its stairwell. Only drawing
## changes — machines keep working, furniture keeps blocking (WalkBlocker
## looks through it). Works the same for a co-op guest; checks a few times
## a second.
##
## Dependencies: none
class_name ProximityCull
extends Node3D

## Seconds between checks (the camera rarely needs it sooner).
const CHECK_SECONDS: float = 0.2

## Shown while the camera is this close (meters, across the floor) to [member center] ...
@export var radius: float = 5.0
## ... the middle of what it hides, in this node's space (the stairwell).
@export var center: Vector3 = Vector3.ZERO
## ... or while the camera is below this height (inside the cellar).
@export var below_height: float = -0.3

var _seconds_until_check: float = 0.0


func _process(delta: float) -> void:
	_seconds_until_check -= delta
	if _seconds_until_check > 0.0:
		return
	_seconds_until_check = CHECK_SECONDS
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		visible = is_near(camera.global_position, global_transform * center, radius, below_height)


## True when [param eye] is within [param reach] of [param middle] across
## the floor, or lower than [param floor_below].
static func is_near(eye: Vector3, middle: Vector3, reach: float, floor_below: float) -> bool:
	return eye.y < floor_below or Vector2(eye.x - middle.x, eye.z - middle.z).length() <= reach

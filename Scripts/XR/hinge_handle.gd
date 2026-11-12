## A handle on something that swings on a hinge (a door, a gate, a cabinet).
## Grip it with a hand and move the hand around the hinge: the handle reports
## the angle the hand pulls the leaf to, relative to where the grab started,
## so a distance grab along the beam works too. It never follows the hand
## itself — the owner rotates the leaf (and the handle with it).
## In the flat simulator a click on the handle asks to open / close instead.
##
##   handle.hinge_origin = hinge                       # the Node3D the leaf turns around
##   handle.angle_dragged.connect(door.drag_to_angle)  # degrees, + = toward the hinge's +Z side
##   handle.toggle_requested.connect(door.toggle_open)
##   handle.released.connect(func(_item: Grabbable) -> void: door.end_drag())
##
## Dependencies: Grabbable
class_name HingeHandle
extends Grabbable

## A hand pulled the leaf to [param angle_degrees] (owner clamps and applies).
signal angle_dragged(angle_degrees: float)
## A click without a tracked hand (flat simulator): open if closed, close if open.
signal toggle_requested

## The node whose Y axis is the hinge; its parent's frame is the reference.
var hinge_origin: Node3D = null
## The leaf's current angle (the owner keeps it up to date), in degrees.
var current_angle_degrees: float = 0.0

var _grab_hand_angle: float = 0.0
var _grab_leaf_angle: float = 0.0


func attach_to(new_holder: Node3D) -> void:
	super(new_holder)
	if not _is_tracked_hand(new_holder):
		# The flat cursor can't swing anything: treat the click as "use the
		# door" and let go at once (the rig forgets items without a holder).
		holder = null
		set_process(false)
		toggle_requested.emit()
		released.emit(self)
		return
	_grab_hand_angle = _get_hand_angle()
	_grab_leaf_angle = current_angle_degrees


func _process(_delta: float) -> void:
	if holder == null or not is_instance_valid(holder) or hinge_origin == null:
		set_process(false)
		return
	var swing: float = angle_difference(deg_to_rad(_grab_hand_angle), deg_to_rad(_get_hand_angle()))
	angle_dragged.emit(_grab_leaf_angle + rad_to_deg(swing))


## Stays on its door when let go anywhere.
func drop_nowhere() -> void:
	detach()


## Angle of the hand around the hinge in the hinge parent's floor plane
## (degrees; + turns from the leaf's +X toward +Z).
func _get_hand_angle() -> float:
	var reference: Node3D = hinge_origin.get_parent_node_3d()
	var to_hand: Vector3 = holder.global_position - hinge_origin.global_position
	if reference != null:
		to_hand = reference.global_transform.basis.inverse() * to_hand
	return rad_to_deg(atan2(to_hand.z, to_hand.x))


static func _is_tracked_hand(node: Node3D) -> bool:
	return node != null and node.get_parent() is XRController3D

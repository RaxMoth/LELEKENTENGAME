## The model of a melee weapon in the player's hand (the knife, the axe),
## animated on every strike: it draws back, chops forward past rest and
## settles again. Forward is -Z with the handle in the fist at the origin;
## %Tip marks the far end of the edge (shown for where a swing reaches).
##
##   model.play_use()
##
## Dependencies: WeaponModel
class_name MeleeModel
extends WeaponModel

## Degrees the blade draws back before the strike...
@export var draw_back_degrees: float = 22.0
## ...and chops forward past its rest.
@export var chop_degrees: float = 50.0
## Seconds the whole strike takes.
@export var strike_seconds: float = 0.32
## In the flat simulator's view the blade is held up like this (degrees:
## tilted up, turned, rolled), so its edge shows above the hand.
@export var flat_pose_degrees: Vector3 = Vector3(40.0, 0.0, -15.0)

var _tween: Tween

@onready var _body: Node3D = %Body
@onready var _tip: Marker3D = %Tip


func play_use() -> void:
	if _tween != null:
		_tween.kill()
	_body.rotation.x = 0.0
	_tween = create_tween()
	_tween.tween_property(_body, "rotation:x", deg_to_rad(draw_back_degrees), strike_seconds * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_body, "rotation:x", -deg_to_rad(chop_degrees), strike_seconds * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_body, "rotation:x", 0.0, strike_seconds * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func get_tip_position() -> Vector3:
	return _tip.global_position


func use_flat_pose(is_flat: bool) -> void:
	rotation_degrees = flat_pose_degrees if is_flat else Vector3.ZERO

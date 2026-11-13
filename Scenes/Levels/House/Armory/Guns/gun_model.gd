## The model of a gun in the player's hand (pistol, SMG, shotgun, rifle),
## animated on every shot: the body kicks back and up, a muzzle flash
## blinks, and the gun's own moving part cycles — the pistol's slide, the
## shotgun's pump, the rifle's bolt, the SMG's charging handle. An empty gun
## only clicks. Forward is -Z, the grip hangs down; the FrontGarden puts it
## in the off hand (or the flat view's lower right).
##
##   model.play_shot()
##   var muzzle: Vector3 = model.get_muzzle_position()
##
## Dependencies: WeaponModel
class_name GunModel
extends WeaponModel

## The part that moves with every shot (slide, pump, bolt).
@export var moving_part: Node3D
## How far (local) the moving part travels back...
@export var moving_travel: Vector3 = Vector3(0.0, 0.0, 0.03)
## ...and how long one cycle takes.
@export var cycle_seconds: float = 0.1
## Kick of one shot: meters back and degrees up.
@export var recoil_distance: float = 0.025
@export var recoil_degrees: float = 6.0
## Seconds the muzzle flash shows.
@export var flash_seconds: float = 0.05

var _rest_position: Vector3 = Vector3.ZERO
var _kick_tween: Tween
var _cycle_tween: Tween

@onready var _body: Node3D = %Body
@onready var _muzzle: Marker3D = %Muzzle
@onready var _flash: Node3D = %Flash


func _ready() -> void:
	_flash.visible = false
	if moving_part != null:
		_rest_position = moving_part.position


func get_muzzle_position() -> Vector3:
	return _muzzle.global_position


func play_use() -> void:
	play_shot()


func play_empty() -> void:
	play_dry_fire()


func get_tip_position() -> Vector3:
	return get_muzzle_position()


## One shot: kick, flash and the moving part cycling.
func play_shot() -> void:
	if _kick_tween != null:
		_kick_tween.kill()
	_body.position = Vector3.ZERO
	_body.rotation = Vector3.ZERO
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_kick_tween = create_tween()
	_kick_tween.set_parallel(true)
	_kick_tween.tween_property(_body, "position:z", recoil_distance, 0.035).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kick_tween.tween_property(_body, "rotation:x", deg_to_rad(recoil_degrees), 0.035).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kick_tween.tween_callback(func() -> void: _flash.visible = false).set_delay(flash_seconds)
	_kick_tween.chain().tween_property(_body, "position:z", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_kick_tween.tween_property(_body, "rotation:x", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_cycle(moving_travel)


## Pulled the trigger on an empty gun: just the moving part twitches.
func play_dry_fire() -> void:
	_cycle(moving_travel * 0.25)


func _cycle(travel: Vector3) -> void:
	if moving_part == null:
		return
	if _cycle_tween != null:
		_cycle_tween.kill()
	moving_part.position = _rest_position
	_cycle_tween = create_tween()
	_cycle_tween.tween_property(moving_part, "position", _rest_position + travel, cycle_seconds * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cycle_tween.tween_property(moving_part, "position", _rest_position, cycle_seconds * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

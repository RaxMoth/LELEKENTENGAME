## Shooting tower: fires bolts down its lane while an attacker is ahead of
## it. The light turret is quick and weak (junkies); the heavy gun is slow,
## strong and pierces armor (cops). Bolts are pooled and hit by lane math.
##
## Dependencies: LaneDefender, LaneBoard, LaneBolt, Pools, Audio autoloads, SfxSynth
class_name Turret
extends LaneDefender

const BOLT_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/LaneBolt.tscn")

@export var bolt_damage: float = 14.0
@export var fire_interval_seconds: float = 0.9
@export var pierces_armor: bool = false
## Seconds between "is anything in my lane?" checks while idle.
@export var scan_interval_seconds: float = 0.25

var _seconds_until_shot: float = 0.0

@onready var _muzzle: Marker3D = %Muzzle
@onready var _head: Node3D = %Head


func _on_placed() -> void:
	_seconds_until_shot = scan_interval_seconds


func _physics_process(delta: float) -> void:
	if board == null or not is_alive():
		return
	_seconds_until_shot -= delta
	if _seconds_until_shot > 0.0:
		return
	if not board.has_enemy_ahead(get_lane(), global_position.z):
		_seconds_until_shot = scan_interval_seconds
		return
	_seconds_until_shot = fire_interval_seconds
	var bolt: LaneBolt = Pools.spawn(BOLT_SCENE, board.get_effects_root(), _muzzle.global_position) as LaneBolt
	bolt.launch(board, get_lane(), bolt_damage, pierces_armor)
	Audio.play_sfx_at(SfxSynth.get_preset(&"shoot"), _muzzle.global_position, 0.08, -8.0)
	var tween: Tween = create_tween()
	tween.tween_property(_head, "position:z", 0.08, 0.04)
	tween.tween_property(_head, "position:z", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

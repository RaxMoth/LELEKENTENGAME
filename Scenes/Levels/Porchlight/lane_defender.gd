## Base for everything the player places on a LaneBoard cell. On its own it
## is a plain blocker (the Stonecap wall); Sparkbloom and Boltbloom extend it.
## Attackers stop at its cell and chew through its HealthComponent.
##
## Dependencies: LaneBoard, DefenderData, HealthComponent, Audio autoload, SfxSynth
class_name LaneDefender
extends Node3D

signal destroyed(defender: LaneDefender)

const PLACE_SECONDS: float = 0.25
const REMOVE_SECONDS: float = 0.18

var data: DefenderData = null
var board: LaneBoard = null
## Vector2i(lane, column) on the board.
var cell: Vector2i = LaneGrid.INVALID_CELL

var _punch_tween: Tween

@onready var health_component: HealthComponent = %HealthComponent
@onready var _visual: Node3D = %Visual


func _ready() -> void:
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)


## Called by the board right after the defender entered the tree.
func setup(defender_data: DefenderData, owner_board: LaneBoard, board_cell: Vector2i) -> void:
	data = defender_data
	board = owner_board
	cell = board_cell
	health_component.revive(defender_data.max_health)
	_visual.scale = Vector3.ONE * 0.01
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE, PLACE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_on_placed()


func get_lane() -> int:
	return cell.x


func is_alive() -> bool:
	return not health_component.is_dead


## @virtual The defender is on the board and may start working.
func _on_placed() -> void:
	pass


func _on_damaged(_damage_info: DamageInfo) -> void:
	if _punch_tween != null:
		_punch_tween.kill()
	_punch_tween = create_tween()
	_punch_tween.tween_property(_visual, "scale", Vector3(1.1, 0.88, 1.1), 0.05)
	_punch_tween.tween_property(_visual, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_died() -> void:
	set_physics_process(false)
	destroyed.emit(self)
	Audio.play_sfx_at(SfxSynth.get_preset(&"hit"), global_position, 0.1)
	if _punch_tween != null:
		_punch_tween.kill()
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, REMOVE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Placed rarely by hand, so a defender is a normal instance, not a pooled one.
	tween.tween_callback(queue_free)

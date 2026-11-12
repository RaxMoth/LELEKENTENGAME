## Economy defender: grows a spark every few seconds. The spark is handed to
## the board, which floats it above the bloom for the player to catch.
##
## Dependencies: LaneDefender, LaneBoard
class_name Sparkbloom
extends LaneDefender

@export var spark_value: int = 25
@export var spark_interval_seconds: float = 9.0
## The first spark comes sooner so a fresh bloom feels alive.
@export var first_spark_seconds: float = 4.0
## Height above the ground where the spark appears.
@export var spark_height: float = 0.95

var _seconds_until_spark: float = 0.0

@onready var _bulb: Node3D = %Bulb


func _on_placed() -> void:
	_seconds_until_spark = first_spark_seconds


func _physics_process(delta: float) -> void:
	if board == null or not is_alive():
		return
	_seconds_until_spark -= delta
	if _seconds_until_spark > 0.0:
		return
	_seconds_until_spark = spark_interval_seconds
	board.release_spark(global_position + Vector3(0.0, spark_height, 0.0), spark_value)
	var tween: Tween = create_tween()
	tween.tween_property(_bulb, "scale", Vector3.ONE * 1.3, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bulb, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## One group of enemies inside a wave.
##
## Dependencies: none
class_name WaveEntry
extends Resource

@export var enemy_scene: PackedScene
@export var count: int = 5
@export var spawn_interval: float = 0.5
@export var start_delay: float = 0.0

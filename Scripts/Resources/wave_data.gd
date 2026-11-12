## A wave for WaveSpawner: groups of enemies plus scaling values.
##
## Dependencies: none
class_name WaveData
extends Resource

@export var entries: Array[WaveEntry] = []
@export var delay_before_wave: float = 2.0
@export var health_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
## Rewards granted when the wave is cleared (handled by the level script).
@export var clear_rewards: Dictionary[StringName, int] = {}


func get_total_enemy_count() -> int:
	var total_count: int = 0
	for entry: WaveEntry in entries:
		total_count += entry.count
	return total_count

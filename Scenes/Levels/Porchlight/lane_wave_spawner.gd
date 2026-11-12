## WaveSpawner for a LaneBoard: every enemy of a wave enters through the far
## end of a lane instead of a 2D marker, ring or path.
##
## Dependencies: WaveSpawner, LaneBoard
class_name LaneWaveSpawner
extends WaveSpawner

@export var board: LaneBoard


func _create_enemy(enemy_scene: PackedScene) -> Node:
	return board.spawn_enemy(enemy_scene)

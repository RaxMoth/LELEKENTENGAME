## Pooled projectile of a Turret: flies down one lane (toward -Z) and hits
## the first attacker it reaches. Hit detection is lane math on the board,
## so hundreds of bolts cost no physics.
##
## Dependencies: LaneBoard, LaneEnemy, PopEffect3D, Pools autoload, Palette
class_name LaneBolt
extends Node3D

@export var speed: float = 11.0

var _board: LaneBoard = null
var _lane: int = 0
var _damage: float = 0.0
var _pierces_armor: bool = false


func launch(board: LaneBoard, lane: int, damage: float, pierces_armor: bool = false) -> void:
	_board = board
	_lane = lane
	_damage = damage
	_pierces_armor = pierces_armor


func _on_pool_despawned() -> void:
	_board = null


func _physics_process(delta: float) -> void:
	if _board == null or Pools.is_in_pool(self):
		return
	var previous_z: float = global_position.z
	global_position.z -= speed * delta
	var enemy: LaneEnemy = _board.find_enemy_between(_lane, previous_z, global_position.z)
	if enemy != null:
		enemy.take_hit(_damage, self, true, _pierces_armor)
		PopEffect3D.spawn(Vector3(global_position.x, global_position.y, enemy.global_position.z + enemy.hit_radius), Palette.PROJECTILE, 0.35, _board.get_effects_root())
		Pools.despawn(self)
	elif global_position.z < _board.get_spawn_z():
		Pools.despawn(self)

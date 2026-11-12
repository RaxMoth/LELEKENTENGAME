## Spawns loot from a LootTable (call drop() when the owner dies).
##
## Dependencies: LootTable, Pools, Global autoloads
class_name LootDropComponent
extends Node

@export var loot_table: LootTable
@export var scatter_radius: float = 24.0


func drop(drop_position: Vector2) -> void:
	if loot_table == null:
		return
	for loot_scene: PackedScene in loot_table.roll():
		var scatter_offset: Vector2 = Vector2.from_angle(randf() * TAU) * randf() * scatter_radius
		Pools.spawn.call_deferred(loot_scene, Global.get_world_root(), drop_position + scatter_offset)

## A possible drop inside a LootTable.
##
## Dependencies: none
class_name LootEntry
extends Resource

@export var scene: PackedScene
@export_range(0.0, 1.0) var drop_chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 1

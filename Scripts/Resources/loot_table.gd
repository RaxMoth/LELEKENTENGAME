## Collection of LootEntry rolls used by LootDropComponent.
##
## Dependencies: none
class_name LootTable
extends Resource

@export var entries: Array[LootEntry] = []


## Returns the scenes to spawn for one roll (duplicates = multiple drops).
func roll() -> Array[PackedScene]:
	var dropped_scenes: Array[PackedScene] = []
	for entry: LootEntry in entries:
		if entry.scene == null or randf() > entry.drop_chance:
			continue
		for drop_index: int in randi_range(entry.min_count, entry.max_count):
			dropped_scenes.append(entry.scene)
	return dropped_scenes

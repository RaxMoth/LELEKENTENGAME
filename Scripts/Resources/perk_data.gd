## Temporary in-run upgrade (roguelite level-up cards, power-ups...).
##
## Dependencies: none
class_name PerkData
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var modifiers: Array[StatModifier] = []
## 0 = unlimited.
@export var max_stacks: int = 5
@export var weight: float = 1.0

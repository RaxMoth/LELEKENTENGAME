## Base class for an active ability with a cooldown. Subclass it and override
## activate() — the resource is shared, so keep per-use state in the caster.
##
## Dependencies: none
class_name AbilityData
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export var icon: Texture2D
@export var cooldown_seconds: float = 5.0


## @virtual Performs the ability. Return false to cancel (no cooldown is started).
func activate(_caster: Node2D) -> bool:
	return true

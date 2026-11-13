## Something besides a raider that the player's weapons hit (the cabin's
## rats): it sits in Types.GROUP_HIT_TARGET and offers a hit sphere. Fists,
## blades and guns check these along their strike or shot (FrontGarden),
## anywhere in the house.
##
##   class_name Rat extends HitTarget
##   func take_hit(amount: float, _source: Node = null) -> void: _die()
##
## Dependencies: Types autoload
class_name HitTarget
extends Node3D


func _ready() -> void:
	add_to_group(Types.GROUP_HIT_TARGET)


## @virtual Center of the sphere hits land in.
func get_hit_center() -> Vector3:
	return global_position


## @virtual Radius of that sphere (meters).
func get_hit_radius() -> float:
	return 0.1


## @virtual False once it can't be hit any more.
func is_alive() -> bool:
	return is_visible_in_tree()


## @virtual Takes a hit of [param amount] damage from [param _source].
func take_hit(_amount: float, _source: Node = null) -> void:
	pass

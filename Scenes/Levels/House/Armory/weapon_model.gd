## The model of a weapon in the player's hand: a gun (GunModel) or a knife /
## axe (MeleeModel). The FrontGarden puts it in the off hand (or the flat
## view's lower right) and plays it on every use. Forward is -Z, the handle
## or grip in the fist at the origin. A level-only base class, kept with the
## armory that sells the weapons.
##
##   model.play_use()                              # a shot or a strike
##   var tip: Vector3 = model.get_tip_position()   # muzzle or blade tip
##
## Dependencies: none
class_name WeaponModel
extends Node3D


## @virtual One use: a shot, or a strike with a blade.
func play_use() -> void:
	pass


## @virtual Used without ammo (a gun only clicks).
func play_empty() -> void:
	pass


## @virtual Where the weapon acts: a gun's muzzle, a blade's tip.
func get_tip_position() -> Vector3:
	return global_position


## @virtual How it sits in the flat simulator's view (true) or in a hand
## (false): a blade is held up there so its edge shows; a gun points ahead
## either way.
func use_flat_pose(_is_flat: bool) -> void:
	pass

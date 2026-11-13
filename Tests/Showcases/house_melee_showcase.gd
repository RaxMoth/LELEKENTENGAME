## Close combat: the axe in hand (bought after the knife), a cop right in
## front of the player in the front room.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_melee`.
##
## Dependencies: HouseLevel, FrontGarden, Armory, Raider, AttackerDirector, Profile autoload
extends RefCounted

const COP: PackedScene = preload("res://Scenes/Levels/House/Garden/Cop.tscn")
## The weapon in hand for the picture.
const WEAPON_ID: StringName = &"axe"


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var armory: Armory = level.get_front(Armory) as Armory
	(level.get_front(SalesWindow) as SalesWindow).flow.is_active = false
	garden.director.is_active = false
	# Owned straight away (no purchase announcement in the picture).
	for weapon_id: StringName in [&"knife", &"axe"]:
		Profile.armory.loadout.buy_weapon(armory.weapon_catalog.find_weapon(weapon_id))
	Profile.armory.loadout.equip(armory.weapon_catalog.find_weapon(WEAPON_ID))
	var cop: Raider = garden.director.spawn_raider(COP)
	cop.global_position = Vector3(0.1, 0.0, -4.3)
	cop.rotation.y = 0.0
	cop.freeze()

## The phone's weapons app: the house showcase with every gun bought and
## the phone open on its weapons list.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_phone_weapons`.
##
## Dependencies: house_showcase.gd, HouseLevel, FrontGarden, Phone, PhoneScreen
extends RefCounted

const HOUSE_SHOWCASE: Script = preload("res://Tests/Showcases/house_showcase.gd")


static func apply(scene: Node) -> void:
	HOUSE_SHOWCASE.call("apply", scene)
	var level: HouseLevel = scene as HouseLevel
	var garden: FrontGarden = level.get_front(FrontGarden) as FrontGarden
	var loadout: WeaponLoadout = Profile.armory.loadout
	for weapon: WeaponData in garden.weapon_catalog.weapons:
		if not loadout.owns(weapon):
			loadout.buy_weapon(weapon)
	garden.phone.open()
	garden.phone.get_screen().show_page(PhoneScreen.Page.WEAPONS)

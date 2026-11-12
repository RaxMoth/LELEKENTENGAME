## The armory: a terminal on the front room's back wall where the cash made
## selling buys guns and ammo for the raid at the end of every 3-day cycle.
## The bought gun is equipped here and fired from the front room or porch
## (the FrontGarden reads Profile.armory). Part of the defense area; it reads
## and writes only the Operation (cash) and Profile.armory.
##
## Dependencies: HouseFront, ArmoryBoard, WeaponCatalog, WeaponData,
##               WeaponLoadout, WorldScreen, Operation, Profile, Audio autoloads, Palette
class_name Armory
extends HouseFront

## Every gun the terminal sells, in shop order.
@export var weapon_catalog: WeaponCatalog

var _is_board_dirty: bool = false

@onready var _screen: WorldScreen = %ArmoryScreen


func _on_setup() -> void:
	var board: ArmoryBoard = get_board()
	board.set_catalog(weapon_catalog)
	board.weapon_buy_requested.connect(buy_weapon)
	board.weapon_equip_requested.connect(equip_weapon)
	board.ammo_buy_requested.connect(buy_ammo)
	# Shots change the ammo count many times a second: redraw the board at
	# the display refresh rate instead of on every shot.
	Profile.armory.loadout.changed.connect(_on_loadout_changed)


func _refresh_displays() -> void:
	update_screen_rendering(_screen)
	if _is_board_dirty and _screen.is_rendering():
		_is_board_dirty = false
		get_board().refresh()


func get_board() -> ArmoryBoard:
	return _screen.content as ArmoryBoard


func get_screen() -> WorldScreen:
	return _screen


## Buys a gun for cash and puts it in the player's hand. Returns true on success.
func buy_weapon(weapon: WeaponData) -> bool:
	var loadout: WeaponLoadout = Profile.armory.loadout
	if weapon == null or loadout.owns(weapon) or not context.operation.spend_cash(weapon.cost, "weapons"):
		Audio.play_ui(Audio.UI_ERROR)
		return false
	loadout.buy_weapon(weapon)
	loadout.equip(weapon)
	Audio.play_ui(Audio.UI_CONFIRM)
	announcement_requested.emit(tr("%s bought") % tr(weapon.display_name), Palette.SUCCESS)
	get_board().refresh()
	return true


## Puts an owned gun in the player's hand.
func equip_weapon(weapon: WeaponData) -> bool:
	if not Profile.armory.loadout.equip(weapon):
		Audio.play_ui(Audio.UI_ERROR)
		return false
	Audio.play_ui(Audio.UI_CLICK)
	get_board().refresh()
	return true


## Buys one ammo box for an owned gun. Returns true on success.
func buy_ammo(weapon: WeaponData) -> bool:
	var loadout: WeaponLoadout = Profile.armory.loadout
	if not loadout.can_add_ammo(weapon) or not context.operation.spend_cash(weapon.ammo_pack_cost, "ammo"):
		Audio.play_ui(Audio.UI_ERROR)
		return false
	loadout.add_ammo(weapon, weapon.ammo_pack_size)
	Audio.play_ui(Audio.UI_CONFIRM)
	get_board().refresh()
	return true


func get_status_line() -> String:
	var weapon: WeaponData = Profile.armory.loadout.get_equipped(weapon_catalog)
	if weapon == null:
		return ""
	if weapon.has_unlimited_ammo:
		return tr(weapon.display_name)
	return "%s %d" % [tr(weapon.display_name), Profile.armory.loadout.get_ammo(weapon)]


func _on_loadout_changed() -> void:
	_is_board_dirty = true

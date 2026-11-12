## The armory terminal's screen: every gun with its price, the one in hand,
## and ammo boxes for the guns the player owns. Shown in the world on a
## WorldScreen. It displays Profile data and emits signals; the Armory front
## does the buying.
##
## Dependencies: WeaponCatalog, WeaponData, WeaponLoadout, ShopItemRow,
##               IconLabel, NumberFormat, Profile, Events autoloads
class_name ArmoryBoard
extends Control

signal weapon_buy_requested(weapon: WeaponData)
signal weapon_equip_requested(weapon: WeaponData)
signal ammo_buy_requested(weapon: WeaponData)

const ROW_SCENE: PackedScene = preload("res://Scenes/Menus/Shop/ShopItemRow.tscn")
const CASH_ICON: Texture2D = preload("res://Assets/Icons/cash.svg")

var _catalog: WeaponCatalog = null
var _is_refresh_queued: bool = false
## Rows by key ("weapon:<id>" / "ammo:<id>") for tests and tutorials.
var _rows_by_key: Dictionary[String, ShopItemRow] = {}

@onready var _cash_label: IconLabel = %CashLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _equipped_label: Label = %EquippedLabel


func _ready() -> void:
	Events.currency_changed.connect(func(_id: StringName, _amount: int, _delta: int) -> void: queue_refresh())


## Called by the Armory front with the guns it sells.
func set_catalog(catalog: WeaponCatalog) -> void:
	_catalog = catalog
	refresh()


## Rebuilds the rows and the header numbers.
func refresh() -> void:
	_is_refresh_queued = false
	_cash_label.text = NumberFormat.compact(Profile.wallet.get_amount(Types.CURRENCY_CASH))
	Global.remove_all_children(_rows)
	_rows_by_key.clear()
	if _catalog == null:
		return
	var loadout: WeaponLoadout = Profile.armory.loadout
	var equipped: WeaponData = loadout.get_equipped(_catalog)
	for weapon: WeaponData in _catalog.weapons:
		_add_weapon_row(weapon, loadout, weapon == equipped)
		if loadout.owns(weapon) and not weapon.has_unlimited_ammo:
			_add_ammo_row(weapon, loadout)
	if equipped != null:
		_equipped_label.text = tr("In hand: %s · %s") % [tr(equipped.display_name), _describe_ammo(equipped, loadout)]


## Many changes in one frame (a shot, a sale) rebuild the rows once.
func queue_refresh() -> void:
	if not _is_refresh_queued:
		_is_refresh_queued = true
		refresh.call_deferred()


## The row of a gun ("weapon") or its ammo box ("ammo"), or null.
func get_row(kind: String, weapon_id: StringName) -> ShopItemRow:
	return _rows_by_key.get("%s:%s" % [kind, weapon_id])


func _add_weapon_row(weapon: WeaponData, loadout: WeaponLoadout, is_equipped: bool) -> void:
	var row: ShopItemRow = _create_row("weapon:%s" % weapon.id)
	var detail: String = _describe_stats(weapon)
	if is_equipped:
		row.setup(tr(weapon.display_name), tr(weapon.description), detail, tr("In hand"), false)
	elif loadout.owns(weapon):
		row.setup(tr(weapon.display_name), tr(weapon.description), detail, tr("Equip"), true)
		row.buy_pressed.connect(func() -> void: weapon_equip_requested.emit(weapon))
	else:
		var can_afford: bool = Profile.wallet.can_afford(Types.CURRENCY_CASH, weapon.cost)
		row.setup(tr(weapon.display_name), tr(weapon.description), detail, NumberFormat.with_separators(weapon.cost), can_afford, CASH_ICON)
		row.buy_pressed.connect(func() -> void: weapon_buy_requested.emit(weapon))


func _add_ammo_row(weapon: WeaponData, loadout: WeaponLoadout) -> void:
	var row: ShopItemRow = _create_row("ammo:%s" % weapon.id)
	var detail: String = tr("+%d rounds · %d / %d carried") % [weapon.ammo_pack_size, loadout.get_ammo(weapon), weapon.max_ammo]
	var is_enabled: bool = loadout.can_add_ammo(weapon) and Profile.wallet.can_afford(Types.CURRENCY_CASH, weapon.ammo_pack_cost)
	row.setup(tr("%s ammo") % tr(weapon.display_name), "", detail, NumberFormat.with_separators(weapon.ammo_pack_cost), is_enabled, CASH_ICON)
	row.buy_pressed.connect(func() -> void: ammo_buy_requested.emit(weapon))


func _create_row(key: String) -> ShopItemRow:
	var row: ShopItemRow = ROW_SCENE.instantiate() as ShopItemRow
	_rows.add_child(row)
	_rows_by_key[key] = row
	return row


func _describe_stats(weapon: WeaponData) -> String:
	var shots_per_second: float = 1.0 / maxf(0.01, weapon.fire_interval_seconds)
	var stats: String = tr("Damage %d · %.1f shots/s · Range %d m") % [roundi(weapon.damage), shots_per_second, roundi(weapon.range_meters)]
	if weapon.pierces_armor:
		stats += " · " + tr("Pierces armor")
	return stats


func _describe_ammo(weapon: WeaponData, loadout: WeaponLoadout) -> String:
	if weapon.has_unlimited_ammo:
		return tr("unlimited ammo")
	return tr("%d rounds") % loadout.get_ammo(weapon)

## The tower depot's screen in the garden: every kind of tower with what it
## does and its price, how many stand already, and how to build one (carry
## the kit outside, point at the ground, pull the trigger). Shown on a
## WorldScreen; it emits signals, the TowerField does the buying.
##
## Dependencies: TowerCatalog, TowerData, ShopItemRow, IconLabel, NumberFormat,
##               Profile, Events autoloads
class_name TowerBoard
extends Control

signal kit_buy_requested(tower_data: TowerData)

const ROW_SCENE: PackedScene = preload("res://Scenes/Menus/Shop/ShopItemRow.tscn")
const CASH_ICON: Texture2D = preload("res://Assets/Icons/cash.svg")

var _catalog: TowerCatalog = null
var _is_refresh_queued: bool = false
var _rows_by_id: Dictionary[StringName, ShopItemRow] = {}

@onready var _cash_label: IconLabel = %CashLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _count_label: Label = %CountLabel


func _ready() -> void:
	Events.currency_changed.connect(func(_id: StringName, _amount: int, _delta: int) -> void: queue_refresh())


## Called by the TowerField with the towers it sells.
func set_catalog(catalog: TowerCatalog) -> void:
	_catalog = catalog
	refresh()


func refresh() -> void:
	_is_refresh_queued = false
	_cash_label.text = NumberFormat.compact(Profile.wallet.get_amount(Types.CURRENCY_CASH))
	_count_label.text = tr("Towers standing: %d") % Profile.towers.placements.get_count()
	Global.remove_all_children(_rows)
	_rows_by_id.clear()
	if _catalog == null:
		return
	for tower: TowerData in _catalog.towers:
		var row: ShopItemRow = ROW_SCENE.instantiate() as ShopItemRow
		_rows.add_child(row)
		_rows_by_id[tower.id] = row
		var can_afford: bool = Profile.wallet.can_afford(Types.CURRENCY_CASH, tower.cost)
		row.setup(tr(tower.display_name), tr(tower.description), _describe(tower), NumberFormat.with_separators(tower.cost), can_afford, CASH_ICON)
		row.buy_pressed.connect(func() -> void: kit_buy_requested.emit(tower))


func queue_refresh() -> void:
	if not _is_refresh_queued:
		_is_refresh_queued = true
		refresh.call_deferred()


## The row of tower [param tower_id] (tests).
func get_row(tower_id: StringName) -> ShopItemRow:
	return _rows_by_id.get(tower_id)


func _describe(tower: TowerData) -> String:
	var stats: String = tr("Damage %d · Range %d m") % [roundi(tower.damage), roundi(tower.range_meters)]
	match tower.kind:
		TowerData.Kind.MORTAR:
			stats += " · " + tr("Blast %.1f m") % tower.splash_radius
		TowerData.Kind.BEAM:
			stats += " · " + tr("Heats up to ×%d") % roundi(tower.beam_max_multiplier)
		TowerData.Kind.SHOCK:
			stats += " · " + tr("Jumps to %d") % tower.chain_count
		_:
			stats += " · " + tr("%.1f shots/s") % (1.0 / maxf(0.01, tower.fire_interval_seconds))
	return stats

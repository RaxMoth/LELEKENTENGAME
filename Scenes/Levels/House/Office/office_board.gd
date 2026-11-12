## The office wall screen: spend cash on the five progression branches
## (production, sales, defense, workforce, house) and pay off the police.
## Shown in the world on a WorldScreen. It displays Profile data and emits
## signals; the level does the buying.
##
## Dependencies: UpgradeData, ShopItemRow, GameConfig, Profile, IconLabel,
##               NumberFormat, Events autoload
class_name OfficeBoard
extends Control

signal upgrade_requested(upgrade: UpgradeData)
signal bribe_requested

const ROW_SCENE: PackedScene = preload("res://Scenes/Menus/Shop/ShopItemRow.tscn")

var _branch: StringName = UpgradeData.BRANCHES[0]
var _tab_buttons: Dictionary[StringName, Button] = {}
var _bribe_cost: int = 0
var _heat: float = 0.0
var _is_refresh_queued: bool = false

@onready var _reputation_label: IconLabel = %ReputationLabel
@onready var _cash_label: IconLabel = %CashLabel
@onready var _tabs: HBoxContainer = %Tabs
@onready var _rows: VBoxContainer = %Rows
@onready var _heat_label: Label = %HeatLabel
@onready var _bribe_button: Button = %BribeButton


func _ready() -> void:
	for branch: StringName in UpgradeData.BRANCHES:
		var tab: Button = Button.new()
		tab.text = tr(UpgradeData.get_branch_title(branch))
		tab.custom_minimum_size = Vector2(0, 88)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(show_branch.bind(branch))
		_tabs.add_child(tab)
		_tab_buttons[branch] = tab
	Events.currency_changed.connect(func(_id: StringName, _amount: int, _delta: int) -> void: _queue_refresh())
	Events.upgrade_purchased.connect(func(_id: StringName, _level: int) -> void: _queue_refresh())
	Events.reputation_changed.connect(func(_reputation: int, _delta: int) -> void: _queue_refresh())
	show_branch(_branch)


func show_branch(branch: StringName) -> void:
	_branch = branch
	for tab_branch: StringName in _tab_buttons:
		_tab_buttons[tab_branch].theme_type_variation = &"SecondaryButton" if tab_branch == branch else &"GhostButton"
	refresh()


## Rebuilds the rows of the current branch and the header numbers.
func refresh() -> void:
	_is_refresh_queued = false
	_reputation_label.text = NumberFormat.with_separators(Profile.operation.reputation)
	_cash_label.text = NumberFormat.compact(Profile.wallet.get_amount(Types.CURRENCY_CASH))
	Global.remove_all_children(_rows)
	for upgrade: UpgradeData in GameConfig.get_default().upgrades:
		if upgrade.branch != _branch:
			continue
		var row: ShopItemRow = ROW_SCENE.instantiate() as ShopItemRow
		_rows.add_child(row)
		row.setup_upgrade(upgrade)
		row.buy_pressed.connect(func() -> void: upgrade_requested.emit(upgrade))
	_apply_heat()


func set_heat(heat: float, bribe_cost: int) -> void:
	if roundi(heat) == roundi(_heat) and bribe_cost == _bribe_cost:
		return
	_heat = heat
	_bribe_cost = bribe_cost
	_apply_heat()


## Branch tab button (tests and tutorials).
func get_tab(branch: StringName) -> Button:
	return _tab_buttons.get(branch)


## Many changes in one frame (a sale, wages, reputation) rebuild the rows once.
func _queue_refresh() -> void:
	if not _is_refresh_queued:
		_is_refresh_queued = true
		refresh.call_deferred()


func _apply_heat() -> void:
	_heat_label.text = tr("Police heat %d") % roundi(_heat)
	_bribe_button.text = tr("Bribe  $%s") % NumberFormat.with_separators(_bribe_cost)
	_bribe_button.disabled = _heat < 1.0 or Profile.wallet.get_amount(Types.CURRENCY_CASH) < _bribe_cost


func _on_bribe_button_pressed() -> void:
	bribe_requested.emit()

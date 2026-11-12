## The board above the garden gate, readable from the front windows: front
## door health, heat, cash and the tower cards. Choose a card, then point at
## a garden tile and pull the trigger to build. Shown in the world through a
## WorldScreen; it only displays state and emits a signal when a card is chosen.
##
## Dependencies: TowerCard, TowerData, IconLabel, NumberFormat, Palette
class_name BuildBoard
extends Control

signal tower_chosen(tower_index: int)

const CARD_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/TowerCard.tscn")

var _cards: Array[TowerCard] = []

@onready var _door_bar: ProgressBar = %DoorBar
@onready var _door_label: Label = %DoorLabel
@onready var _cash_label: IconLabel = %CashLabel
@onready var _heat_label: IconLabel = %HeatLabel
@onready var _hint_label: Label = %HintLabel
@onready var _card_row: HBoxContainer = %Cards


## Builds one card per tower, in order.
func set_towers(towers: Array[TowerData]) -> void:
	for card: TowerCard in _cards:
		card.queue_free()
	_cards.clear()
	for tower_index: int in towers.size():
		var card: TowerCard = CARD_SCENE.instantiate() as TowerCard
		_card_row.add_child(card)
		card.set_data(towers[tower_index])
		card.pressed.connect(func() -> void: tower_chosen.emit(tower_index))
		_cards.append(card)


func set_selected(tower_index: int) -> void:
	for card_index: int in _cards.size():
		_cards[card_index].set_selected(card_index == tower_index)


func set_cash(amount: int) -> void:
	_cash_label.text = NumberFormat.compact(amount)
	for card: TowerCard in _cards:
		card.set_affordable(amount >= card.data.cost)


func set_locked(tower_index: int, is_locked: bool) -> void:
	if tower_index >= 0 and tower_index < _cards.size():
		_cards[tower_index].set_locked(is_locked)


func set_door_health(ratio: float) -> void:
	_door_bar.value = ratio * 100.0
	_door_label.text = tr("Front door %d%%") % roundi(ratio * 100.0)


func set_heat(heat: float) -> void:
	_heat_label.text = str(roundi(heat))
	_heat_label.icon_color = Palette.DANGER if heat >= 50.0 else (Palette.WARNING if heat >= 25.0 else Palette.TEXT_MUTED)


func set_hint(hint_text: String) -> void:
	_hint_label.text = hint_text


func set_cooldown_ratio(tower_index: int, ratio: float) -> void:
	if tower_index >= 0 and tower_index < _cards.size():
		_cards[tower_index].set_cooldown_ratio(ratio)


func get_card_count() -> int:
	return _cards.size()


## Center of a card in this control's coordinates (tutorials, tests).
func get_card_center(tower_index: int) -> Vector2:
	var card: TowerCard = _cards[tower_index]
	return card.global_position + card.size * 0.5

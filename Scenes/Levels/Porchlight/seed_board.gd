## The scoreboard above the garden gate: wave progress, lives, sparks and the
## defender cards. Shown in the world through a WorldScreen, so it works the
## same in a headset and on a flat screen. Emits a signal when a card is
## chosen; it never runs game logic.
##
## Dependencies: SeedCard, DefenderData, IconLabel, NumberFormat, Palette
class_name SeedBoard
extends Control

signal seed_chosen(seed_index: int)

const CARD_SCENE: PackedScene = preload("res://Scenes/Levels/Porchlight/SeedCard.tscn")
const HEART_ICON: Texture2D = preload("res://Assets/Icons/heart.svg")
const HEART_SIZE: float = 48.0

var _cards: Array[SeedCard] = []
var _hearts: Array[TextureRect] = []

@onready var _wave_label: Label = %WaveLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _wave_bar: ProgressBar = %WaveBar
@onready var _heart_row: HBoxContainer = %Hearts
@onready var _sparks_label: IconLabel = %SparksLabel
@onready var _hint_label: Label = %HintLabel
@onready var _card_row: HBoxContainer = %Cards


## Builds one card per defender, in order.
func set_defenders(defenders: Array[DefenderData]) -> void:
	for card: SeedCard in _cards:
		card.queue_free()
	_cards.clear()
	for defender_index: int in defenders.size():
		var card: SeedCard = CARD_SCENE.instantiate() as SeedCard
		_card_row.add_child(card)
		card.set_data(defenders[defender_index])
		card.pressed.connect(func() -> void: seed_chosen.emit(defender_index))
		_cards.append(card)


func set_selected(seed_index: int) -> void:
	for card_index: int in _cards.size():
		_cards[card_index].set_selected(card_index == seed_index)


func set_sparks(amount: int) -> void:
	_sparks_label.text = str(amount)
	for card: SeedCard in _cards:
		card.set_affordable(amount >= card.data.cost)


func set_lives(current_lives: int, max_lives: int) -> void:
	while _hearts.size() < max_lives:
		var heart: TextureRect = TextureRect.new()
		heart.texture = HEART_ICON
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
		_heart_row.add_child(heart)
		_hearts.append(heart)
	for heart_index: int in _hearts.size():
		_hearts[heart_index].self_modulate = Palette.DANGER if heart_index < current_lives else Palette.STROKE


func set_wave(current_wave: int, total_waves: int) -> void:
	_wave_label.text = tr("Wave %d / %d") % [maxi(1, current_wave), total_waves]
	_wave_bar.max_value = maxi(1, total_waves)
	_wave_bar.value = current_wave


func set_score(score: int) -> void:
	_score_label.text = tr("Score %s") % NumberFormat.with_separators(score)


func set_hint(hint_text: String) -> void:
	_hint_label.text = hint_text


func set_cooldown_ratio(seed_index: int, ratio: float) -> void:
	if seed_index >= 0 and seed_index < _cards.size():
		_cards[seed_index].set_cooldown_ratio(ratio)


func get_card_count() -> int:
	return _cards.size()


## Center of a card in this control's coordinates (tutorial markers, tests).
func get_card_center(seed_index: int) -> Vector2:
	var card: SeedCard = _cards[seed_index]
	return card.global_position + card.size * 0.5

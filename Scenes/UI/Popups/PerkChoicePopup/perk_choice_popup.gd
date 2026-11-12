## "Choose 1 of N" card picker for roguelite level-ups, shrines, chests...
## Pauses the game while open and can't be dismissed without choosing.
##
## popup_data keys: title, subtitle, perks (Array[PerkData]), stacks (Dictionary id -> int)
## Result: the chosen PerkData.
##
## Dependencies: BasePopup
class_name PerkChoicePopup
extends BasePopup

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _card_list: VBoxContainer = %CardList


func _on_opened(data: Dictionary) -> void:
	_title_label.text = str(data.get("title", tr("Level Up!")))
	_subtitle_label.text = str(data.get("subtitle", tr("Choose an upgrade")))
	var stacks: Dictionary = data.get("stacks", {})
	var card_index: int = 0
	for perk: PerkData in data.get("perks", []):
		var card_button: Button = Button.new()
		card_button.custom_minimum_size = Vector2(0, 130)
		card_button.theme_type_variation = &"SecondaryButton"
		card_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var stack_count: int = int(stacks.get(perk.id, 0))
		var level_text: String = "  (Lv %d)" % (stack_count + 1) if stack_count > 0 else ""
		card_button.text = "%s%s\n%s" % [perk.title, level_text, perk.description]
		card_button.pressed.connect(close.bind(perk))
		_card_list.add_child(card_button)
		card_button.modulate.a = 0.0
		var tween: Tween = card_button.create_tween()
		tween.tween_interval(0.1 * card_index)
		tween.tween_property(card_button, "modulate:a", 1.0, 0.2)
		card_index += 1


func handle_back() -> void:
	pass

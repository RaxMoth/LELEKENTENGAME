## Horizontal list of rewards ("+20 [coin]   +1 [gem]"): currencies show their
## icon from GameConfig, other rewards (items) show their id as text.
##
##   reward_list.set_rewards(level_result.rewards)
##
## Dependencies: none
class_name RewardList
extends HBoxContainer

@export var icon_size: int = 44
@export var label_theme_type: StringName = &"HeaderLabel"


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_rewards(rewards: Dictionary[StringName, int]) -> void:
	Global.remove_all_children(self)
	for reward_id: StringName in rewards:
		var currency: CurrencyData = GameConfig.get_default().find_currency(reward_id)
		var amount_text: String = "+" + NumberFormat.compact(rewards[reward_id])
		var entry: IconLabel
		if currency != null and currency.icon != null:
			entry = IconLabel.create(currency.icon, amount_text, icon_size)
		else:
			entry = IconLabel.create(null, "%s %s" % [amount_text, reward_id.capitalize()], icon_size)
		entry.label_theme_type = label_theme_type
		add_child(entry)

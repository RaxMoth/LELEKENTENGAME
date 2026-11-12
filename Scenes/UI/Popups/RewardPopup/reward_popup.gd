## Shows a set of rewards with "Claim" and an optional rewarded-ad "Claim x2".
## The popup does not grant anything itself — the caller grants
## rewards * multiplier (the result), which keeps it reusable for daily
## rewards, offline earnings, chests, etc.
##
## popup_data keys: title, subtitle, rewards (Dictionary[StringName, int]), allow_double (bool)
## Result: int multiplier (1, or 2 after watching an ad).
##
## Dependencies: BasePopup, Ads autoload
class_name RewardPopup
extends BasePopup

const AD_PLACEMENT_DOUBLE: StringName = &"double_reward_popup"

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _rewards_row: HBoxContainer = %RewardsRow
@onready var _double_button: Button = %DoubleButton


func _on_opened(data: Dictionary) -> void:
	_title_label.text = str(data.get("title", ""))
	_subtitle_label.text = str(data.get("subtitle", ""))
	_subtitle_label.visible = not _subtitle_label.text.is_empty()
	_double_button.visible = bool(data.get("allow_double", false)) and Ads.is_rewarded_ready()
	var rewards: Dictionary = data.get("rewards", {})
	for reward_id: Variant in rewards:
		var tile: Control = _create_reward_tile(StringName(reward_id), int(rewards[reward_id]))
		_rewards_row.add_child(tile)
		TweenFX.bounce_in(tile)
	Audio.play_ui(Audio.UI_REWARD)


func handle_back() -> void:
	close(1)


func _create_reward_tile(reward_id: StringName, amount: int) -> Control:
	var tile: PanelContainer = PanelContainer.new()
	tile.theme_type_variation = &"CardPanel"
	tile.custom_minimum_size = Vector2(150, 150)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_child(column)
	var currency: CurrencyData = GameConfig.get_default().find_currency(reward_id)
	if currency != null and currency.icon != null:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = currency.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(64, 64)
		column.add_child(icon_rect)
	else:
		var name_label: Label = Label.new()
		name_label.text = currency.display_name if currency != null else String(reward_id).capitalize()
		name_label.theme_type_variation = &"SmallLabel"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
	var amount_label: Label = Label.new()
	amount_label.text = "x" + NumberFormat.compact(amount)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(amount_label)
	return tile


func _on_claim_button_pressed() -> void:
	close(1)


func _on_double_button_pressed() -> void:
	_double_button.disabled = true
	var was_rewarded: bool = await Ads.show_rewarded(AD_PLACEMENT_DOUBLE)
	close(2 if was_rewarded else 1)

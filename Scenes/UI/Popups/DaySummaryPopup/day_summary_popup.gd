## The end of a day in the house: what the shift brought in (cash, units
## sold and crafted, a beaten raid) or what losing it cost (the stash, the
## repairs), and one button into the next morning — or into the same day
## again after a loss. The house is the only world: there are no levels,
## stars or level select, just one day after the other.
##
##   await UI.open_popup(DAY_SUMMARY_POPUP, {DaySummaryPopup.KEY_DAY: 3, ...}).closed
##
## Dependencies: BasePopup, IconLabel, NumberFormat, Palette
class_name DaySummaryPopup
extends BasePopup

const KEY_DAY: String = "day"
const KEY_WON: String = "won"
const KEY_RAID_BEATEN: String = "raid_beaten"
const KEY_CASH_EARNED: String = "cash_earned"
const KEY_UNITS_SOLD: String = "units_sold"
const KEY_UNITS_CRAFTED: String = "units_crafted"
const KEY_UNITS_LOST: String = "units_lost"
const KEY_REPAIR_COST: String = "repair_cost"
const ROW_ICON_SIZE: int = 40
const CASH_ICON: Texture2D = preload("res://Assets/Icons/cash.svg")
const BAG_ICON: Texture2D = preload("res://Assets/Icons/bag.svg")
const BOX_ICON: Texture2D = preload("res://Assets/Icons/box.svg")
const SHIELD_ICON: Texture2D = preload("res://Assets/Icons/shield.svg")
const FLAME_ICON: Texture2D = preload("res://Assets/Icons/flame.svg")

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _continue_button: Button = %ContinueButton


func _on_opened(data: Dictionary) -> void:
	var day: int = int(data.get(KEY_DAY, 1))
	var is_won: bool = bool(data.get(KEY_WON, true))
	if is_won:
		_title_label.text = tr("Day %d done") % day
		_subtitle_label.text = tr("The raid is beaten. The heat is gone.") if bool(data.get(KEY_RAID_BEATEN, false)) else tr("You made it to dawn.")
		_continue_button.text = tr("Start Day %d") % (day + 1)
	else:
		_title_label.text = tr("The house was overrun")
		_subtitle_label.text = tr("Day %d starts over.") % day
		_continue_button.text = tr("Try Day %d Again") % day
	_add_row(CASH_ICON, tr("Earned $%s") % NumberFormat.with_separators(int(data.get(KEY_CASH_EARNED, 0))), Palette.GOLD)
	_add_row(BAG_ICON, tr("Sold %d units") % int(data.get(KEY_UNITS_SOLD, 0)), Palette.TEXT_MUTED)
	_add_row(BOX_ICON, tr("Crafted %d units") % int(data.get(KEY_UNITS_CRAFTED, 0)), Palette.TEXT_MUTED)
	if bool(data.get(KEY_RAID_BEATEN, false)):
		_add_row(SHIELD_ICON, tr("Police raid beaten"), Palette.SUCCESS)
	if not is_won:
		_add_row(FLAME_ICON, tr("Stash lost: %d units") % int(data.get(KEY_UNITS_LOST, 0)), Palette.DANGER)
		_add_row(CASH_ICON, tr("Repairs: $%s") % NumberFormat.with_separators(int(data.get(KEY_REPAIR_COST, 0))), Palette.DANGER)


func handle_back() -> void:
	close(null)


func _add_row(icon: Texture2D, text: String, icon_tint: Color) -> void:
	var row: IconLabel = IconLabel.create(icon, text, ROW_ICON_SIZE, icon_tint)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_rows.add_child(row)


func _on_continue_button_pressed() -> void:
	close(null)

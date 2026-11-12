## The office: the wall screen that sells the upgrades of all five branches
## and pays off the police. Part of the house (the economy hub); it reads and
## writes only the Operation and Profile.
##
## Dependencies: HouseFront, OfficeBoard, WorldScreen, Operation, Profile, Audio autoloads, Palette
class_name Office
extends HouseFront

@onready var _screen: WorldScreen = %OfficeScreen


func _on_setup() -> void:
	var board: OfficeBoard = get_board()
	board.upgrade_requested.connect(buy_upgrade)
	board.bribe_requested.connect(_on_bribe_requested)


func _refresh_displays() -> void:
	get_board().set_heat(context.operation.heat.value, context.operation.get_bribe_cost())
	update_screen_rendering(_screen)


func apply_upgrades() -> void:
	get_board().refresh()


func get_board() -> OfficeBoard:
	return _screen.content as OfficeBoard


func get_screen() -> WorldScreen:
	return _screen


## Buys an upgrade (from the board, a tutorial or a test). Returns true on success.
func buy_upgrade(upgrade: UpgradeData) -> bool:
	if not Profile.upgrades.purchase(upgrade):
		Audio.play_ui(Audio.UI_ERROR)
		return false
	Audio.play_ui(Audio.UI_CONFIRM)
	return true


func _on_bribe_requested() -> void:
	if context.operation.bribe():
		Audio.play_ui(Audio.UI_CONFIRM)
		announcement_requested.emit(tr("Heat dropped"), Palette.SUCCESS)
	else:
		Audio.play_ui(Audio.UI_ERROR)

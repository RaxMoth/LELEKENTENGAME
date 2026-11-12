## Admin mode for testing (debug and editor builds only; it removes itself
## from release builds): an in-world terminal on the office's back wall that
## gives cash and reputation, moves the day, starts the raid at once, skips
## or clears waves, wins the shift and speeds time up. In the headset it is
## used like every other screen; in the flat simulator too.
##
## It works only through the HouseContext (operation, cycle, day cycle,
## level) and Profile, like every front.
##
## Dependencies: HouseFront, AdminBoard, HouseCycle, DayCycle, RaidPlanner,
##               WorldScreen, Profile, Audio, Types autoloads, Palette
class_name AdminPanel
extends HouseFront

const SMALL_CASH: int = 1000
const LARGE_CASH: int = 10000
const REPUTATION_STEP: int = 50
const FAST_TIME_SCALE: float = 3.0

## Off = show the terminal in release builds as well (never ship that).
@export var debug_builds_only: bool = true

@onready var _screen: WorldScreen = %AdminScreen


func _ready() -> void:
	if debug_builds_only and not OS.is_debug_build():
		visible = false
		_screen.set_active(false)


func _on_setup() -> void:
	get_board().action_requested.connect(run_action)


func _refresh_displays() -> void:
	if not visible:
		return
	update_screen_rendering(_screen)
	if _screen.is_rendering():
		get_board().show_status(_describe_state())


func finish_shift(_result: LevelResult) -> void:
	# A sped-up clock must not leak into menus or the next shift.
	Engine.time_scale = 1.0


func get_board() -> AdminBoard:
	return _screen.content as AdminBoard


func get_screen() -> WorldScreen:
	return _screen


## Runs one admin action (an AdminBoard.ACTION_* id). Returns false when it
## can't run right now (e.g. "next wave" outside a raid).
func run_action(action_id: StringName) -> bool:
	if not context.is_playing():
		Audio.play_ui(Audio.UI_ERROR)
		return false
	var cycle: HouseCycle = context.cycle
	var did_run: bool = true
	match action_id:
		AdminBoard.ACTION_CASH_SMALL:
			Profile.wallet.add(Types.CURRENCY_CASH, SMALL_CASH, false)
		AdminBoard.ACTION_CASH_LARGE:
			Profile.wallet.add(Types.CURRENCY_CASH, LARGE_CASH, false)
		AdminBoard.ACTION_REPUTATION:
			Profile.operation.add_reputation(REPUTATION_STEP)
		AdminBoard.ACTION_DAY_BACK:
			did_run = set_day(Profile.operation.day_number - 1)
		AdminBoard.ACTION_DAY_FORWARD:
			did_run = set_day(Profile.operation.day_number + 1)
		AdminBoard.ACTION_RAID_NOW:
			did_run = start_raid_now()
		AdminBoard.ACTION_NEXT_WAVE:
			did_run = cycle.is_raid_active() and not cycle.is_wave_active()
			cycle.skip_wave_break()
		AdminBoard.ACTION_CLEAR_WAVE:
			did_run = cycle.is_wave_active()
			cycle.remove_raiders()
		AdminBoard.ACTION_TIME_SCALE:
			Engine.time_scale = FAST_TIME_SCALE if Engine.time_scale < FAST_TIME_SCALE else 1.0
		AdminBoard.ACTION_WIN_SHIFT:
			context.level.win()
		_:
			did_run = false
	Audio.play_ui(Audio.UI_CONFIRM if did_run else Audio.UI_ERROR)
	if did_run:
		get_board().show_status(_describe_state())
	return did_run


## Jumps to day [param day_number] (1 or later) of the operation. Only while
## selling: the raid of a running raid night stays as it is.
func set_day(day_number: int) -> bool:
	if day_number < 1 or context.cycle.is_raid_active():
		return false
	Profile.operation.day_number = day_number
	Profile.operation.mark_dirty()
	announcement_requested.emit(context.cycle.get_day_announcement(), Palette.WARNING)
	return true


## Moves to the raid day of the current cycle and lets night fall now, so the
## raid starts the way it does in play.
func start_raid_now() -> bool:
	var cycle: HouseCycle = context.cycle
	if cycle.is_raid_active():
		return false
	if not cycle.is_raid_day():
		Profile.operation.day_number += RaidPlanner.get_days_until_raid(Profile.operation.day_number, cycle.raid_data)
		Profile.operation.mark_dirty()
	var clock: DayClock = context.day_cycle.clock
	if clock.get_phase() == DayClock.Phase.DAY:
		# Nightfall starts the raid (HouseLevel._on_nightfall).
		context.day_cycle.advance(clock.day_seconds - clock.elapsed_seconds + 0.01)
	else:
		cycle.start_raid()
	return cycle.is_raid_active()


func _describe_state() -> String:
	var cycle: HouseCycle = context.cycle
	var phase_text: String = cycle.get_status_line()
	return tr("Day %d · day %d of %d · raid %d · %s\nCash $%d · time x%d") % [
		Profile.operation.day_number, cycle.get_day_in_cycle(), cycle.get_days_per_cycle(),
		cycle.get_raid_number(), phase_text, context.operation.get_cash(), roundi(Engine.time_scale)]

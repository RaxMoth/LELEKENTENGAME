## A handful of raiders that work their way to the door together: they
## leapfrog from cover to cover (only part of the squad moves at once, the
## rest waits in cover), gather in the last cover before the house, then
## rush the door all at the same time. Created by the AttackerDirector for
## each wave; raiders ask it whether they may move and whether to rush.
## A level-only helper class of the defense front (kept with Raider).
##
## Dependencies: Raider
class_name RaidSquad
extends RefCounted

enum Phase { ADVANCING, RUSHING }

## Share of the squad that may be out of cover at the same time.
const MOVING_SHARE: float = 0.5
## Once the first member reached the last cover, the rest get this long.
const GATHER_TIMEOUT_SECONDS: float = 9.0

var phase: Phase = Phase.ADVANCING
var members: Array[Raider] = []

var _seconds_since_first_staged: float = -1.0


func add(raider: Raider) -> void:
	members.append(raider)
	raider.squad = self


func is_rushing() -> bool:
	return phase == Phase.RUSHING


## Living members still in the yard.
func get_alive_members() -> Array[Raider]:
	var alive: Array[Raider] = []
	for member: Raider in members:
		if member.is_alive() and member.squad == self:
			alive.append(member)
	return alive


## True when [param raider] may leave cover now (leapfrogging).
func may_move(raider: Raider) -> bool:
	if is_rushing():
		return true
	var alive: Array[Raider] = get_alive_members()
	var moving: int = 0
	for member: Raider in alive:
		if member != raider and member.is_moving():
			moving += 1
	return moving < maxi(1, ceili(alive.size() * MOVING_SHARE))


## Called by the director every frame: decides when the squad rushes.
func step(delta: float) -> void:
	if is_rushing():
		return
	var alive: Array[Raider] = get_alive_members()
	if alive.is_empty():
		return
	var staged: int = 0
	for member: Raider in alive:
		if member.is_staged:
			staged += 1
	if staged == 0:
		return
	if _seconds_since_first_staged < 0.0:
		_seconds_since_first_staged = 0.0
	_seconds_since_first_staged += delta
	if staged == alive.size() or _seconds_since_first_staged >= GATHER_TIMEOUT_SECONDS:
		start_rush()


## Everyone runs for the door now.
func start_rush() -> void:
	if is_rushing():
		return
	phase = Phase.RUSHING
	for member: Raider in get_alive_members():
		member.on_squad_rush()

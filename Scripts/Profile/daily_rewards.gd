## Login-streak rewards. Claiming on consecutive days advances the streak;
## missing a day restarts it. Rewards come from GameConfig.daily_rewards.
##
## Dependencies: Events, Global, Profile autoloads
class_name DailyRewards
extends ProfileModule

var last_claim_day: int = -1
var streak_index: int = -1


func get_save_key() -> StringName:
	return &"daily_rewards"


func to_dict() -> Dictionary:
	return {"last_claim_day": last_claim_day, "streak_index": streak_index}


func from_dict(data: Dictionary) -> void:
	last_claim_day = int(data.get("last_claim_day", -1))
	streak_index = int(data.get("streak_index", -1))


func reset() -> void:
	last_claim_day = -1
	streak_index = -1


func can_claim() -> bool:
	return not config.daily_rewards.is_empty() and _today() > last_claim_day


## Index into GameConfig.daily_rewards that the next claim would grant.
func get_next_reward_index() -> int:
	if config.daily_rewards.is_empty():
		return -1
	var continues_streak: bool = _today() == last_claim_day + 1
	var next_streak: int = streak_index + 1 if continues_streak else 0
	return next_streak % config.daily_rewards.size()


func claim() -> Dictionary[StringName, int]:
	var granted_rewards: Dictionary[StringName, int] = {}
	if not can_claim():
		return granted_rewards
	var continues_streak: bool = _today() == last_claim_day + 1
	streak_index = streak_index + 1 if continues_streak else 0
	last_claim_day = _today()
	granted_rewards = config.daily_rewards[streak_index % config.daily_rewards.size()].rewards
	Profile.grant_rewards(granted_rewards)
	Events.daily_reward_claimed.emit(streak_index, granted_rewards)
	mark_dirty()
	return granted_rewards


func _today() -> int:
	return Global.local_day_index(Global.unix_now())

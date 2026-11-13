## The player's skills and the experience in each: crafting, fighting and
## harvesting grow by doing them (SkillTuning says how much each action
## gives and what a level is worth). Pure data; PlayerSkills saves it.
##
##   var level_up: int = book.add_xp(SkillBook.Skill.CRAFTING, 2.5, tuning)   # new level, or -1
##   book.get_level(SkillBook.Skill.FIGHTING, tuning)
##
## Unit-tested in Tests/Unit/skill_book_test.gd.
##
## Dependencies: SkillTuning
class_name SkillBook
extends RefCounted

enum Skill { CRAFTING, FIGHTING, HARVESTING }

## Display names, in Skill order.
const SKILL_NAMES: Array[String] = ["Crafting", "Fighting", "Harvesting"]
## Short names for the wrist, in Skill order.
const SHORT_NAMES: Array[String] = ["Craft", "Fight", "Harvest"]

var _xp: Dictionary[int, float] = {}


func get_xp(skill: Skill) -> float:
	return _xp.get(skill, 0.0)


## Adds [param amount] experience. Returns the new level when it went up, else -1.
func add_xp(skill: Skill, amount: float, tuning: SkillTuning) -> int:
	if amount <= 0.0:
		return -1
	var level_before: int = get_level(skill, tuning)
	_xp[skill] = get_xp(skill) + amount
	var level_after: int = get_level(skill, tuning)
	return level_after if level_after > level_before else -1


## Levels reached: how many thresholds the experience has passed.
func get_level(skill: Skill, tuning: SkillTuning) -> int:
	var experience: float = get_xp(skill)
	var level: int = 0
	for threshold: float in tuning.level_thresholds:
		if experience < threshold:
			break
		level += 1
	return level


## True at the top level (no further thresholds).
func is_maxed(skill: Skill, tuning: SkillTuning) -> bool:
	return get_level(skill, tuning) >= tuning.level_thresholds.size()


## Share of the way to the next level (1 at the top level).
func get_progress(skill: Skill, tuning: SkillTuning) -> float:
	var level: int = get_level(skill, tuning)
	if level >= tuning.level_thresholds.size():
		return 1.0
	var start: float = tuning.level_thresholds[level - 1] if level > 0 else 0.0
	var end: float = tuning.level_thresholds[level]
	return clampf((get_xp(skill) - start) / maxf(0.001, end - start), 0.0, 1.0)


## JSON-friendly: {"0": 12.5, "1": 3.0}.
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	for skill: int in _xp:
		data[str(skill)] = _xp[skill]
	return data


func from_dict(data: Dictionary) -> void:
	_xp.clear()
	for key: Variant in data:
		var skill: int = int(str(key))
		if skill >= 0 and skill < Skill.size():
			_xp[skill] = maxf(0.0, float(data[key]))

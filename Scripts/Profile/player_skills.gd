## The player's skills between shifts (a SkillBook) and what they give
## (Ressources/Skills/skill_tuning.tres). The house records what the player
## does — a skill check stopped by hand, a punch or blade hit, a hand
## harvest — and asks for the bonuses.
##
##   var new_level: int = Profile.skills.record(SkillBook.Skill.FIGHTING, Profile.skills.tuning.fight_xp)
##   Profile.skills.get_melee_damage_bonus()
##
## Dependencies: SkillBook, SkillTuning, SaveManager autoload (through ProfileModule)
class_name PlayerSkills
extends ProfileModule

const TUNING: SkillTuning = preload("res://Ressources/Skills/skill_tuning.tres")

var book: SkillBook = null
var tuning: SkillTuning = TUNING


func get_save_key() -> StringName:
	return &"skills"


func to_dict() -> Dictionary:
	return book.to_dict()


func from_dict(data: Dictionary) -> void:
	reset()
	book.from_dict(data)


func reset() -> void:
	book = SkillBook.new()


## Adds experience to [param skill]. Returns the new level when it went up, else -1.
func record(skill: SkillBook.Skill, amount: float) -> int:
	var new_level: int = book.add_xp(skill, amount, tuning)
	mark_dirty()
	return new_level


func get_level(skill: SkillBook.Skill) -> int:
	return book.get_level(skill, tuning)


## Multiplier on the skill check's sweet zone (crafting).
func get_sweet_zone_multiplier() -> float:
	return 1.0 + get_level(SkillBook.Skill.CRAFTING) * tuning.sweet_zone_per_level


## Added to every punch and blade hit (fighting).
func get_melee_damage_bonus() -> float:
	return get_level(SkillBook.Skill.FIGHTING) * tuning.melee_damage_per_level


## Added to every hand harvest (harvesting).
func get_harvest_bonus() -> int:
	return floori(get_level(SkillBook.Skill.HARVESTING) * tuning.harvest_units_per_level)

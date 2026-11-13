## How the player's skills grow by doing and what each level gives:
## crafting (stopping a skill check by hand) widens the sweet zone, fighting
## (landing a punch or a blade) adds melee damage, harvesting (picking a
## plant by hand) adds units to every hand harvest.
##
## Instance: Ressources/Skills/skill_tuning.tres (PlayerSkills loads it).
##
## Dependencies: none
class_name SkillTuning
extends Resource

## Experience needed for each next level (the last entry is the top level).
@export var level_thresholds: PackedFloat32Array = PackedFloat32Array([8.0, 20.0, 40.0, 70.0, 110.0])

@export_group("Experience")
## A skill check stopped by hand gives this much...
@export var craft_xp: float = 1.0
## ...plus this much more at a perfect stop (scaled by the accuracy).
@export var craft_accuracy_xp: float = 2.0
## Each landed punch or blade hit.
@export var fight_xp: float = 1.0
## Each hand harvest.
@export var harvest_xp: float = 2.0

@export_group("Per level")
## Sweet zone grows by this share per crafting level (0.06 = +6 %).
@export var sweet_zone_per_level: float = 0.06
## Melee damage added per fighting level.
@export var melee_damage_per_level: float = 2.0
## Extra units per hand harvest per harvesting level (rounded down).
@export var harvest_units_per_level: float = 0.5

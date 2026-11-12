## A named set of rewards (currencies and/or items), e.g. one daily-reward day.
##
## Dependencies: none
class_name RewardBundle
extends Resource

@export var title: String = ""
@export var rewards: Dictionary[StringName, int] = {}

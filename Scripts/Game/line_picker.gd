## Picks which of several lines an NPC says next: at random, but never one
## of the last few it said, so a short pool doesn't repeat itself.
##
##   var picker: LinePicker = LinePicker.new()
##   var index: int = picker.pick(&"greet", 4, random)
##
## Pure logic (unit-tested in Tests/Unit/dialogue_test.gd).
##
## Dependencies: none
class_name LinePicker
extends RefCounted

## How many recent picks per category are kept out of the draw (never all
## of a pool: at least one line stays available).
var memory: int = 2

var _recent_by_category: Dictionary = {}


## An index into a pool of [param count] lines of [param category], or -1
## when the pool is empty.
func pick(category: StringName, count: int, random: RandomNumberGenerator = null) -> int:
	if count <= 0:
		return -1
	var recent: Array[int] = []
	recent.assign(_recent_by_category.get(category, []))
	var kept_out: int = mini(memory, count - 1)
	while recent.size() > kept_out:
		recent.remove_at(0)
	var candidates: Array[int] = []
	for line_index: int in count:
		if not recent.has(line_index):
			candidates.append(line_index)
	var roll: int = random.randi_range(0, candidates.size() - 1) if random != null else randi_range(0, candidates.size() - 1)
	var picked: int = candidates[roll]
	recent.append(picked)
	_recent_by_category[category] = recent
	return picked


## Forgets what was said (an NPC back in the pool).
func reset() -> void:
	_recent_by_category.clear()

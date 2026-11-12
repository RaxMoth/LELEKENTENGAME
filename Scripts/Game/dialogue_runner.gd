## Walks a conversation (DialogueData): where it stands, which replies the
## player has, where a reply leads, and the outcomes it reached. Roll nodes
## resolve on the spot with the chance given at start().
##
##   var runner: DialogueRunner = DialogueRunner.new(dialogue)
##   runner.start(0.6, random)
##   npc_voice.say(runner.get_current().line_category, true)
##   runner.choose(reply_index)
##
## Pure logic (unit-tested in Tests/Unit/dialogue_test.gd).
##
## Dependencies: DialogueData, DialogueNodeData, DialogueReplyData
class_name DialogueRunner
extends RefCounted

## Roll nodes in a row before the runner gives up (a loop in the data).
const MAX_ROLLS_IN_A_ROW: int = 8

var dialogue: DialogueData = null
## Outcomes reached so far in this conversation, in order.
var outcomes: Array[DialogueNodeData.Outcome] = []

var _current: DialogueNodeData = null
var _success_chance: float = 0.5
var _random: RandomNumberGenerator = null


func _init(conversation: DialogueData) -> void:
	dialogue = conversation


## Starts at the dialogue's first node. [param success_chance] (0..1) decides
## roll nodes. Returns the node the NPC answers with (null when empty).
func start(success_chance: float = 0.5, random: RandomNumberGenerator = null) -> DialogueNodeData:
	_success_chance = clampf(success_chance, 0.0, 1.0)
	_random = random
	outcomes.clear()
	_enter(dialogue.start_node if dialogue != null else &"")
	return _current


## The node the conversation stands at (null once it has ended).
func get_current() -> DialogueNodeData:
	return _current


func is_finished() -> bool:
	return _current == null


## Replies the player can give now (empty once finished or at a closing line).
func get_replies() -> Array[DialogueReplyData]:
	var replies: Array[DialogueReplyData] = []
	if _current != null:
		replies.assign(_current.replies)
	return replies


## The player picks reply [param reply_index]. Returns the node the NPC
## answers with, or null when the conversation is over.
func choose(reply_index: int) -> DialogueNodeData:
	var replies: Array[DialogueReplyData] = get_replies()
	if reply_index < 0 or reply_index >= replies.size():
		return _current
	_enter(replies[reply_index].next_node)
	return _current


## Ends the conversation (the player walked off).
func finish() -> void:
	_current = null


func has_outcome(outcome: DialogueNodeData.Outcome) -> bool:
	return outcomes.has(outcome)


func _enter(node_id: StringName) -> void:
	_current = dialogue.find_node(node_id) if dialogue != null and node_id != &"" else null
	var rolls: int = 0
	while _current != null and _current.is_roll and rolls < MAX_ROLLS_IN_A_ROW:
		rolls += 1
		var roll: float = _random.randf() if _random != null else randf()
		var next_id: StringName = _current.success_node if roll < _success_chance else _current.failure_node
		_current = dialogue.find_node(next_id) if next_id != &"" else null
	if _current != null and _current.is_roll:
		_current = null
	if _current != null and _current.outcome != DialogueNodeData.Outcome.NONE:
		outcomes.append(_current.outcome)

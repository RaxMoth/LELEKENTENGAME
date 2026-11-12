## One step of a conversation: the NPC says a line of a voice category and
## the player picks a reply. A node can instead be a roll (an offer the NPC
## may take or turn down), and it can carry an outcome for the game (the
## NPC agrees to come and buy).
##
## Dependencies: DialogueReplyData
class_name DialogueNodeData
extends Resource

## What reaching this node means for the game.
enum Outcome {
	NONE,
	## The NPC will come to the window and buy.
	REFERRED_CUSTOMER,
}

@export var id: StringName = &""
## The VoiceLineData category the NPC answers with (empty = says nothing).
@export var line_category: StringName = &""
@export var replies: Array[DialogueReplyData] = []
@export var outcome: Outcome = Outcome.NONE

@export_group("Roll")
## A roll node passes straight on: to success_node with the chance the
## conversation gives it, otherwise to failure_node.
@export var is_roll: bool = false
@export var success_node: StringName = &""
@export var failure_node: StringName = &""

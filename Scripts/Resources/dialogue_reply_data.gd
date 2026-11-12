## One answer the player can give in a conversation, and where it leads.
##
## Dependencies: none
class_name DialogueReplyData
extends Resource

## What the player says (translated, shown on a button).
@export var text: String = ""
## The node the NPC answers with; empty ends the conversation.
@export var next_node: StringName = &""

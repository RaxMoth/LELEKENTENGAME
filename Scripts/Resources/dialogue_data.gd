## A conversation the player can have with an NPC: a small graph of nodes
## (what the NPC says) joined by the player's replies. Walked by a
## DialogueRunner.
##
## Dependencies: DialogueNodeData
class_name DialogueData
extends Resource

@export var start_node: StringName = &""
@export var nodes: Array[DialogueNodeData] = []


## The node with [param node_id], or null.
func find_node(node_id: StringName) -> DialogueNodeData:
	for node: DialogueNodeData in nodes:
		if node != null and node.id == node_id:
			return node
	return null

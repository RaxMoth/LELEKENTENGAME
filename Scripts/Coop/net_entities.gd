## Streams spawned things (lab items, customers, raiders) from the co-op
## host to the other player. The host lists what exists, where it is and how
## it looks; the guest spawns look-alike stand-ins from the same scenes —
## frozen, so none of their own game logic runs — moves them smoothly and
## removes them when the host's are gone. An item held by the guest's own
## hand is drawn right at that hand, so holding never lags.
##
##   # Host, into every snapshot:
##   var entries: Array = entities.collect(get_tree().get_nodes_in_group(Types.GROUP_NET_ENTITY))
##   # Guest:
##   entities.apply(entries, Global.get_world_root())
##   entities.smooth(delta)   # every frame
##
## Entry: [net id, kind index, transform, look (get_net_state() or []),
## holder] — holder is Vector2i(peer id, hand) of the hand holding it, taken
## from the RemotePlayer.META_HOLDER metadata on hold anchors, or NO_HOLDER.
##
## Dependencies: Grabbable, RemotePlayer, Pools autoload
class_name NetEntities
extends RefCounted

const NO_HOLDER: Vector2i = Vector2i(0, -1)
## Optional method: the look the other player needs (ingredient, recipe...).
const METHOD_GET_STATE: StringName = &"get_net_state"
## Optional method on the stand-in: take that look.
const METHOD_APPLY_STATE: StringName = &"apply_net_state"
## How fast stand-ins catch up with the host's latest positions (1/s).
const SMOOTHING: float = 14.0
const ENTRY_ID: int = 0
const ENTRY_KIND: int = 1
const ENTRY_TRANSFORM: int = 2
const ENTRY_STATE: int = 3
const ENTRY_HOLDER: int = 4

## Scenes that are streamed; an entry's kind is the index into this list.
var kind_paths: PackedStringArray = PackedStringArray()
## Guest: (holder: Vector2i) -> Node3D — this player's own hand for a holder
## that is them, or null. Their held items are drawn there.
var local_hold_anchor: Callable = Callable()

## Host: net id of every streamed node.
var _ids: Dictionary[Node, int] = {}
var _next_id: int = 1
## Guest: stand-in per net id, where it should be and who holds it.
var _stand_ins: Dictionary[int, Node3D] = {}
var _targets: Dictionary[int, Transform3D] = {}
var _holders: Dictionary[int, Vector2i] = {}
var _scenes: Dictionary[int, PackedScene] = {}


func _init(streamed_scene_paths: PackedStringArray) -> void:
	kind_paths = streamed_scene_paths

# ============================================
# HOST
# ============================================

## Entries for every live node among [param candidates] whose scene is streamed.
func collect(candidates: Array[Node]) -> Array:
	var entries: Array = []
	var seen: Dictionary[Node, bool] = {}
	for candidate: Node in candidates:
		var node: Node3D = candidate as Node3D
		if node == null or seen.has(node) or not node.is_inside_tree() or Pools.is_in_pool(node):
			continue
		var kind: int = kind_paths.find(node.scene_file_path)
		if kind < 0:
			continue
		seen[node] = true
		var net_id: int = _ids.get(node, 0)
		if net_id == 0:
			net_id = _next_id
			_next_id += 1
			_ids[node] = net_id
		var state: Array = node.call(METHOD_GET_STATE) if node.has_method(METHOD_GET_STATE) else []
		entries.append([net_id, kind, node.global_transform, state, _get_holder(node)])
	# Gone or back in its pool: a later respawn is a new thing with a new id.
	for known: Variant in _ids.keys():
		if not is_instance_valid(known) or not seen.has(known):
			_ids.erase(known)
	return entries

# ============================================
# GUEST
# ============================================

## Brings the stand-ins in line with the host's [param entries] (spawning
## new ones under [param parent], removing those the host no longer has).
func apply(entries: Array, parent: Node) -> void:
	var present: Dictionary[int, bool] = {}
	for entry: Array in entries:
		var net_id: int = int(entry[ENTRY_ID])
		var kind: int = int(entry[ENTRY_KIND])
		if kind < 0 or kind >= kind_paths.size():
			continue
		present[net_id] = true
		var target: Transform3D = entry[ENTRY_TRANSFORM]
		var stand_in: Node3D = _stand_ins.get(net_id) as Node3D
		if stand_in == null or not is_instance_valid(stand_in) or Pools.is_in_pool(stand_in):
			stand_in = _spawn_stand_in(kind, parent, target)
			_stand_ins[net_id] = stand_in
		_targets[net_id] = target
		_holders[net_id] = entry[ENTRY_HOLDER]
		var state: Array = entry[ENTRY_STATE]
		if not state.is_empty() and stand_in.has_method(METHOD_APPLY_STATE):
			stand_in.call(METHOD_APPLY_STATE, state)
	for net_id: int in _stand_ins.keys():
		if not present.has(net_id):
			_remove(net_id)


## Moves every stand-in toward where the host has it (held ones to the hand).
func smooth(delta: float) -> void:
	var weight: float = clampf(delta * SMOOTHING, 0.0, 1.0)
	for net_id: int in _stand_ins:
		var stand_in: Node3D = _stand_ins[net_id]
		if not is_instance_valid(stand_in):
			continue
		var anchor: Node3D = local_hold_anchor.call(_holders.get(net_id, NO_HOLDER)) as Node3D if local_hold_anchor.is_valid() else null
		if anchor != null:
			var grabbable: Grabbable = stand_in as Grabbable
			var offset: Vector3 = grabbable.hold_offset if grabbable != null else Vector3.ZERO
			stand_in.global_transform = anchor.global_transform * Transform3D(Basis.IDENTITY, offset)
		else:
			stand_in.global_transform = stand_in.global_transform.interpolate_with(_targets[net_id], weight)


## The stand-in the host says [param holder] holds, or null.
func find_held_by(holder: Vector2i) -> Node3D:
	for net_id: int in _holders:
		if _holders[net_id] == holder and _stand_ins.has(net_id) and is_instance_valid(_stand_ins[net_id]):
			return _stand_ins[net_id]
	return null


func get_stand_in_count() -> int:
	return _stand_ins.size()


## Every stand-in of streamed scene [param scene_path] (tests).
func get_stand_ins_of(scene_path: String) -> Array[Node3D]:
	var matches: Array[Node3D] = []
	for net_id: int in _stand_ins:
		var stand_in: Node3D = _stand_ins[net_id]
		if is_instance_valid(stand_in) and stand_in.scene_file_path == scene_path:
			matches.append(stand_in)
	return matches

# ============================================
# INTERNALS
# ============================================

func _get_holder(node: Node3D) -> Vector2i:
	var grabbable: Grabbable = node as Grabbable
	if grabbable == null or grabbable.holder == null or not is_instance_valid(grabbable.holder):
		return NO_HOLDER
	return grabbable.holder.get_meta(RemotePlayer.META_HOLDER, NO_HOLDER)


func _spawn_stand_in(kind: int, parent: Node, at: Transform3D) -> Node3D:
	if not _scenes.has(kind):
		_scenes[kind] = load(kind_paths[kind]) as PackedScene
	var stand_in: Node3D = Pools.spawn(_scenes[kind], parent, at.origin) as Node3D
	# A picture of the host's thing: its own logic (walking, timers) must not run here.
	stand_in.process_mode = Node.PROCESS_MODE_DISABLED
	stand_in.global_transform = at
	return stand_in


func _remove(net_id: int) -> void:
	var stand_in: Node3D = _stand_ins.get(net_id) as Node3D
	if stand_in != null and is_instance_valid(stand_in):
		# Back to normal before the pool hands it out again.
		stand_in.process_mode = Node.PROCESS_MODE_INHERIT
		Pools.despawn(stand_in)
	_stand_ins.erase(net_id)
	_targets.erase(net_id)
	_holders.erase(net_id)

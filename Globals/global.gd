## Stateless runtime helpers: group and component queries, the spawn root, timing.
##
## Rule: nothing in here may hold mutable game state. If you need state,
## it belongs in a component, a Resource or one of the service autoloads.
##
## Dependencies: Types autoload
extends Node

# ============================================
# TREE & GROUP QUERIES
# ============================================

## Returns the first node in [param group_name] or null.
func get_first_in_group(group_name: StringName) -> Node:
	return get_tree().get_first_node_in_group(group_name)


## Finds the first direct child of [param host] that is an instance of [param component_script].
## Example: [code]Global.find_component(enemy, HealthComponent) as HealthComponent[/code]
func find_component(host: Node, component_script: Script) -> Node:
	if host == null:
		return null
	for child: Node in host.get_children():
		if is_instance_of(child, component_script):
			return child
	return null


## Node that runtime spawns (attackers, bolts, effects) should be parented to.
## Levels put their World node in [constant Types.GROUP_WORLD_ROOT]; falls back to the current scene.
func get_world_root() -> Node:
	var world_root: Node = get_tree().get_first_node_in_group(Types.GROUP_WORLD_ROOT)
	return world_root if world_root != null else get_tree().current_scene


func remove_all_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

# ============================================
# TIME
# ============================================

## Awaitable delay: [code]await Global.wait(0.5)[/code].
## [param pausable] = true stops the timer while the tree is paused.
func wait(seconds: float, pausable: bool = true) -> void:
	await get_tree().create_timer(seconds, not pausable).timeout


func unix_now() -> int:
	return int(Time.get_unix_time_from_system())


## Day number since the unix epoch in local time. Used by daily rewards.
func local_day_index(unix_time: int) -> int:
	var timezone_offset_seconds: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return floori(float(unix_time + timezone_offset_seconds) / 86400.0)

## Stateless runtime helpers: group queries, geometry, spawning roots, timing.
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


## Returns the closest [Node2D] of a group to [param from_position].
## [param max_distance] <= 0 means unlimited.
func find_nearest_in_group(group_name: StringName, from_position: Vector2, max_distance: float = 0.0) -> Node2D:
	var nearest_node: Node2D = null
	var nearest_distance_squared: float = INF
	var max_distance_squared: float = max_distance * max_distance
	for candidate: Node in get_tree().get_nodes_in_group(group_name):
		var candidate_2d: Node2D = candidate as Node2D
		if candidate_2d == null or not candidate_2d.is_inside_tree():
			continue
		var distance_squared: float = from_position.distance_squared_to(candidate_2d.global_position)
		if max_distance > 0.0 and distance_squared > max_distance_squared:
			continue
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_node = candidate_2d
	return nearest_node


## Returns every [Node2D] of a group inside a circle.
func get_group_nodes_in_radius(group_name: StringName, center: Vector2, radius: float) -> Array[Node2D]:
	var found_nodes: Array[Node2D] = []
	var radius_squared: float = radius * radius
	for candidate: Node in get_tree().get_nodes_in_group(group_name):
		var candidate_2d: Node2D = candidate as Node2D
		if candidate_2d != null and center.distance_squared_to(candidate_2d.global_position) <= radius_squared:
			found_nodes.append(candidate_2d)
	return found_nodes


## Finds the first direct child of [param host] that is an instance of [param component_script].
## Example: [code]Global.find_component(enemy, HealthComponent) as HealthComponent[/code]
func find_component(host: Node, component_script: Script) -> Node:
	if host == null:
		return null
	for child: Node in host.get_children():
		if is_instance_of(child, component_script):
			return child
	return null


## Node that runtime spawns (projectiles, pickups, effects) should be parented to.
## Levels put their World node in [constant Types.GROUP_WORLD_ROOT]; falls back to the current scene.
func get_world_root() -> Node:
	var world_root: Node = get_tree().get_first_node_in_group(Types.GROUP_WORLD_ROOT)
	return world_root if world_root != null else get_tree().current_scene


func remove_all_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

# ============================================
# GEOMETRY
# ============================================

func random_point_in_ring(center: Vector2, min_radius: float, max_radius: float) -> Vector2:
	var random_angle: float = randf() * TAU
	var random_distance: float = randf_range(min_radius, max_radius)
	return center + Vector2.from_angle(random_angle) * random_distance


func random_point_in_rect(area: Rect2) -> Vector2:
	return Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))


## World-space rectangle currently visible through the viewport of [param context].
func get_visible_world_rect(context: CanvasItem) -> Rect2:
	var canvas_to_world: Transform2D = context.get_viewport().get_canvas_transform().affine_inverse()
	var viewport_rect: Rect2 = context.get_viewport_rect()
	return canvas_to_world * viewport_rect


## Converts a screen/touch position into world coordinates of [param context]'s canvas.
func screen_to_world(context: CanvasItem, screen_position: Vector2) -> Vector2:
	return context.get_viewport().get_canvas_transform().affine_inverse() * screen_position


## Ray-samples around a point to see whether it sits too close to world geometry.
func is_point_too_close_to_wall(world: World2D, point: Vector2, min_radius: float = 32.0, collision_mask: int = Types.LAYER_WORLD, sample_count: int = 8) -> bool:
	var space_state: PhysicsDirectSpaceState2D = world.direct_space_state
	for sample_index: int in sample_count:
		var sample_offset: Vector2 = Vector2.from_angle(sample_index * TAU / sample_count) * min_radius
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(point, point + sample_offset, collision_mask)
		if not space_state.intersect_ray(query).is_empty():
			return true
	return false

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

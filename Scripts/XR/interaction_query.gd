## Finds what a hand or pointer can interact with — grabbables, grab sources,
## sockets, 3D buttons — with plain sphere math on small groups, no physics.
##
## Grab sources are nodes in Types.GROUP_GRAB_SOURCE with a `grab_radius`
## property, a `take_item() -> Grabbable` method and optionally
## `get_grab_center() -> Vector3` (ingredient crates).
##
## Dependencies: Grabbable, ItemSocket, PointerButton, RayMath, Types autoload
class_name InteractionQuery
extends RefCounted

const METHOD_TAKE_ITEM: StringName = &"take_item"
const PROPERTY_GRAB_RADIUS: StringName = &"grab_radius"
const METHOD_GET_GRAB_CENTER: StringName = &"get_grab_center"


## Nearest grabbable item or grab source a ray hits within [param max_distance].
static func find_grab_target_on_ray(tree: SceneTree, ray_origin: Vector3, ray_direction: Vector3, max_distance: float) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = max_distance
	for candidate: Node3D in _get_grab_candidates(tree):
		var distance: float = RayMath.intersect_sphere(ray_origin, ray_direction, _get_center(candidate), _get_radius(candidate))
		if distance != RayMath.NO_HIT and distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


## Nearest grabbable item or grab source within reach of a hand at [param point].
static func find_grab_target_near(tree: SceneTree, point: Vector3, reach: float) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = INF
	for candidate: Node3D in _get_grab_candidates(tree):
		var distance: float = point.distance_to(_get_center(candidate)) - _get_radius(candidate)
		if distance <= reach and distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


## Turns a grab target into the item to hold (a source hands out a new one).
static func take_from(target: Node3D) -> Grabbable:
	if target is Grabbable:
		return target as Grabbable
	if target != null and target.has_method(METHOD_TAKE_ITEM):
		return target.call(METHOD_TAKE_ITEM) as Grabbable
	return null


## Nearest socket that takes [param item] within its snap radius of [param point].
static func find_socket_near(tree: SceneTree, item: Grabbable, point: Vector3) -> ItemSocket:
	var nearest: ItemSocket = null
	var nearest_distance: float = INF
	for node: Node in tree.get_nodes_in_group(Types.GROUP_ITEM_SOCKET):
		var socket: ItemSocket = node as ItemSocket
		if socket == null or not socket.can_accept(item):
			continue
		var distance: float = point.distance_to(socket.global_position)
		if distance <= socket.snap_radius and distance < nearest_distance:
			nearest_distance = distance
			nearest = socket
	return nearest


## Nearest free socket that takes [param item] within [param radius] of
## [param point], ignoring snap radii (where a dropped item can go back to).
static func find_socket_within(tree: SceneTree, item: Grabbable, point: Vector3, radius: float) -> ItemSocket:
	var nearest: ItemSocket = null
	var nearest_distance: float = radius
	for node: Node in tree.get_nodes_in_group(Types.GROUP_ITEM_SOCKET):
		var socket: ItemSocket = node as ItemSocket
		if socket == null or not socket.can_accept(item):
			continue
		var distance: float = point.distance_to(socket.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = socket
	return nearest


## Nearest socket taking [param item] whose snap sphere a ray passes through.
static func find_socket_on_ray(tree: SceneTree, item: Grabbable, ray_origin: Vector3, ray_direction: Vector3, max_distance: float) -> ItemSocket:
	var nearest: ItemSocket = null
	var nearest_distance: float = max_distance
	for node: Node in tree.get_nodes_in_group(Types.GROUP_ITEM_SOCKET):
		var socket: ItemSocket = node as ItemSocket
		if socket == null or not socket.can_accept(item):
			continue
		var distance: float = RayMath.intersect_sphere(ray_origin, ray_direction, socket.global_position, socket.snap_radius)
		if distance != RayMath.NO_HIT and distance < nearest_distance:
			nearest_distance = distance
			nearest = socket
	return nearest


## Nearest 3D button a ray hits within [param max_distance].
static func find_button_on_ray(tree: SceneTree, ray_origin: Vector3, ray_direction: Vector3, max_distance: float) -> PointerButton:
	var nearest: PointerButton = null
	var nearest_distance: float = max_distance
	for node: Node in tree.get_nodes_in_group(Types.GROUP_POINTER_BUTTON):
		var button: PointerButton = node as PointerButton
		if button == null or not button.is_visible_in_tree():
			continue
		var distance: float = RayMath.intersect_sphere(ray_origin, ray_direction, button.get_press_center(), button.press_radius)
		if distance != RayMath.NO_HIT and distance < nearest_distance:
			nearest_distance = distance
			nearest = button
	return nearest


## Distance along a ray to a grab target or button (RayMath.NO_HIT for none),
## so the pointer beam can end on it.
static func get_hover_distance(tree: SceneTree, ray_origin: Vector3, ray_direction: Vector3, max_distance: float) -> float:
	var nearest_distance: float = RayMath.NO_HIT
	var target: Node3D = find_grab_target_on_ray(tree, ray_origin, ray_direction, max_distance)
	if target != null:
		nearest_distance = RayMath.intersect_sphere(ray_origin, ray_direction, _get_center(target), _get_radius(target))
	var button: PointerButton = find_button_on_ray(tree, ray_origin, ray_direction, max_distance)
	if button != null:
		var button_distance: float = RayMath.intersect_sphere(ray_origin, ray_direction, button.get_press_center(), button.press_radius)
		if nearest_distance == RayMath.NO_HIT or button_distance < nearest_distance:
			nearest_distance = button_distance
	return nearest_distance


static func _get_grab_candidates(tree: SceneTree) -> Array[Node3D]:
	var candidates: Array[Node3D] = []
	for node: Node in tree.get_nodes_in_group(Types.GROUP_GRABBABLE):
		var item: Grabbable = node as Grabbable
		if item != null and item.can_grab():
			candidates.append(item)
	for node: Node in tree.get_nodes_in_group(Types.GROUP_GRAB_SOURCE):
		var source: Node3D = node as Node3D
		if source != null and source.is_visible_in_tree():
			candidates.append(source)
	return candidates


static func _get_center(candidate: Node3D) -> Vector3:
	if candidate.has_method(METHOD_GET_GRAB_CENTER):
		return candidate.call(METHOD_GET_GRAB_CENTER) as Vector3
	return candidate.global_position


static func _get_radius(candidate: Node3D) -> float:
	return float(candidate.get(PROPERTY_GRAB_RADIUS)) if PROPERTY_GRAB_RADIUS in candidate else 0.15

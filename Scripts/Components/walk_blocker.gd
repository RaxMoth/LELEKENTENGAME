## Furniture the player can't walk through: a table, a station, a shelf, a
## grow rack. Its footprint ([member size], centered on the node, turned
## with it) blocks the floor it stands on while it is visible — a station
## that isn't bought yet blocks nothing. The House level hands every blocker
## in Types.GROUP_WALK_BLOCKER to the player's WalkableArea whenever
## upgrades change (WalkableArea.add_obstacle()).
##
## Dependencies: ProximityCull, Types autoload
class_name WalkBlocker
extends Node3D

## Width (local X) and depth (local Z) of the footprint in meters.
@export var size: Vector2 = Vector2(1.0, 1.0)


func _ready() -> void:
	add_to_group(Types.GROUP_WALK_BLOCKER)


## The footprint in world X / Z (an axis-aligned rect around the turned one).
func get_footprint() -> Rect2:
	var half: Vector3 = Vector3(size.x * 0.5, 0.0, size.y * 0.5)
	var footprint: Rect2 = Rect2()
	var corners: Array[Vector3] = [Vector3(-half.x, 0.0, -half.z), Vector3(half.x, 0.0, -half.z), Vector3(half.x, 0.0, half.z), Vector3(-half.x, 0.0, half.z)]
	for corner_index: int in corners.size():
		var world: Vector3 = global_transform * corners[corner_index]
		var point: Vector2 = Vector2(world.x, world.z)
		footprint = Rect2(point, Vector2.ZERO) if corner_index == 0 else footprint.expand(point)
	return footprint


## True when it stands in the world now (bought and shown). A room hidden
## only to save drawing (ProximityCull) still has its furniture.
func is_blocking() -> bool:
	if not is_inside_tree():
		return false
	var node: Node = self
	while node != null:
		var spatial: Node3D = node as Node3D
		if spatial != null and not spatial.visible and not spatial is ProximityCull:
			return false
		node = node.get_parent()
	return true

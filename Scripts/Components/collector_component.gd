## Magnet area that attracts Pickups (put it on the player). Its collision
## mask should include the "pickup" layer.
##
## Dependencies: Pickup
class_name CollectorComponent
extends Area2D

@export var magnet_radius: float = 120.0:
	set(value):
		magnet_radius = value
		if _magnet_shape != null:
			_magnet_shape.radius = magnet_radius
## Node the pickups fly to (defaults to owner).
@export var attract_target: Node2D

var _magnet_shape: CircleShape2D


func _ready() -> void:
	monitorable = false
	for child: Node in get_children():
		var existing_shape: CollisionShape2D = child as CollisionShape2D
		if existing_shape != null and existing_shape.shape is CircleShape2D:
			_magnet_shape = existing_shape.shape as CircleShape2D
	if _magnet_shape == null:
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		_magnet_shape = CircleShape2D.new()
		collision_shape.shape = _magnet_shape
		add_child(collision_shape)
	_magnet_shape.radius = magnet_radius
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	var pickup: Pickup = area as Pickup
	if pickup != null:
		pickup.attract_to(attract_target if attract_target != null else owner as Node2D)

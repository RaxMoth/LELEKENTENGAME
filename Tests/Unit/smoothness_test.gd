## Unit tests for smoother play and lighter drawing: ProximityCull (a room
## drawn only near it), XRPointer steadying (a shaky hand's ray) and
## WalkBlocker furniture inside a culled room.
##
## Dependencies: gdUnit4, ProximityCull, XRPointer, WalkBlocker
extends GdUnitTestSuite

const STAIRWELL: Vector3 = Vector3(2.65, 0.0, 2.12)


func test_a_room_is_near_within_reach_or_from_below() -> void:
	assert_bool(ProximityCull.is_near(Vector3(2.0, 1.7, 3.0), STAIRWELL, 4.5, -0.3)).is_true()
	assert_bool(ProximityCull.is_near(Vector3(-3.0, 1.7, 0.0), STAIRWELL, 4.5, -0.3)).is_false()
	# Down in the cellar it is always near, however far across.
	assert_bool(ProximityCull.is_near(Vector3(-8.0, -0.9, 0.0), STAIRWELL, 4.5, -0.3)).is_true()


func test_steadied_pointer_smooths_small_wobbles_and_follows_real_moves() -> void:
	var pointer: XRPointer = auto_free(XRPointer.new()) as XRPointer
	pointer.steadying = 0.7
	add_child(pointer)
	pointer.update_ray()
	# A one-degree wobble moves the ray only part of the way.
	pointer.rotate_y(deg_to_rad(1.0))
	pointer.update_ray()
	var aimed: Vector3 = -pointer.global_transform.basis.z
	var lag_degrees: float = rad_to_deg(pointer.ray_direction.angle_to(aimed))
	assert_float(lag_degrees).is_greater(0.3)
	assert_float(lag_degrees).is_less(1.0)
	# A real turn is followed at once.
	pointer.rotate_y(deg_to_rad(25.0))
	pointer.update_ray()
	assert_float(rad_to_deg(pointer.ray_direction.angle_to(-pointer.global_transform.basis.z))).is_less(0.01)


func test_unsteadied_pointer_points_straight() -> void:
	var pointer: XRPointer = auto_free(XRPointer.new()) as XRPointer
	add_child(pointer)
	pointer.rotate_y(deg_to_rad(1.0))
	pointer.update_ray()
	assert_float(rad_to_deg(pointer.ray_direction.angle_to(-pointer.global_transform.basis.z))).is_less(0.01)


func test_furniture_in_a_culled_room_still_blocks() -> void:
	var cull: ProximityCull = auto_free(ProximityCull.new()) as ProximityCull
	var hidden_parent: Node3D = auto_free(Node3D.new()) as Node3D
	var culled_table: WalkBlocker = WalkBlocker.new()
	var hidden_table: WalkBlocker = WalkBlocker.new()
	add_child(cull)
	add_child(hidden_parent)
	cull.add_child(culled_table)
	hidden_parent.add_child(hidden_table)
	cull.visible = false
	hidden_parent.visible = false
	assert_bool(culled_table.is_blocking()).is_true()
	assert_bool(hidden_table.is_blocking()).is_false()

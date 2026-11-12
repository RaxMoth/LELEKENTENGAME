## Unit tests for PropScatter3D's placement math (x, z, scale, yaw -> transform).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite

const TOLERANCE: float = 0.0001


func test_placement_sits_on_the_ground_plane() -> void:
	var placement: Transform3D = PropScatter3D.get_placement_transform(Vector4(2.5, -7.0, 1.0, 0.0))
	assert_vector(placement.origin).is_equal_approx(Vector3(2.5, 0.0, -7.0), Vector3.ONE * TOLERANCE)
	assert_vector(placement.basis.y).is_equal_approx(Vector3.UP, Vector3.ONE * TOLERANCE)


func test_placement_scales_uniformly() -> void:
	var placement: Transform3D = PropScatter3D.get_placement_transform(Vector4(0.0, 0.0, 1.5, 37.0))
	assert_vector(placement.basis.get_scale()).is_equal_approx(Vector3.ONE * 1.5, Vector3.ONE * TOLERANCE)


func test_placement_yaw_turns_around_up() -> void:
	var placement: Transform3D = PropScatter3D.get_placement_transform(Vector4(0.0, 0.0, 1.0, 90.0))
	# A quarter turn to the left (counter-clockwise seen from above) takes +X to -Z.
	assert_vector(placement.basis * Vector3.RIGHT).is_equal_approx(Vector3.FORWARD, Vector3.ONE * TOLERANCE)
	assert_vector(placement.basis * Vector3.UP).is_equal_approx(Vector3.UP, Vector3.ONE * TOLERANCE)

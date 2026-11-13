## Unit tests for SnapshotBuffer: synced things move evenly between the
## host's snapshots, carry on briefly past the newest, then hold still.
##
## Dependencies: gdUnit4, SnapshotBuffer
extends GdUnitTestSuite

const TOLERANCE: float = 0.0001


func _at(x: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0))


func test_samples_between_snapshots_move_evenly() -> void:
	var buffer: SnapshotBuffer = SnapshotBuffer.new()
	buffer.push(1.0, _at(0.0))
	buffer.push(1.1, _at(1.0))
	buffer.push(1.2, _at(2.0))
	assert_float(buffer.sample(1.05).origin.x).is_equal_approx(0.5, TOLERANCE)
	assert_float(buffer.sample(1.15).origin.x).is_equal_approx(1.5, TOLERANCE)


func test_before_the_oldest_it_holds_the_oldest() -> void:
	var buffer: SnapshotBuffer = SnapshotBuffer.new()
	buffer.push(1.0, _at(3.0))
	buffer.push(1.1, _at(4.0))
	assert_float(buffer.sample(0.5).origin.x).is_equal_approx(3.0, TOLERANCE)


func test_past_the_newest_it_carries_on_briefly_then_stops() -> void:
	var buffer: SnapshotBuffer = SnapshotBuffer.new()
	buffer.push(1.0, _at(0.0))
	buffer.push(1.1, _at(1.0))
	assert_float(buffer.sample(1.15).origin.x).is_equal_approx(1.5, TOLERANCE)
	var limit: float = 1.0 + SnapshotBuffer.MAX_EXTRAPOLATION_SECONDS / 0.1
	assert_float(buffer.sample(5.0).origin.x).is_equal_approx(limit, TOLERANCE)


func test_one_snapshot_or_a_repeat_is_held() -> void:
	var buffer: SnapshotBuffer = SnapshotBuffer.new()
	assert_bool(buffer.is_empty()).is_true()
	buffer.push(1.0, _at(2.0))
	assert_float(buffer.sample(3.0).origin.x).is_equal_approx(2.0, TOLERANCE)
	buffer.push(1.0, _at(5.0))
	assert_float(buffer.get_latest().origin.x).is_equal_approx(5.0, TOLERANCE)


func test_keeps_only_the_newest_snapshots() -> void:
	var buffer: SnapshotBuffer = SnapshotBuffer.new()
	for step: int in 10:
		buffer.push(float(step), _at(float(step)))
	# The oldest kept is 10 - MAX_SNAPSHOTS.
	assert_float(buffer.sample(0.0).origin.x).is_equal_approx(float(10 - SnapshotBuffer.MAX_SNAPSHOTS), TOLERANCE)


func test_a_jump_cuts_instead_of_gliding() -> void:
	var buffer: SnapshotBuffer = SnapshotBuffer.new()
	buffer.push(1.0, _at(0.0))
	buffer.push(1.1, _at(SnapshotBuffer.JUMP_DISTANCE + 3.0))
	# No glide through the room in between: it is already at the new place.
	assert_float(buffer.sample(1.05).origin.x).is_equal_approx(SnapshotBuffer.JUMP_DISTANCE + 3.0, TOLERANCE)

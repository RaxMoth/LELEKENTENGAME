## Where one synced thing was, as the host sent it, a few times a second.
## Sampling it a moment in the past (INTERPOLATION_DELAY) moves evenly
## between the two snapshots around that moment, so a walking customer, a
## raider or the other player glides at constant speed instead of jumping
## or easing at 15–20 Hz. A late snapshot is bridged by carrying on for a
## little (MAX_EXTRAPOLATION_SECONDS), then it holds still.
##
##   buffer.push(now, host_transform)                 # on every snapshot
##   node.global_transform = buffer.sample(now - SnapshotBuffer.INTERPOLATION_DELAY)
##
## Dependencies: none
class_name SnapshotBuffer
extends RefCounted

## How far in the past synced things are shown (a bit more than one 15 Hz
## snapshot interval, so there is nearly always a snapshot on both sides).
const INTERPOLATION_DELAY: float = 0.1
## How long a missing snapshot is bridged by carrying on.
const MAX_EXTRAPOLATION_SECONDS: float = 0.1
## Snapshots kept (the newest ones).
const MAX_SNAPSHOTS: int = 4

var _times: Array[float] = []
var _transforms: Array[Transform3D] = []


## Adds the transform the host sent, arriving at [param time] (seconds).
func push(time: float, transform: Transform3D) -> void:
	if not _times.is_empty() and time <= _times.back():
		# Same instant (or out of order): the newer value wins.
		_transforms[_transforms.size() - 1] = transform
		return
	_times.append(time)
	_transforms.append(transform)
	if _times.size() > MAX_SNAPSHOTS:
		_times.remove_at(0)
		_transforms.remove_at(0)


func is_empty() -> bool:
	return _times.is_empty()


## The newest transform the host sent.
func get_latest() -> Transform3D:
	return _transforms.back() if not _transforms.is_empty() else Transform3D.IDENTITY


## Where the thing was at [param time]: between the snapshots around it,
## carried on a little past the newest, never before the oldest.
func sample(time: float) -> Transform3D:
	if _times.is_empty():
		return Transform3D.IDENTITY
	if _times.size() == 1 or time <= _times[0]:
		return _transforms[0] if time <= _times[0] else _transforms.back()
	for index: int in range(1, _times.size()):
		if time <= _times[index]:
			var share: float = inverse_lerp(_times[index - 1], _times[index], time)
			return _transforms[index - 1].interpolate_with(_transforms[index], share)
	# Past the newest: carry on along the last step for a moment.
	var last: int = _times.size() - 1
	var step_seconds: float = maxf(0.0001, _times[last] - _times[last - 1])
	var beyond: float = minf(time - _times[last], MAX_EXTRAPOLATION_SECONDS)
	return _transforms[last - 1].interpolate_with(_transforms[last], 1.0 + beyond / step_seconds)

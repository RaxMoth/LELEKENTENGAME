## The rules of walking in VR: arm-swing running (both grips held, swing the
## arms like jogging — the faster the swing, the faster the walk), easing
## into and out of a walk instead of jumping to full speed, sprinting with
## the stick pushed all the way, and where footsteps fall.
##
##   var speed: float = WalkMotion.get_arm_swing_speed(left_velocity, right_velocity)
##   velocity = WalkMotion.ease_velocity(velocity, target_velocity, delta)
##
## Pure functions (unit-tested in Tests/Unit/walk_motion_test.gd).
##
## Dependencies: none
class_name WalkMotion
extends RefCounted

## Hand speed (m/s, both hands averaged) below which swinging doesn't move you.
const SWING_DEADZONE: float = 0.35
## Walking speed per m/s of hand swing.
const SWING_GAIN: float = 1.9
## Fastest arm-swing run (m/s).
const MAX_SWING_SPEED: float = 4.0
## m/s² when speeding up and when slowing down (stopping is quicker).
const ACCELERATION: float = 7.0
const DECELERATION: float = 11.0
## Stick pushed past this counts as sprinting...
const SPRINT_STICK: float = 0.95
## ...at this multiple of the walking speed.
const SPRINT_MULTIPLIER: float = 1.6
## Meters between two footsteps.
const STRIDE_METERS: float = 0.75


## Walking speed from how fast the hands move (their velocities in the play
## space). Only swinging counts: a hand at rest or moving one way stays
## slow because both hands are averaged. 0 below the deadzone.
static func get_arm_swing_speed(left_velocity: Vector3, right_velocity: Vector3) -> float:
	# Up/down and forward/back swing both count; sideways sweeps don't.
	var left_swing: float = Vector2(left_velocity.y, left_velocity.z).length()
	var right_swing: float = Vector2(right_velocity.y, right_velocity.z).length()
	var hand_speed: float = (left_swing + right_swing) * 0.5
	if hand_speed < SWING_DEADZONE:
		return 0.0
	return minf(MAX_SWING_SPEED, (hand_speed - SWING_DEADZONE) * SWING_GAIN)


## Moves [param velocity] toward [param target] — quicker when slowing down,
## so stopping feels firm and starting smooth.
static func ease_velocity(velocity: Vector3, target: Vector3, delta: float) -> Vector3:
	var rate: float = ACCELERATION if target.length() > velocity.length() else DECELERATION
	return velocity.move_toward(target, rate * delta)


## Stick walking speed: walk speed scaled by how far the stick is pushed,
## sprinting when it is pushed all the way.
static func get_stick_speed(stick: Vector2, walk_speed: float) -> float:
	var push: float = minf(1.0, stick.length())
	return walk_speed * push * (SPRINT_MULTIPLIER if push >= SPRINT_STICK else 1.0)


## How many footsteps fall when [param distance] meters are walked with
## [param carried] meters already walked since the last one. Returns
## [steps, new carried distance].
static func count_footsteps(carried: float, distance: float) -> Array[float]:
	var total: float = carried + maxf(0.0, distance)
	var steps: int = floori(total / STRIDE_METERS)
	return [float(steps), total - steps * STRIDE_METERS]

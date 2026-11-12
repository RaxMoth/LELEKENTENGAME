## Comfort math for seated play: how far to lift the play space so a player
## sitting in a chair sees (and reaches) the world like a standing person.
## Only ever lifts: a player who is already standing tall is left alone.
##
##   var lift: float = StandingView.get_lift(camera.position.y, 1.65)
##
## Dependencies: none
class_name StandingView
extends RefCounted

## A head lower than this above the floor means the headset has no floor
## reference (or lost tracking): don't trust it for a lift.
const MIN_TRUSTED_HEAD_HEIGHT: float = 0.3


## Meters to raise the play space so a head at [param head_height] above
## the real floor ends up at [param standing_eye_height].
static func get_lift(head_height: float, standing_eye_height: float) -> float:
	if head_height < MIN_TRUSTED_HEAD_HEIGHT:
		return 0.0
	return maxf(0.0, standing_eye_height - head_height)

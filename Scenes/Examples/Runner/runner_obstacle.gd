## Pooled obstacle that scrolls left at the shared world speed and damages the runner.
##
## Dependencies: HitboxComponent, Pools autoload
class_name RunnerObstacle
extends HitboxComponent

## Shared scroll speed, driven by the runner level.
static var scroll_speed: float = 0.0

@export var despawn_x: float = -200.0


func _physics_process(delta: float) -> void:
	super(delta)
	position.x -= scroll_speed * delta
	if global_position.x < despawn_x:
		Pools.despawn(self)

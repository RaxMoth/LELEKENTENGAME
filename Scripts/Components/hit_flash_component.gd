## Flashes a CanvasItem white when its HealthComponent takes damage.
##
## Dependencies: HealthComponent
class_name HitFlashComponent
extends Node

@export var flash_target: CanvasItem
@export var health_component: HealthComponent
@export var flash_color: Color = Color(4, 4, 4, 1)
@export var flash_seconds: float = 0.12

var _flash_tween: Tween


func _ready() -> void:
	if health_component != null:
		health_component.damaged.connect(func(_damage_info: DamageInfo) -> void: flash())


func flash() -> void:
	if flash_target == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	flash_target.modulate = flash_color
	_flash_tween = flash_target.create_tween()
	_flash_tween.tween_property(flash_target, "modulate", Color.WHITE, flash_seconds)


func reset() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	if flash_target != null:
		flash_target.modulate = Color.WHITE

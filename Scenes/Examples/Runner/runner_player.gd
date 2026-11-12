## One-tap runner hero: stays at a fixed x while the world scrolls, jumps
## (double jump, variable height) and dies on the first hit.
##
## Dependencies: PlatformerMovementComponent, HealthComponent, Audio, Platform autoloads
class_name RunnerPlayer
extends CharacterBody2D

signal died

@onready var movement: PlatformerMovementComponent = %PlatformerMovementComponent
@onready var health_component: HealthComponent = %HealthComponent
@onready var _visual: Node2D = %Visual

var is_running: bool = false


func _ready() -> void:
	add_to_group(Types.GROUP_PLAYER)
	movement.jumped.connect(_on_jumped)
	movement.landed.connect(func() -> void: TweenFX.punch_scale(_visual, 1.15, 0.12))
	health_component.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if health_component.is_dead:
		return
	if is_running and Input.is_action_just_pressed(Types.ACTION_JUMP):
		movement.request_jump()
	if Input.is_action_just_released(Types.ACTION_JUMP):
		movement.release_jump(self)
	movement.physics_update(self, 0.0, delta)
	_visual.rotation = clampf(velocity.y / 2000.0, -0.4, 0.4)


func jump_pressed() -> void:
	if is_running and not health_component.is_dead:
		movement.request_jump()


func jump_released() -> void:
	movement.release_jump(self)


func _on_jumped(jump_number: int) -> void:
	Audio.play_sfx(SfxSynth.get_preset(&"jump"), 0.05, -6.0)
	if jump_number > 1:
		var tween: Tween = create_tween()
		tween.tween_property(_visual, "rotation", _visual.rotation + TAU, 0.3)


func _on_died() -> void:
	Events.camera_shake_requested.emit(0.7)
	Platform.vibrate(Types.HapticStrength.HEAVY)
	Audio.play_sfx(SfxSynth.get_preset(&"explosion"))
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "modulate", Color(Palette.DANGER, 0.6), 0.2)
	died.emit()

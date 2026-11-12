## One-line "juice" tweens for UI and world objects.
##
##   TweenFX.pop(coin_label)
##   TweenFX.punch_scale(enemy_sprite, 1.2)
##   await TweenFX.fade_out(panel).finished
##
## Every helper returns the Tween so callers can chain or await it.
##
## Dependencies: none
class_name TweenFX
extends RefCounted


## Quick grow-and-settle, great for counters and rewards.
static func pop(target: CanvasItem, strength: float = 1.25, duration_seconds: float = 0.25) -> Tween:
	_center_pivot(target)
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "scale", Vector2.ONE * strength, duration_seconds * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, duration_seconds * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


## Scale from 0 with overshoot (spawning, appearing).
static func bounce_in(target: CanvasItem, duration_seconds: float = 0.35) -> Tween:
	_center_pivot(target)
	target.scale = Vector2.ZERO
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "scale", Vector2.ONE, duration_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


static func punch_scale(target: CanvasItem, strength: float = 1.15, duration_seconds: float = 0.15) -> Tween:
	return pop(target, strength, duration_seconds)


static func fade_in(target: CanvasItem, duration_seconds: float = 0.2) -> Tween:
	target.modulate.a = 0.0
	target.visible = true
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "modulate:a", 1.0, duration_seconds)
	return tween


static func fade_out(target: CanvasItem, duration_seconds: float = 0.2, hide_when_done: bool = true) -> Tween:
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "modulate:a", 0.0, duration_seconds)
	if hide_when_done:
		tween.tween_callback(target.hide)
	return tween


## Horizontal shake for "not allowed" feedback (e.g. can't afford).
static func shake(target: CanvasItem, strength: float = 12.0, duration_seconds: float = 0.3) -> Tween:
	var origin: Vector2 = target.position
	var tween: Tween = target.create_tween()
	var step_count: int = 6
	for step_index: int in step_count:
		var direction: float = 1.0 if step_index % 2 == 0 else -1.0
		var falloff: float = 1.0 - float(step_index) / step_count
		tween.tween_property(target, "position", origin + Vector2(strength * direction * falloff, 0.0), duration_seconds / step_count)
	tween.tween_property(target, "position", origin, duration_seconds / step_count)
	return tween


## Continuous gentle pulse (call-to-action buttons). Kill the tween to stop.
static func pulse_loop(target: CanvasItem, strength: float = 1.06, period_seconds: float = 1.0) -> Tween:
	_center_pivot(target)
	var tween: Tween = target.create_tween().set_loops()
	tween.tween_property(target, "scale", Vector2.ONE * strength, period_seconds * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "scale", Vector2.ONE, period_seconds * 0.5).set_trans(Tween.TRANS_SINE)
	return tween


## Animates a whole-number label from [param from_value] to [param to_value]
## (intermediate values are rounded, so a counter never shows "103.1").
## [param formatter] receives a float and returns a String (defaults to NumberFormat.compact).
static func count_label(label: Label, from_value: float, to_value: float, duration_seconds: float = 0.4, formatter: Callable = Callable()) -> Tween:
	var number_formatter: Callable = formatter if formatter.is_valid() else NumberFormat.compact
	var tween: Tween = label.create_tween()
	tween.tween_method(func(current_value: float) -> void: label.text = number_formatter.call(roundf(current_value)), from_value, to_value, duration_seconds)
	return tween


static func _center_pivot(target: CanvasItem) -> void:
	if target is Control:
		(target as Control).pivot_offset = (target as Control).size * 0.5

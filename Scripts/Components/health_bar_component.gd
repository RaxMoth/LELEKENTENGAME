## Small world-space health bar bound to a HealthComponent.
##
## Dependencies: HealthComponent
class_name HealthBarComponent
extends ProgressBar

@export var health_component: HealthComponent
@export var hide_when_full: bool = true
@export var fill_color: Color = Palette.SUCCESS

var _value_tween: Tween


func _ready() -> void:
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(4)
	add_theme_stylebox_override("fill", fill_style)
	if health_component != null:
		health_component.health_changed.connect(_on_health_changed)
		_on_health_changed(health_component.max_health, health_component.max_health)


func _on_health_changed(current_health: float, max_health: float) -> void:
	max_value = max_health
	visible = not (hide_when_full and current_health >= max_health)
	if _value_tween != null:
		_value_tween.kill()
	if current_health >= max_health:
		value = current_health
		return
	_value_tween = create_tween()
	_value_tween.tween_property(self, "value", current_health, 0.15)

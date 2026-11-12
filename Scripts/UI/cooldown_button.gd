## Button that shows a cooldown curtain + countdown. Bind it to an AbilityComponent
## slot or drive it manually with start_cooldown().
##
## Dependencies: AbilityComponent (optional)
class_name CooldownButton
extends Button

@export var ability_component: AbilityComponent
@export var ability_index: int = 0
@export var overlay_color: Color = Color(Palette.BACKGROUND, 0.6)

var _cooldown_total: float = 0.0
var _cooldown_remaining: float = 0.0


func _ready() -> void:
	if ability_component != null:
		bind_ability(ability_component, ability_index)


func bind_ability(component: AbilityComponent, slot_index: int) -> void:
	ability_component = component
	ability_index = slot_index
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	component.cooldown_started.connect(func(started_index: int, duration_seconds: float) -> void:
		if started_index == ability_index:
			start_cooldown(duration_seconds))
	var ability: AbilityData = component.get_ability(slot_index)
	if ability != null and text.is_empty() and icon == null:
		text = ability.title
		icon = ability.icon


func start_cooldown(duration_seconds: float) -> void:
	_cooldown_total = duration_seconds
	_cooldown_remaining = duration_seconds
	disabled = duration_seconds > 0.0


func _process(delta: float) -> void:
	if _cooldown_remaining <= 0.0:
		return
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _cooldown_remaining <= 0.0:
		disabled = false
		TweenFX.pop(self, 1.1)
	queue_redraw()


func _on_pressed() -> void:
	if ability_component != null:
		ability_component.try_activate(ability_index)


func _draw() -> void:
	if _cooldown_remaining <= 0.0 or _cooldown_total <= 0.0:
		return
	# Dark curtain that shrinks downward as the cooldown runs out.
	var ratio: float = clampf(_cooldown_remaining / _cooldown_total, 0.0, 1.0)
	var curtain: StyleBoxFlat = StyleBoxFlat.new()
	curtain.bg_color = overlay_color
	curtain.set_corner_radius_all(18)
	draw_style_box(curtain, Rect2(0.0, size.y * (1.0 - ratio), size.x, size.y * ratio))
	draw_string(get_theme_default_font(), Vector2(0.0, size.y * 0.5 + 12.0), "%.1f" % _cooldown_remaining, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32)

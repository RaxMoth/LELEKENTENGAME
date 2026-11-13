## A small health bar floating over an entity (raiders): the share of
## health left, always facing the camera (the billboard runs on the GPU,
## Assets/Shaders/health_bar.gdshader). It follows its HealthComponent's
## signals — no per-frame work — and hides once the entity is dead. Far
## away it isn't drawn (visibility_range_end). Pooled entities are fine:
## a revive shows it full again.
##
##   HealthBar3D (in the entity's scene, above its head)
##       health_component = ../HealthComponent
##
## Dependencies: HealthComponent, Palette
class_name HealthBar3D
extends MeshInstance3D

const SHADER: Shader = preload("res://Assets/Shaders/health_bar.gdshader")

## The health it shows (wired in the scene).
@export var health_component: HealthComponent
## Width and height of the bar (meters).
@export var bar_size: Vector2 = Vector2(0.6, 0.075)
@export var fill_color: Color = Palette.DANGER
## Shown at full health too (false: only after the first hit).
@export var shows_at_full_health: bool = true

var _material: ShaderMaterial = null
var _shown_ratio: float = -1.0


func _ready() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = bar_size
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"fill_color", fill_color)
	_material.set_shader_parameter(&"empty_color", Palette.SURFACE_RAISED)
	_material.set_shader_parameter(&"border_color", Palette.BACKGROUND)
	_material.set_shader_parameter(&"aspect", bar_size.x / maxf(0.001, bar_size.y))
	material_override = _material
	if health_component != null:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_refresh)
		_on_health_changed(health_component.current_health, health_component.max_health)


## The share of health it shows now (0..1).
func get_shown_ratio() -> float:
	return _shown_ratio


func _on_health_changed(current_health: float, max_health: float) -> void:
	var ratio: float = clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
	if not is_equal_approx(ratio, _shown_ratio):
		_shown_ratio = ratio
		_material.set_shader_parameter(&"fill", ratio)
	_refresh()


func _refresh() -> void:
	var is_dead: bool = health_component == null or health_component.is_dead
	visible = not is_dead and (shows_at_full_health or _shown_ratio < 1.0)

## One buildable tower on the BuildBoard: icon, name and cash cost, with a
## selection frame, a dimmed look while unaffordable, a lock while its
## upgrade is missing and a cooldown curtain. Only displays state.
##
## Dependencies: TowerData, IconLabel, Palette
class_name TowerCard
extends Button

const CORNER_RADIUS: int = 20
const FRAME_WIDTH: int = 5
const UNAFFORDABLE_OPACITY: float = 0.4
const CURTAIN_OPACITY: float = 0.72
const LOCK_ICON: Texture2D = preload("res://Assets/Icons/lock.svg")

var data: TowerData = null

var _is_selected: bool = false
var _cooldown_ratio: float = 0.0
var _frame_style: StyleBoxFlat = null
var _curtain_style: StyleBoxFlat = null

@onready var _icon_rect: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _cost_label: IconLabel = %CostLabel
@onready var _content: Control = %Content
@onready var _overlay: Control = %Overlay


func _ready() -> void:
	_frame_style = StyleBoxFlat.new()
	_frame_style.draw_center = false
	_frame_style.border_color = Palette.PRIMARY
	_frame_style.set_border_width_all(FRAME_WIDTH)
	_frame_style.set_corner_radius_all(CORNER_RADIUS)
	_curtain_style = StyleBoxFlat.new()
	_curtain_style.bg_color = Color(Palette.BACKGROUND, CURTAIN_OPACITY)
	_curtain_style.set_corner_radius_all(CORNER_RADIUS)


func set_data(tower_data: TowerData) -> void:
	data = tower_data
	_icon_rect.texture = tower_data.icon
	_icon_rect.self_modulate = tower_data.icon_color
	_name_label.text = tr(tower_data.display_name)
	_cost_label.text = str(tower_data.cost)


func set_selected(is_selected: bool) -> void:
	_is_selected = is_selected
	_overlay.queue_redraw()


func set_affordable(is_affordable: bool) -> void:
	_content.modulate.a = 1.0 if is_affordable else UNAFFORDABLE_OPACITY


## Locked towers show a lock instead of their icon.
func set_locked(is_locked: bool) -> void:
	disabled = is_locked
	_icon_rect.texture = LOCK_ICON if is_locked else data.icon
	_icon_rect.self_modulate = Palette.TEXT_FAINT if is_locked else data.icon_color


## [param ratio] 1 = cooldown just started, 0 = ready.
func set_cooldown_ratio(ratio: float) -> void:
	if is_equal_approx(ratio, _cooldown_ratio):
		return
	_cooldown_ratio = clampf(ratio, 0.0, 1.0)
	_overlay.queue_redraw()


## Drawn on a child above the content, so the curtain covers icon and text.
func _on_overlay_draw() -> void:
	if _cooldown_ratio > 0.0:
		_overlay.draw_style_box(_curtain_style, Rect2(Vector2.ZERO, Vector2(size.x, size.y * _cooldown_ratio)))
	if _is_selected:
		_overlay.draw_style_box(_frame_style, Rect2(Vector2.ZERO, size))

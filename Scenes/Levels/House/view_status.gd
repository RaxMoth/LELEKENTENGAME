## Two small panels that move with the player's view: their health in the
## top right (a heart, a bar and the points) and what their hands hold at
## the bottom center ("Shrooms ×3 · Okay"). They hang half a meter in front
## of the camera — the headset's or the flat simulator's — near the edge of
## the view (in a headset well inside the lenses' clear area), drawn over
## the world so a wall in front of the face never hides them. Nothing here
## moves the camera; the panels follow the head.
##
##   view_status.setup(rig)                      # hangs on rig.get_view_camera()
##   vitals.health_changed.connect(view_status.show_health)
##
## Dependencies: XRPlayerRig, Grabbable, Palette
class_name ViewStatus
extends Node3D

## Health shares below which the bar turns amber (hurt) and red (low) — as the wrist.
const HURT_HEALTH_RATIO: float = WristStatus.HURT_HEALTH_RATIO
const LOW_HEALTH_RATIO: float = WristStatus.LOW_HEALTH_RATIO
## Drawn after the world and the other in-world UI.
const RENDER_PRIORITY: int = 20
## Seconds between two looks at the hands (a held item has no signal for every way it leaves a hand).
const HANDS_POLL_SECONDS: float = 0.2

## Meters in front of the eyes.
@export var depth: float = 0.5
## Headset: how far up/right of center the health panel sits, and down the
## hands panel (degrees; the lenses are clear within about 20°).
@export var headset_health_angles_degrees: Vector2 = Vector2(17.0, 13.0)
@export var headset_hands_angle_degrees: float = 16.0
## Headset: the panels drawn this much larger (text needs ~1.5° to read in lenses).
@export var headset_scale: float = 1.4
## Flat simulator: gap to the window's edge (pixels).
@export var flat_margin_pixels: float = 24.0
## Empty space left and right of the hands panel's text (meters).
@export var hands_padding: float = 0.012

var _rig: XRPlayerRig = null
var _camera: Camera3D = null
var _shown_health: int = -1
var _shown_hands: String = "\n"
var _seconds_until_hands_poll: float = 0.0

@onready var _health_panel: Node3D = %HealthPanel
@onready var _health_backdrop: MeshInstance3D = %HealthBackdrop
@onready var _heart: Sprite3D = %Heart
@onready var _bar_back: MeshInstance3D = %BarBack
@onready var _bar_fill: MeshInstance3D = %BarFill
@onready var _health_label: Label3D = %HealthValue
@onready var _hands_panel: Node3D = %HandsPanel
@onready var _hands_backdrop: MeshInstance3D = %HandsBackdrop
@onready var _hands_icon: Sprite3D = %HandsIcon
@onready var _hands_label: Label3D = %HandsLabel


func _ready() -> void:
	_health_backdrop.material_override = _make_overlay_material(Color(Palette.BACKGROUND, 0.82), RENDER_PRIORITY)
	_hands_backdrop.material_override = _make_overlay_material(Color(Palette.BACKGROUND, 0.82), RENDER_PRIORITY)
	_bar_back.material_override = _make_overlay_material(Palette.SURFACE_RAISED, RENDER_PRIORITY + 1)
	_bar_fill.material_override = _make_overlay_material(Palette.SUCCESS, RENDER_PRIORITY + 2)
	for sprite: Sprite3D in [_heart, _hands_icon]:
		sprite.no_depth_test = true
		sprite.render_priority = RENDER_PRIORITY + 2
	set_process(false)


func _process(delta: float) -> void:
	_seconds_until_hands_poll -= delta
	if _seconds_until_hands_poll > 0.0:
		return
	_seconds_until_hands_poll = HANDS_POLL_SECONDS
	_refresh_hands()

# ============================================
# PUBLIC API
# ============================================

## Hangs the panels in front of [param rig]'s camera and starts watching its hands.
func setup(rig: XRPlayerRig) -> void:
	_rig = rig
	_camera = rig.get_view_camera()
	if get_parent() != null:
		get_parent().remove_child(self)
	_camera.add_child(self)
	transform = Transform3D.IDENTITY
	if not get_viewport().size_changed.is_connected(_place_panels):
		get_viewport().size_changed.connect(_place_panels)
	_place_panels()
	set_process(true)
	_refresh_hands()


## The player's health (PlayerVitals): a green bar, amber when hurt, red when low.
func show_health(current: float, maximum: float) -> void:
	var whole_points: int = ceili(current)
	if whole_points == _shown_health:
		return
	_shown_health = whole_points
	var ratio: float = clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	var bar_color: Color = Palette.SUCCESS if ratio > HURT_HEALTH_RATIO else (Palette.WARNING if ratio > LOW_HEALTH_RATIO else Palette.DANGER)
	(_bar_fill.material_override as StandardMaterial3D).albedo_color = bar_color
	_heart.modulate = Palette.DANGER if ratio <= LOW_HEALTH_RATIO else Palette.TEXT
	# The fill grows from the bar's left end.
	var bar_width: float = (_bar_back.mesh as QuadMesh).size.x
	_bar_fill.scale.x = maxf(0.001, ratio)
	_bar_fill.position.x = _bar_back.position.x - bar_width * 0.5 * (1.0 - ratio)
	_health_label.text = str(whole_points)


## What the hands hold now, in words (empty: nothing).
func get_hands_text() -> String:
	return _shown_hands

# ============================================
# INTERNALS
# ============================================

func _refresh_hands() -> void:
	if _rig == null:
		return
	var names: PackedStringArray = PackedStringArray()
	for item: Grabbable in _rig.get_held_items():
		if is_instance_valid(item):
			var item_name: String = item.get_display_name()
			if not item_name.is_empty():
				names.append(item_name)
	var hands_text: String = "   ".join(names)
	if hands_text == _shown_hands:
		return
	_shown_hands = hands_text
	var is_empty: bool = names.is_empty()
	_hands_label.text = tr("Hands empty") if is_empty else hands_text
	_hands_label.modulate = Palette.TEXT_MUTED if is_empty else Palette.TEXT
	_hands_icon.modulate = Palette.TEXT_MUTED if is_empty else Palette.GOLD
	_fit_hands_panel()


## Sizes the hands panel's backdrop to its text and centers icon + text.
func _fit_hands_panel() -> void:
	var font: Font = _hands_label.font if _hands_label.font != null else ThemeDB.fallback_font
	var text_width: float = font.get_string_size(_hands_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _hands_label.font_size).x * _hands_label.pixel_size
	var icon_width: float = _hands_icon.texture.get_width() * _hands_icon.pixel_size if _hands_icon.texture != null else 0.0
	var gap: float = hands_padding * 0.6
	var content_width: float = icon_width + gap + text_width
	var quad: QuadMesh = _hands_backdrop.mesh as QuadMesh
	quad.size.x = content_width + hands_padding * 2.0
	_hands_icon.position.x = -content_width * 0.5 + icon_width * 0.5
	_hands_label.position.x = -content_width * 0.5 + icon_width + gap


func _place_panels() -> void:
	if _camera == null or not is_inside_tree():
		return
	var health_half: Vector2 = (_health_backdrop.mesh as QuadMesh).size * 0.5
	var hands_half_height: float = (_hands_backdrop.mesh as QuadMesh).size.y * 0.5
	var panel_scale: float = headset_scale if _rig.is_xr_active else 1.0
	_health_panel.scale = Vector3.ONE * panel_scale
	_hands_panel.scale = Vector3.ONE * panel_scale
	if _rig.is_xr_active:
		var health_angles: Vector2 = headset_health_angles_degrees
		_health_panel.position = Vector3(tan(deg_to_rad(health_angles.x)) * depth, tan(deg_to_rad(health_angles.y)) * depth, -depth)
		_hands_panel.position = Vector3(0.0, -tan(deg_to_rad(headset_hands_angle_degrees)) * depth, -depth)
		return
	# Flat simulator: pinned to the window's corner / bottom edge at this depth.
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var top_right: Vector3 = _camera.to_local(_camera.project_position(Vector2(view_size.x - flat_margin_pixels, flat_margin_pixels), depth))
	var bottom_center: Vector3 = _camera.to_local(_camera.project_position(Vector2(view_size.x * 0.5, view_size.y - flat_margin_pixels), depth))
	_health_panel.position = Vector3(top_right.x - health_half.x, top_right.y - health_half.y, -depth)
	_hands_panel.position = Vector3(0.0, bottom_center.y + hands_half_height, -depth)


## Unshaded, drawn over everything (a wall right in front of the face can't hide it).
static func _make_overlay_material(color: Color, priority: int) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = priority
	return material

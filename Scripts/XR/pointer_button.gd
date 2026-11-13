## A physical button in the world (a station's "stop" plunger, a door bell):
## pressed with a controller ray and trigger, or a click in the flat
## simulator. Shows a cap that dips when pressed and a caption.
##
## Dependencies: PlaceholderMesh3D, Palette, Audio, Types autoloads
class_name PointerButton
extends Node3D

signal pressed(button: PointerButton)

const PRESS_DEPTH: float = 0.02
const PRESS_SECONDS: float = 0.08
const DISABLED_OPACITY: float = 0.35
## Captions are drawn only within this distance.
const CAPTION_VISIBLE_METERS: float = 8.0

## Radius of the sphere the pointer ray hits.
@export var press_radius: float = 0.09
@export var caption: String = "":
	set(value):
		caption = value
		if _caption_label != null:
			_caption_label.text = value
@export var color: Color = Palette.PRIMARY:
	set(value):
		color = value
		_apply_color()

## Off = no cap, base or caption: an invisible hot spot on something that
## already looks pressable (a door handle that also takes the trigger).
@export var has_visual: bool = true

var is_enabled: bool = true:
	set(value):
		if is_enabled == value:
			return
		is_enabled = value
		_apply_color()

var _cap: MeshInstance3D = null
var _caption_label: Label3D = null
var _tween: Tween


func _ready() -> void:
	add_to_group(Types.GROUP_POINTER_BUTTON)
	if not has_visual:
		return
	var base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = press_radius * 1.15
	base_mesh.bottom_radius = press_radius * 1.25
	base_mesh.height = 0.03
	base.mesh = base_mesh
	base.material_override = PlaceholderMesh3D.get_shared_material(Palette.SURFACE)
	base.position.y = 0.015
	add_child(base)
	_cap = MeshInstance3D.new()
	var cap_mesh: CylinderMesh = CylinderMesh.new()
	cap_mesh.top_radius = press_radius * 0.85
	cap_mesh.bottom_radius = press_radius * 0.9
	cap_mesh.height = 0.035
	_cap.mesh = cap_mesh
	_cap.position.y = 0.045
	add_child(_cap)
	_caption_label = Label3D.new()
	_caption_label.text = caption
	_caption_label.pixel_size = 0.0018
	_caption_label.font_size = 44
	_caption_label.outline_size = 10
	_caption_label.outline_modulate = Color(Palette.BACKGROUND, 0.9)
	_caption_label.modulate = Palette.TEXT
	_caption_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_caption_label.position = Vector3(0.0, 0.13, 0.0)
	# Too small to read from farther away; not drawing it saves a draw call per button.
	_caption_label.visibility_range_end = CAPTION_VISIBLE_METERS
	add_child(_caption_label)
	_apply_color()


## Called by a pointer. Returns false while disabled.
func press() -> bool:
	if not is_enabled:
		Audio.play_ui(Audio.UI_ERROR)
		return false
	if _cap != null:
		if _tween != null:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(_cap, "position:y", 0.045 - PRESS_DEPTH, PRESS_SECONDS)
		_tween.tween_property(_cap, "position:y", 0.045, PRESS_SECONDS * 1.5)
	Audio.play_ui(Audio.UI_CLICK)
	pressed.emit(self)
	return true


func get_press_center() -> Vector3:
	if not has_visual:
		return global_position
	return global_position + global_transform.basis.y * 0.05


func _apply_color() -> void:
	if _cap == null:
		return
	_cap.material_override = PlaceholderMesh3D.get_shared_material(color if is_enabled else Color(Palette.STROKE, 1.0), 0.6 if is_enabled else 0.0)
	_caption_label.modulate = Color(Palette.TEXT, 1.0 if is_enabled else DISABLED_OPACITY)

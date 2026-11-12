## An icon followed by text: amounts, prices, star totals, rewards. Use it
## instead of text glyphs like "●" or "★" so every screen shares the icon set
## in Assets/Icons.
##
##   var price: IconLabel = IconLabel.create(coin_icon, "1.2K")
##   var total: IconLabel = IconLabel.create(STAR_ICON, "12 / 15", 32, Palette.STAR)
##
## Dependencies: none
@tool
class_name IconLabel
extends HBoxContainer

@export var icon: Texture2D:
	set(value):
		icon = value
		_apply()
@export var text: String = "":
	set(value):
		text = value
		_apply()
@export var icon_size: int = 36:
	set(value):
		icon_size = value
		_apply()
## Tint for monochrome (white) icons; leave white for full-color icons.
@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		_apply()
## Theme type variation of the label (e.g. SmallLabel, HeaderLabel).
@export var label_theme_type: StringName = &"":
	set(value):
		label_theme_type = value
		_apply()

var _icon_rect: TextureRect
var _label: Label


static func create(icon_texture: Texture2D, label_text: String, size_pixels: int = 36, tint: Color = Color.WHITE) -> IconLabel:
	var icon_label: IconLabel = IconLabel.new()
	icon_label.icon = icon_texture
	icon_label.text = label_text
	icon_label.icon_size = size_pixels
	icon_label.icon_color = tint
	return icon_label


func _init() -> void:
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect = TextureRect.new()
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect, false, Node.INTERNAL_MODE_FRONT)
	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)
	_apply()


## The inner label, e.g. for TweenFX.count_label().
func get_label() -> Label:
	return _label


func _apply() -> void:
	if _label == null:
		return
	_icon_rect.texture = icon
	_icon_rect.visible = icon != null
	_icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon_rect.self_modulate = icon_color
	_label.text = text
	_label.visible = not text.is_empty()
	_label.theme_type_variation = label_theme_type

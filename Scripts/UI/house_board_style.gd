## The look of the boards that hang in the house (office, armory, sales
## window, recipe book, how-to poster, admin): the main theme re-colored warm
## and worn — dark stained wood, cream ink, brass where the app uses blue —
## so they belong to the shabby old house instead of looking like a phone
## app. Built at runtime from the main theme, so it follows every change to
## it. A WorldScreen with uses_house_style shows its content in it.
##
##   content.theme = HouseBoardStyle.get_theme()
##   HouseBoardStyle.to_house_color(Palette.PRIMARY)   # Palette.BRASS
##
## Unit-tested in Tests/Unit/house_board_style_test.gd.
##
## Dependencies: Palette
class_name HouseBoardStyle
extends RefCounted

const MAIN_THEME_PATH: String = "res://Assets/Themes/main_theme.tres"
## App color -> house color (the main theme was generated from these Palette values).
const COLOR_MAP: Array[Array] = [
	[Palette.BACKGROUND, Palette.BOARD_BACKGROUND],
	[Palette.BACKGROUND_RAISED, Palette.BOARD_BACKGROUND_RAISED],
	[Palette.SURFACE, Palette.BOARD_SURFACE],
	[Palette.SURFACE_RAISED, Palette.BOARD_SURFACE_RAISED],
	[Palette.STROKE, Palette.BOARD_STROKE],
	[Palette.TEXT, Palette.BOARD_INK],
	[Palette.TEXT_MUTED, Palette.BOARD_INK_MUTED],
	[Palette.TEXT_FAINT, Palette.BOARD_INK_FAINT],
	[Palette.PRIMARY, Palette.BRASS],
	[Palette.SUCCESS, Palette.BOARD_SUCCESS],
	[Palette.DANGER, Palette.BOARD_DANGER],
]
## A color this close (RGB distance) to an app color takes its house color,
## keeping its small offset (a hovered or pressed shade stays a shade).
const MATCH_DISTANCE: float = 0.12
## Any other clear blue (hue range, minimum saturation) turns brass-warm at its own brightness.
const BLUE_HUES: Vector2 = Vector2(0.55, 0.72)
const MIN_BLUE_SATURATION: float = 0.3
## Color overrides a board's controls may set in their own scenes.
const OVERRIDE_COLOR_NAMES: Array[StringName] = [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_disabled_color", &"font_outline_color", &"icon_normal_color", &"icon_hover_color", &"icon_pressed_color"]

static var _theme: Theme = null


## The house boards' theme (built once).
static func get_theme() -> Theme:
	if _theme == null:
		var main_theme: Theme = load(MAIN_THEME_PATH) as Theme
		_theme = build_theme(main_theme) if main_theme != null else Theme.new()
	return _theme


## The house version of [param color]: the nearest app color's house color
## (with the same small offset), or the color itself when it is none of them
## (a product's own color, gold, a gem).
static func to_house_color(color: Color) -> Color:
	var nearest_distance: float = INF
	var nearest_pair: Array = []
	for pair: Array in COLOR_MAP:
		var app_color: Color = pair[0]
		var distance: float = Vector3(color.r - app_color.r, color.g - app_color.g, color.b - app_color.b).length()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_pair = pair
	if nearest_pair.is_empty() or nearest_distance > MATCH_DISTANCE:
		if color.s >= MIN_BLUE_SATURATION and color.h >= BLUE_HUES.x and color.h <= BLUE_HUES.y:
			return Color.from_hsv(Palette.BRASS.h, minf(color.s, Palette.BRASS.s), color.v, color.a)
		return color
	var app: Color = nearest_pair[0]
	var house: Color = nearest_pair[1]
	return Color(clampf(house.r + color.r - app.r, 0.0, 1.0), clampf(house.g + color.g - app.g, 0.0, 1.0), clampf(house.b + color.b - app.b, 0.0, 1.0), color.a)


## A copy of [param source] with every color and flat style box re-colored.
static func build_theme(source: Theme) -> Theme:
	var theme: Theme = source.duplicate() as Theme
	for type_name: StringName in theme.get_type_list():
		for color_name: StringName in theme.get_color_list(type_name):
			theme.set_color(color_name, type_name, to_house_color(theme.get_color(color_name, type_name)))
		for box_name: StringName in theme.get_stylebox_list(type_name):
			var flat_box: StyleBoxFlat = theme.get_stylebox(box_name, type_name) as StyleBoxFlat
			if flat_box == null:
				continue
			var house_box: StyleBoxFlat = flat_box.duplicate() as StyleBoxFlat
			house_box.bg_color = to_house_color(flat_box.bg_color)
			house_box.border_color = to_house_color(flat_box.border_color)
			house_box.shadow_color = to_house_color(flat_box.shadow_color)
			theme.set_stylebox(box_name, type_name, house_box)
	return theme


## Re-colors the color overrides [param node] and the controls under it set
## in their own scenes (a row's blue detail text), which a theme can't reach.
static func restyle_tree(node: Node) -> void:
	var control: Control = node as Control
	if control != null:
		restyle_control(control)
	for child: Node in node.get_children():
		restyle_tree(child)


## Re-colors [param control]'s own color overrides.
static func restyle_control(control: Control) -> void:
	for color_name: StringName in OVERRIDE_COLOR_NAMES:
		if control.has_theme_color_override(color_name):
			control.add_theme_color_override(color_name, to_house_color(control.get_theme_color(color_name)))


## Drops the built theme (shutdown, or after the main theme changed).
static func clear_cache() -> void:
	_theme = null

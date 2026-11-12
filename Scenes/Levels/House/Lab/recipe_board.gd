## The lab's recipe book on the wall: one row per product with the
## combination that makes it (ingredients → product). A product shows only
## question marks until the player cooks it for the first time; one that
## isn't unlocked yet shows a lock where its outcome goes. Lives on a static
## WorldScreen, so the Lab asks for a redraw after every change.
##
##   board.show_recipes(lab.recipes, Profile.operation.discovered_recipe_ids, unlocked_ids)
##
## Dependencies: RecipeData, IngredientData, IconLabel, Palette
class_name RecipeBoard
extends Control

const QUESTION_ICON: Texture2D = preload("res://Assets/Icons/question.svg")
const LOCK_ICON: Texture2D = preload("res://Assets/Icons/lock.svg")
const PLUS_ICON: Texture2D = preload("res://Assets/Icons/plus.svg")
const ARROW_ICON: Texture2D = preload("res://Assets/Icons/arrow.svg")
## Diameter of an ingredient's or product's color swatch (pixels).
const SWATCH_SIZE: int = 64
const SWATCH_ICON_SIZE: int = 36
const JOINER_ICON_SIZE: int = 32
const ROW_HEIGHT: int = 112
const ENTRY_SEPARATION: int = 16
const ROW_SEPARATION: int = 24

@onready var _rows: VBoxContainer = %Rows
@onready var _found_label: IconLabel = %FoundLabel


## Rebuilds the book. [param discovered_ids]: products cooked at least once;
## [param unlocked_ids]: products the cooker takes right now.
func show_recipes(recipes: Array[RecipeData], discovered_ids: Array[StringName], unlocked_ids: Array[StringName]) -> void:
	for old_row: Node in _rows.get_children():
		_rows.remove_child(old_row)
		old_row.queue_free()
	var found_count: int = 0
	for recipe: RecipeData in recipes:
		var is_discovered: bool = discovered_ids.has(recipe.id)
		if is_discovered:
			found_count += 1
		_rows.add_child(_build_row(recipe, is_discovered, unlocked_ids.has(recipe.id)))
	_found_label.text = tr("%d / %d found") % [found_count, recipes.size()]


## Products shown as found (tests).
func get_found_count() -> int:
	var found_count: int = 0
	for row: Node in _rows.get_children():
		if bool(row.get_meta(&"is_discovered", false)):
			found_count += 1
	return found_count

# ============================================
# INTERNALS
# ============================================

func _build_row(recipe: RecipeData, is_discovered: bool, is_unlocked: bool) -> Control:
	var row: PanelContainer = PanelContainer.new()
	row.theme_type_variation = &"ChipPanel"
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	# A short book spreads its rows over the poster; a long one packs them.
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.set_meta(&"is_discovered", is_discovered)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", ROW_SEPARATION)
	row.add_child(line)
	for ingredient_index: int in recipe.ingredients.size():
		if ingredient_index > 0:
			line.add_child(_create_icon(PLUS_ICON, Palette.TEXT_FAINT, JOINER_ICON_SIZE))
		var ingredient: IngredientData = recipe.ingredients[ingredient_index]
		if is_discovered:
			line.add_child(_create_entry(ingredient.color, tr(ingredient.get_name_for(true)), &""))
		else:
			line.add_child(_create_unknown_entry(QUESTION_ICON, ""))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)
	line.add_child(_create_icon(ARROW_ICON, Palette.TEXT_MUTED, JOINER_ICON_SIZE))
	if is_discovered:
		line.add_child(_create_entry(recipe.color, tr(recipe.display_name), &"HeaderLabel"))
	elif is_unlocked:
		line.add_child(_create_unknown_entry(QUESTION_ICON, ""))
	else:
		line.add_child(_create_unknown_entry(LOCK_ICON, tr("Locked")))
	return row


## A color swatch and a name: an ingredient or product the player knows.
func _create_entry(swatch_color: Color, entry_name: String, label_theme_type: StringName) -> Control:
	var entry: HBoxContainer = HBoxContainer.new()
	entry.add_theme_constant_override(&"separation", ENTRY_SEPARATION)
	entry.add_child(_create_swatch(swatch_color, null))
	var label: Label = Label.new()
	label.text = entry_name
	label.theme_type_variation = label_theme_type
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	entry.add_child(label)
	return entry


## A blank swatch with an icon (question mark or lock) and an optional caption.
func _create_unknown_entry(icon: Texture2D, caption: String) -> Control:
	var entry: HBoxContainer = HBoxContainer.new()
	entry.add_theme_constant_override(&"separation", ENTRY_SEPARATION)
	entry.add_child(_create_swatch(Palette.STROKE, icon))
	if not caption.is_empty():
		var label: Label = Label.new()
		label.text = caption
		label.theme_type_variation = &"SmallLabel"
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entry.add_child(label)
	return entry


func _create_swatch(swatch_color: Color, icon: Texture2D) -> Control:
	var swatch: PanelContainer = PanelContainer.new()
	swatch.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = swatch_color
	style.set_corner_radius_all(SWATCH_SIZE / 2)
	swatch.add_theme_stylebox_override(&"panel", style)
	if icon != null:
		var center: CenterContainer = CenterContainer.new()
		center.add_child(_create_icon(icon, Palette.TEXT_MUTED, SWATCH_ICON_SIZE))
		swatch.add_child(center)
	return swatch


func _create_icon(icon: Texture2D, tint: Color, icon_size: int) -> TextureRect:
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = icon
	icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.self_modulate = tint
	return icon_rect

## The lab's recipe book on the wall: every product, open, with the
## combination that makes it (ingredients → product) — or "Grows on the
## plant" for shrooms. A product the lab can't make yet shows a lock and the
## upgrade it needs ("Needs Press"). Lives on a static WorldScreen, so the
## Lab asks for a redraw after every change.
##
##   board.show_recipes(lab.recipes, unlocked_ids, {&"fizz": "Recipe: Fizz"})
##
## Dependencies: RecipeData, IngredientData, IconLabel, Palette
class_name RecipeBoard
extends Control

const LOCK_ICON: Texture2D = preload("res://Assets/Icons/lock.svg")
const PLUS_ICON: Texture2D = preload("res://Assets/Icons/plus.svg")
const ARROW_ICON: Texture2D = preload("res://Assets/Icons/arrow.svg")
const SPROUT_ICON: Texture2D = preload("res://Assets/Icons/sprout.svg")
## Diameter of an ingredient's or product's color swatch (pixels).
const SWATCH_SIZE: int = 64
const SWATCH_ICON_SIZE: int = 36
const JOINER_ICON_SIZE: int = 32
const ROW_HEIGHT: int = 112
const ENTRY_SEPARATION: int = 16
const ROW_SEPARATION: int = 24
const META_IS_UNLOCKED: StringName = &"is_unlocked"

@onready var _rows: VBoxContainer = %Rows
@onready var _unlocked_label: IconLabel = %UnlockedLabel


## Rebuilds the book. [param unlocked_ids]: products the lab can make right
## now; [param unlock_titles]: per product id, the upgrade it still needs.
func show_recipes(recipes: Array[RecipeData], unlocked_ids: Array[StringName], unlock_titles: Dictionary[StringName, String]) -> void:
	for old_row: Node in _rows.get_children():
		_rows.remove_child(old_row)
		old_row.queue_free()
	var unlocked_count: int = 0
	for recipe: RecipeData in recipes:
		var is_unlocked: bool = unlocked_ids.has(recipe.id)
		if is_unlocked:
			unlocked_count += 1
		_rows.add_child(_build_row(recipe, is_unlocked, unlock_titles.get(recipe.id, "")))
	_unlocked_label.text = tr("%d / %d unlocked") % [unlocked_count, recipes.size()]


## Products the lab can make right now, as shown (tests).
func get_unlocked_count() -> int:
	var unlocked_count: int = 0
	for row: Node in _rows.get_children():
		if bool(row.get_meta(META_IS_UNLOCKED, false)):
			unlocked_count += 1
	return unlocked_count


## Rows in the book (tests).
func get_row_count() -> int:
	return _rows.get_child_count()

# ============================================
# INTERNALS
# ============================================

func _build_row(recipe: RecipeData, is_unlocked: bool, unlock_title: String) -> Control:
	var row: PanelContainer = PanelContainer.new()
	row.theme_type_variation = &"ChipPanel"
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	# A short book spreads its rows over the poster; a long one packs them.
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.set_meta(META_IS_UNLOCKED, is_unlocked)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", ROW_SEPARATION)
	row.add_child(line)
	if recipe.is_grown:
		line.add_child(_create_icon_entry(SPROUT_ICON, tr("Grows on the plant")))
	for ingredient_index: int in recipe.ingredients.size():
		if ingredient_index > 0:
			line.add_child(_create_icon(PLUS_ICON, Palette.TEXT_FAINT, JOINER_ICON_SIZE))
		var ingredient: IngredientData = recipe.ingredients[ingredient_index]
		line.add_child(_create_entry(ingredient.color, tr(ingredient.get_name_for(true)), &""))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)
	if not is_unlocked and not unlock_title.is_empty():
		line.add_child(_create_icon_entry(LOCK_ICON, tr("Needs %s") % tr(unlock_title)))
	line.add_child(_create_icon(ARROW_ICON, Palette.TEXT_MUTED, JOINER_ICON_SIZE))
	line.add_child(_create_entry(recipe.color if is_unlocked else Palette.STROKE, tr(recipe.display_name), &"HeaderLabel"))
	return row


## A color swatch and a name: an ingredient or a product.
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


## A blank swatch with an icon (a sprout, a lock) and a caption.
func _create_icon_entry(icon: Texture2D, caption: String) -> Control:
	var entry: HBoxContainer = HBoxContainer.new()
	entry.add_theme_constant_override(&"separation", ENTRY_SEPARATION)
	entry.add_child(_create_swatch(Palette.STROKE, icon))
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

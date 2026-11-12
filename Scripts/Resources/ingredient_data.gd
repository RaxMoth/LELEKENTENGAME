## One fictional, stylized ingredient for the lab. There is no real-world
## chemistry in the game: ingredients are made-up plants and powders.
##
## Dependencies: PlaceholderMesh3D (shape enum)
class_name IngredientData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Ingredient"
## Cash per piece taken from the crate (refunded if it goes back unused).
@export var cost: int = 5
## Tint of the piece (a Palette color).
@export var color: Color = Color.WHITE
@export var shape_kind: PlaceholderMesh3D.ShapeKind = PlaceholderMesh3D.ShapeKind.SPHERE
## Must go through the grinder before it can be cooked.
@export var needs_processing: bool = true
## Name once ground ("Glowcap" -> "Glowcap powder").
@export var processed_name: String = ""


func get_name_for(is_processed: bool) -> String:
	return processed_name if is_processed and not processed_name.is_empty() else display_name

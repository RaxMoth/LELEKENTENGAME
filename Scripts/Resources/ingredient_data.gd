## One fictional, stylized ingredient for the lab. There is no real-world
## chemistry in the game: ingredients are made-up plants and powders.
##
## Dependencies: none
class_name IngredientData
extends Resource

## Mushroom (cap on a stem), root, a bundle of leaves, or crystal chunks.
enum PieceStyle { MUSHROOM, ROOT, LEAF, CRYSTAL }
## Kept in a burlap sack or an open wooden crate.
enum Storage { SACK, CRATE }

@export var id: StringName = &""
@export var display_name: String = "Ingredient"
## Cash per piece taken from the crate (refunded if it goes back unused).
@export var cost: int = 5
## Tint of the piece (a Palette color).
@export var color: Color = Color.WHITE
## What one piece looks like (IngredientLook builds it in [member color]).
@export var piece_style: PieceStyle = PieceStyle.MUSHROOM
## What the lab keeps it in (a burlap sack or an open wooden crate).
@export var storage: Storage = Storage.CRATE
## Must go through the grinder before it can be cooked.
@export var needs_processing: bool = true
## Name once ground ("Glowcap" -> "Glowcap powder").
@export var processed_name: String = ""


func get_name_for(is_processed: bool) -> String:
	return processed_name if is_processed and not processed_name.is_empty() else display_name

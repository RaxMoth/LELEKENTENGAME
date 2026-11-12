## Definition of a currency (soft currency, premium currency, tickets...).
##
## Dependencies: none
class_name CurrencyData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
## Text glyph shown when no icon texture is assigned.
@export var fallback_symbol: String = "●"
@export var color: Color = Color.GOLD
@export var starting_amount: int = 0

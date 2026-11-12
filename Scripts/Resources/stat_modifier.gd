## Modifies one entity stat. FLAT adds to the base, PERCENT adds a percentage
## (0.25 = +25%) applied after all flat modifiers.
##
## Dependencies: Types autoload
class_name StatModifier
extends Resource

@export var stat_id: StringName = &""
@export var kind: Types.StatModifierKind = Types.StatModifierKind.FLAT
@export var value: float = 0.0


static func create(target_stat_id: StringName, modifier_kind: Types.StatModifierKind, modifier_value: float) -> StatModifier:
	var modifier: StatModifier = StatModifier.new()
	modifier.stat_id = target_stat_id
	modifier.kind = modifier_kind
	modifier.value = modifier_value
	return modifier

## Named numeric stats with stackable modifiers (roguelite perks, gear, shop
## upgrades). final = (base + sum(flat)) * (1 + sum(percent)).
##
##   stats.add_modifier(StatModifier.create(Types.ENTITY_STAT_DAMAGE, Types.StatModifierKind.PERCENT, 0.2))
##   var damage: float = stats.get_stat(Types.ENTITY_STAT_DAMAGE)
##
## Dependencies: StatModifier, Types autoload
class_name StatsComponent
extends Node

signal stat_changed(stat_id: StringName, new_value: float)

@export var base_stats: Dictionary[StringName, float] = {}

var _modifiers: Array[StatModifier] = []


func get_stat(stat_id: StringName, default_value: float = 0.0) -> float:
	var flat_total: float = base_stats.get(stat_id, default_value)
	var percent_total: float = 0.0
	for modifier: StatModifier in _modifiers:
		if modifier.stat_id != stat_id:
			continue
		if modifier.kind == Types.StatModifierKind.FLAT:
			flat_total += modifier.value
		else:
			percent_total += modifier.value
	return flat_total * (1.0 + percent_total)


func set_base_stat(stat_id: StringName, value: float) -> void:
	base_stats[stat_id] = value
	stat_changed.emit(stat_id, get_stat(stat_id))


func add_modifier(modifier: StatModifier) -> void:
	_modifiers.append(modifier)
	stat_changed.emit(modifier.stat_id, get_stat(modifier.stat_id))


func add_modifiers(modifiers: Array[StatModifier]) -> void:
	for modifier: StatModifier in modifiers:
		add_modifier(modifier)


func remove_modifier(modifier: StatModifier) -> void:
	_modifiers.erase(modifier)
	stat_changed.emit(modifier.stat_id, get_stat(modifier.stat_id))


func clear_modifiers() -> void:
	var affected_stats: Array[StringName] = []
	for modifier: StatModifier in _modifiers:
		if not affected_stats.has(modifier.stat_id):
			affected_stats.append(modifier.stat_id)
	_modifiers.clear()
	for stat_id: StringName in affected_stats:
		stat_changed.emit(stat_id, get_stat(stat_id))

## Base class for one slice of persistent player data (wallet, levels...).
## Profile creates the modules and registers them with SaveManager.
##
## Subclasses override get_save_key(), to_dict(), from_dict() and reset().
## Call mark_dirty() after every change so the save gets scheduled.
##
## Dependencies: SaveManager autoload
class_name ProfileModule
extends RefCounted

var config: GameConfig


func _init(game_config: GameConfig) -> void:
	config = game_config
	reset()


## @virtual Unique key of this module inside the savegame.
func get_save_key() -> StringName:
	return &""


## @virtual Serializes the module into JSON-compatible data.
func to_dict() -> Dictionary:
	return {}


## @virtual Restores the module from data produced by to_dict().
func from_dict(_data: Dictionary) -> void:
	pass


## @virtual Restores defaults (new player / reset progress).
func reset() -> void:
	pass


func mark_dirty() -> void:
	SaveManager.request_save()


## JSON turns every number into float and every key into String — these
## helpers convert stored dictionaries back into typed ones.
static func to_int_dictionary(raw_data: Variant) -> Dictionary[StringName, int]:
	var typed_dictionary: Dictionary[StringName, int] = {}
	if raw_data is Dictionary:
		for raw_key: Variant in raw_data:
			typed_dictionary[StringName(str(raw_key))] = int(raw_data[raw_key])
	return typed_dictionary


static func to_float_dictionary(raw_data: Variant) -> Dictionary[StringName, float]:
	var typed_dictionary: Dictionary[StringName, float] = {}
	if raw_data is Dictionary:
		for raw_key: Variant in raw_data:
			typed_dictionary[StringName(str(raw_key))] = float(raw_data[raw_key])
	return typed_dictionary

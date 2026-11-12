## Currency balances. Every change is broadcast via Events.currency_changed.
##
## Dependencies: Events, Types autoloads
class_name Wallet
extends ProfileModule

var _balances: Dictionary[StringName, int] = {}


func get_save_key() -> StringName:
	return &"wallet"


func to_dict() -> Dictionary:
	return _balances


func from_dict(data: Dictionary) -> void:
	reset()
	var stored_balances: Dictionary[StringName, int] = to_int_dictionary(data)
	for currency_id: StringName in stored_balances:
		_balances[currency_id] = stored_balances[currency_id]


func reset() -> void:
	_balances = {}
	for currency: CurrencyData in config.currencies:
		_balances[currency.id] = currency.starting_amount


func get_amount(currency_id: StringName) -> int:
	return _balances.get(currency_id, 0)


func can_afford(currency_id: StringName, amount: int) -> bool:
	return get_amount(currency_id) >= amount


func add(currency_id: StringName, amount: int) -> void:
	if amount == 0:
		return
	_balances[currency_id] = maxi(0, get_amount(currency_id) + amount)
	if currency_id == Types.CURRENCY_COINS and amount > 0:
		Profile.stats.increment(Types.STAT_COINS_EARNED, amount)
	Events.currency_changed.emit(currency_id, _balances[currency_id], amount)
	mark_dirty()


## Returns false (and changes nothing) when the player can't afford it.
func spend(currency_id: StringName, amount: int) -> bool:
	if amount < 0 or not can_afford(currency_id, amount):
		return false
	add(currency_id, -amount)
	return true

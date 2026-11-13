## The rules of the house's cycle: which day of the cycle it is, when the
## police raid comes and what each raid brings. Every raid is a little harder
## than the one before (more waves, bigger hordes of cops, SWAT, battering
## rams, squad cars, armored vehicles and helicopters from set raids,
## tougher officers), and police heat at raid time adds cops to
## the last wave.
##
##   RaidPlanner.is_raid_day(day_number, data)            # day 3, 6, 9... with 3 days per cycle
##   var waves: Array[RaidWave] = RaidPlanner.build_raid(data, raid_number, heat_ratio)
##
## Pure functions (unit-tested in Tests/Unit/raid_cycle_test.gd).
##
## Dependencies: RaidData, RaidWave
class_name RaidPlanner
extends RefCounted


## 1-based day inside its cycle (1 .. days_per_cycle) for the 1-based [param day_number].
static func get_day_in_cycle(day_number: int, data: RaidData) -> int:
	return posmod(maxi(1, day_number) - 1, _get_cycle_length(data)) + 1


## 1-based number of the cycle [param day_number] belongs to; also the number
## of the raid that ends it.
static func get_raid_number(day_number: int, data: RaidData) -> int:
	return (maxi(1, day_number) - 1) / _get_cycle_length(data) + 1


## True on the last day of a cycle: its night brings the raid.
static func is_raid_day(day_number: int, data: RaidData) -> bool:
	return get_day_in_cycle(day_number, data) == _get_cycle_length(data)


## Days left before the raid night (0 = the raid comes tonight).
static func get_days_until_raid(day_number: int, data: RaidData) -> int:
	return _get_cycle_length(data) - get_day_in_cycle(day_number, data)


static func get_wave_count(raid_number: int, data: RaidData) -> int:
	var waves: int = data.first_raid_waves + data.extra_waves_per_raid * (maxi(1, raid_number) - 1)
	return clampi(waves, 1, maxi(1, data.max_waves))


## Every wave of raid [param raid_number] (1-based). [param heat_ratio] (0..1)
## is the police heat when the raid starts.
static func build_raid(data: RaidData, raid_number: int, heat_ratio: float = 0.0) -> Array[RaidWave]:
	var waves: Array[RaidWave] = []
	var raid: int = maxi(1, raid_number)
	var later_raids: int = raid - 1
	var wave_count: int = get_wave_count(raid, data)
	var raid_health: float = 1.0 + data.health_growth_per_raid * later_raids
	for wave_index: int in wave_count:
		var is_last_wave: bool = wave_index == wave_count - 1
		var cops: int = data.first_wave_cops + data.cops_per_later_wave * wave_index + data.cops_per_later_raid * later_raids
		if is_last_wave:
			cops += roundi(clampf(heat_ratio, 0.0, 1.0) * data.max_heat_extra_cops)
		var swat: int = 0
		# SWAT join from the raid they unlock in, from that raid's second wave on
		# (the first wave stays a warm-up), and every wave of later raids.
		if raid >= data.swat_from_raid and (wave_index > 0 or raid > data.swat_from_raid):
			swat = data.swat_per_wave + data.swat_per_later_raid * (raid - data.swat_from_raid)
		var health: float = raid_health * (data.last_wave_health_multiplier if is_last_wave else 1.0)
		var rams: int = 0
		if is_last_wave and raid >= data.ram_from_raid:
			rams = 1 + (raid - data.ram_from_raid) / maxi(1, data.raids_per_extra_ram)
		# A horde, but one a standalone headset can draw: SWAT keep their places,
		# cops fill up the rest.
		var on_foot_cap: int = maxi(1, data.max_officers_per_wave)
		swat = mini(swat, on_foot_cap)
		cops = mini(cops, on_foot_cap - swat)
		var wave: RaidWave = RaidWave.new(wave_index, cops, swat, health, rams)
		wave.car_count = _get_cars(data, raid, wave_index, is_last_wave)
		if is_last_wave:
			wave.tank_count = _get_from_raid(raid, data.tanks_from_raid, data.raids_per_extra_tank)
			wave.helicopter_count = _get_from_raid(raid, data.helicopters_from_raid, data.raids_per_extra_helicopter)
		waves.append(wave)
	return waves


## Squad cars: in the last wave of the raid they first come in, in every
## wave of later raids (half as many outside the last wave, at least one).
static func _get_cars(data: RaidData, raid: int, wave_index: int, is_last_wave: bool) -> int:
	if raid < data.cars_from_raid or data.cars_in_first_car_raid <= 0:
		return 0
	var cars: int = data.cars_in_first_car_raid + (raid - data.cars_from_raid)
	if is_last_wave:
		return cars
	if raid == data.cars_from_raid:
		return 0
	return maxi(1, cars / 2) if wave_index > 0 else 0


## One from [param first_raid] on, one more every [param raids_per_extra] raids.
static func _get_from_raid(raid: int, first_raid: int, raids_per_extra: int) -> int:
	if raid < first_raid:
		return 0
	return 1 + (raid - first_raid) / maxi(1, raids_per_extra)


static func _get_cycle_length(data: RaidData) -> int:
	return maxi(1, data.days_per_cycle)

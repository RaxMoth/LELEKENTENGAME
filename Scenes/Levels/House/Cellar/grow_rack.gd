## A grow rack in the cellar: two shelves with two shroom plants each and
## one label for all of them ("2 of 4 ripe"). The plants grow on their own
## like the lab's; grow lights (an UpgradeLook over each shelf) speed them
## up, the auto picker or the player's hand harvests them. Racks come one
## per level of the "Grow Racks" upgrade.
##
##   rack.setup(operation, shroom_recipe)
##   rack.set_active(true)
##   rack.set_growth(1.5, 1)   # grow lights, Green Thumb bonus
##
## Dependencies: ShroomPlant, Operation, RecipeData, Palette
class_name GrowRack
extends Node3D

@onready var _plants: Node3D = %Plants
@onready var _status_label: Label3D = %StatusLabel


## Called by the Cellar at setup: where the harvest goes and what grows.
func setup(house_operation: Operation, crop: RecipeData) -> void:
	for plant: ShroomPlant in get_plants():
		plant.setup(house_operation, crop)


## Bought (or not yet): a rack not bought is hidden and grows nothing.
func set_active(is_active: bool) -> void:
	visible = is_active
	for plant: ShroomPlant in get_plants():
		plant.set_active(is_active)


func is_active() -> bool:
	return visible


## How fast its plants grow (grow lights) and what a harvest by hand adds (Green Thumb).
func set_growth(growth_multiplier: float, hand_bonus: int) -> void:
	for plant: ShroomPlant in get_plants():
		plant.growth_multiplier = growth_multiplier
		plant.hand_harvest_bonus = hand_bonus


func get_plants() -> Array[ShroomPlant]:
	var plants: Array[ShroomPlant] = []
	for child: Node in _plants.get_children():
		var plant: ShroomPlant = child as ShroomPlant
		if plant != null:
			plants.append(plant)
	return plants


func get_ripe_count() -> int:
	var ripe: int = 0
	for plant: ShroomPlant in get_plants():
		if plant.is_ripe():
			ripe += 1
	return ripe


## Updates the label (the Cellar calls this with its other displays).
func refresh_label() -> void:
	var ripe: int = get_ripe_count()
	_status_label.text = tr("%d of %d ripe") % [ripe, get_plants().size()]
	_status_label.modulate = Palette.GOLD if ripe > 0 else Palette.TEXT_MUTED

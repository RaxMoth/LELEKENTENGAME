## Tappable tower slot. Emits tapped; the level decides whether to build or upgrade.
##
## Dependencies: TapArea
class_name TDBuildSpot
extends Node2D

signal tapped(spot: TDBuildSpot)

var tower: TDTower = null

@onready var _tap_area: TapArea = %TapArea
@onready var _label: Label = %Label


func _ready() -> void:
	_tap_area.tapped.connect(func(_area: TapArea) -> void: tapped.emit(self))


func set_label(text: String) -> void:
	_label.text = text

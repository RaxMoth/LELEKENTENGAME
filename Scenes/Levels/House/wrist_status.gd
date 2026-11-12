## A small status panel on the off-hand wrist (lower left of the view in the
## flat simulator): time of day, cash, reputation, stash, heat, door and the
## queue at the window — everything the player splits attention between,
## one glance away.
##
## Dependencies: Palette
class_name WristStatus
extends Node3D

@onready var _time_label: Label3D = %TimeLabel
@onready var _details_label: Label3D = %DetailsLabel
@onready var _backdrop: MeshInstance3D = %Backdrop


func _ready() -> void:
	_backdrop.material_override = PlaceholderMesh3D.get_shared_material(Color(Palette.BACKGROUND, 0.85), 0.0, true)


## Moves the panel onto [param anchor] (a wrist or the flat camera).
func attach_to(anchor: Node3D) -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	anchor.add_child(self)
	transform = Transform3D.IDENTITY


func show_status(time_text: String, is_night: bool, cash: int, reputation: int, stash_units: int, stash_capacity: int, heat: float, door_ratio: float, queue_size: int) -> void:
	_time_label.text = "%s  %s" % [time_text, tr("Night") if is_night else tr("Day")]
	_time_label.modulate = Palette.MOONLIGHT if is_night else Palette.GOLD
	_details_label.text = "%s $%s   %s %d\n%s %d/%d   %s %d\n%s %d%%   %s %d" % [
		tr("Cash"), NumberFormat.compact(cash), tr("Rep"), reputation,
		tr("Stash"), stash_units, stash_capacity, tr("Heat"), roundi(heat),
		tr("Door"), roundi(door_ratio * 100.0), tr("Queue"), queue_size,
	]
	_details_label.modulate = Palette.DANGER if door_ratio < 0.3 else Palette.TEXT

## A small status panel on the off-hand wrist (lower left of the view in the
## flat simulator): time of day, cash, reputation, stash and heat, plus one
## line from each front (door health, the queue at the window) — everything
## the player splits attention between, one glance away.
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


## [param front_lines] are the fronts' own short status lines ("Door 80%", "Queue 2/3").
func show_status(time_text: String, is_night: bool, cash: int, reputation: int, stash_units: int, stash_capacity: int, heat: float, front_lines: PackedStringArray) -> void:
	_time_label.text = "%s  %s" % [time_text, tr("Night") if is_night else tr("Day")]
	_time_label.modulate = Palette.MOONLIGHT if is_night else Palette.GOLD
	_details_label.text = "%s $%s   %s %d\n%s %d/%d   %s %d\n%s" % [
		tr("Cash"), NumberFormat.compact(cash), tr("Rep"), reputation,
		tr("Stash"), stash_units, stash_capacity, tr("Heat"), roundi(heat),
		_pair_lines(front_lines),
	]


## The first line (the 3-day cycle: raid countdown or wave) gets its own row;
## the fronts' lines go two per row to keep the panel narrow on a wrist.
func _pair_lines(lines: PackedStringArray) -> String:
	if lines.is_empty():
		return ""
	var rows: PackedStringArray = PackedStringArray([lines[0]])
	for line_index: int in range(1, lines.size(), 2):
		rows.append("   ".join(lines.slice(line_index, line_index + 2)))
	return "\n".join(rows)

## A small status panel on the off-hand wrist (lower left of the view in the
## flat simulator): time of day and the player's health, cash, reputation,
## stash and heat, plus one line from each front (door health, the queue at
## the window) — everything the player splits attention between, one glance
## away.
##
## Dependencies: Palette
class_name WristStatus
extends Node3D

## Health shares below which the wrist shows it amber (hurt) and red (low).
const HURT_HEALTH_RATIO: float = 0.5
const LOW_HEALTH_RATIO: float = 0.25

@onready var _time_label: Label3D = %TimeLabel
@onready var _details_label: Label3D = %DetailsLabel
@onready var _health_label: Label3D = %HealthLabel
@onready var _backdrop: MeshInstance3D = %Backdrop

## Whole health points shown now (the label only changes when they do).
var _shown_health: int = -1


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


## The player's health (PlayerVitals): plain while fine, amber when hurt,
## red when low.
func show_health(current: float, maximum: float) -> void:
	var whole_points: int = ceili(current)
	if whole_points == _shown_health:
		return
	_shown_health = whole_points
	_health_label.text = "%s %d" % [tr("Health"), whole_points]
	var ratio: float = current / maxf(1.0, maximum)
	_health_label.modulate = Palette.TEXT if ratio > HURT_HEALTH_RATIO else (Palette.WARNING if ratio > LOW_HEALTH_RATIO else Palette.DANGER)


## The first line (the 3-day cycle: raid countdown or wave) gets its own row;
## the fronts' lines go two per row to keep the panel narrow on a wrist.
func _pair_lines(lines: PackedStringArray) -> String:
	if lines.is_empty():
		return ""
	var rows: PackedStringArray = PackedStringArray([lines[0]])
	for line_index: int in range(1, lines.size(), 2):
		rows.append("   ".join(lines.slice(line_index, line_index + 2)))
	return "\n".join(rows)

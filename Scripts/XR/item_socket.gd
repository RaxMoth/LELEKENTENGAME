## A place an item can be put: a grinder's hopper, a cooker's pot slot, a
## press, a station's output tray. Its owner decides what it accepts and
## reacts to items going in and out.
##
##   socket.accept_rule = func(item: Grabbable) -> bool: return item is IngredientItem
##   socket.item_inserted.connect(_on_hopper_filled)
##
## Dependencies: Grabbable, PlaceholderMesh3D, Palette, Types autoload
class_name ItemSocket
extends Node3D

signal item_inserted(item: Grabbable)
signal item_removed(item: Grabbable)

const MARKER_OPACITY: float = 0.35
const MARKER_HEIGHT: float = 0.004

## How close a dropped item must be to snap in, in meters.
@export var snap_radius: float = 0.3
## Items may be taken back out by hand.
@export var allows_removal: bool = true
## Shows a ring when a held item could go here.
@export var show_marker: bool = true
@export var marker_diameter: float = 0.22

## Returns true for items this socket takes (null = anything).
var accept_rule: Callable = Callable()
var item: Grabbable = null

var _marker: MeshInstance3D = null


func _ready() -> void:
	add_to_group(Types.GROUP_ITEM_SOCKET)
	if show_marker:
		_marker = MeshInstance3D.new()
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = marker_diameter * 0.5
		disc.bottom_radius = marker_diameter * 0.5
		disc.height = MARKER_HEIGHT
		disc.radial_segments = 24
		_marker.mesh = disc
		_marker.material_override = PlaceholderMesh3D.get_shared_material(Color(Palette.PRIMARY, MARKER_OPACITY), 0.0, true)
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marker.visible = false
		add_child(_marker)


func is_empty() -> bool:
	return item == null


func can_accept(candidate: Grabbable) -> bool:
	return item == null and candidate != null and is_visible_in_tree() and (not accept_rule.is_valid() or bool(accept_rule.call(candidate)))


## Puts an item in (it stops following any hand and rests here). Returns
## false and changes nothing when the socket is already taken.
func insert(candidate: Grabbable) -> bool:
	if item != null and item != candidate:
		push_warning("ItemSocket %s: already holds an item." % name)
		return false
	if candidate.socket != null and candidate.socket != self:
		candidate.socket.remove_item()
	candidate.holder = null
	candidate.socket = self
	item = candidate
	candidate.global_transform = global_transform
	set_highlighted(false)
	item_inserted.emit(candidate)
	return true


## Takes the item out (it is not freed). Returns it, or null when empty.
func remove_item() -> Grabbable:
	var removed: Grabbable = item
	if removed == null:
		return null
	item = null
	removed.socket = null
	item_removed.emit(removed)
	return removed


## Shows the drop marker while a held item that fits is near.
func set_highlighted(is_highlighted: bool) -> void:
	if _marker != null:
		_marker.visible = is_highlighted and item == null

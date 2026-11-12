## A place an item can be put: a grinder's hopper, a cooker's pot slot, a
## press, a station's output tray. Its owner decides what it accepts and
## reacts to items going in and out.
##
##   socket.accept_rule = func(item: Grabbable) -> bool: return item is IngredientItem
##   socket.refusal_reason = func(item: Grabbable) -> String: return tr("Grind it first")
##   socket.item_inserted.connect(_on_hopper_filled)
##
## A socket with a refusal_reason tells the player why a held item doesn't
## fit: its ring turns red while the item points at it, and letting go there
## emits item_refused (the owner shows the reason). With shows_empty_marker
## the ring stays faintly visible while empty, so the player sees the slot.
##
## Dependencies: Grabbable, PlaceholderMesh3D, Palette, Types autoload
class_name ItemSocket
extends Node3D

signal item_inserted(item: Grabbable)
signal item_removed(item: Grabbable)
## The player let go of [param item] here but it doesn't fit, for [param reason].
signal item_refused(item: Grabbable, reason: String)

enum Highlight { NONE, FITS, REFUSES }

const MARKER_OPACITY: float = 0.35
const EMPTY_MARKER_OPACITY: float = 0.55
const MARKER_HEIGHT: float = 0.004

## How close a dropped item must be to snap in, in meters.
@export var snap_radius: float = 0.3
## Items may be taken back out by hand.
@export var allows_removal: bool = true
## Shows a ring when a held item could go here.
@export var show_marker: bool = true
@export var marker_diameter: float = 0.22
## Keep a faint ring on the slot while it is empty (station inputs).
@export var shows_empty_marker: bool = false:
	set(value):
		shows_empty_marker = value
		_update_marker()

## Returns true for items this socket takes (null = anything).
var accept_rule: Callable = Callable()
## Returns why a refused item doesn't fit (null = refuse silently).
var refusal_reason: Callable = Callable()
var item: Grabbable = null

var _highlight: Highlight = Highlight.NONE

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
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marker)
		_update_marker()


func is_empty() -> bool:
	return item == null


func can_accept(candidate: Grabbable) -> bool:
	return item == null and candidate != null and is_visible_in_tree() and (not accept_rule.is_valid() or bool(accept_rule.call(candidate)))


## True when [param candidate] doesn't fit this free slot and the owner can
## say why (so the player gets told instead of silently refused).
func explains_refusal_of(candidate: Grabbable) -> bool:
	return refusal_reason.is_valid() and item == null and candidate != null and is_visible_in_tree() and not can_accept(candidate)


## The player let go of [param candidate] here although it doesn't fit.
func refuse(candidate: Grabbable) -> void:
	item_refused.emit(candidate, str(refusal_reason.call(candidate)) if refusal_reason.is_valid() else "")


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
	set_highlight(Highlight.NONE)
	item_inserted.emit(candidate)
	return true


## Takes the item out (it is not freed). Returns it, or null when empty.
func remove_item() -> Grabbable:
	var removed: Grabbable = item
	if removed == null:
		return null
	item = null
	removed.socket = null
	_update_marker()
	item_removed.emit(removed)
	return removed


## Ring state while the player holds something: it fits (blue), it doesn't
## (red), or nothing to show.
func set_highlight(state: Highlight) -> void:
	_highlight = state
	_update_marker()


func _update_marker() -> void:
	if _marker == null:
		return
	var color: Color = Color(Palette.TEXT, EMPTY_MARKER_OPACITY)
	match _highlight:
		Highlight.FITS:
			color = Color(Palette.PRIMARY, MARKER_OPACITY + 0.25)
		Highlight.REFUSES:
			color = Color(Palette.DANGER, MARKER_OPACITY + 0.25)
	_marker.visible = item == null and (_highlight != Highlight.NONE or shows_empty_marker)
	_marker.material_override = PlaceholderMesh3D.get_shared_material(color, 0.0, true)

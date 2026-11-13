## The rules of a pair of hands: what a trigger or grip press does with the
## items, slots (ItemSocket) and 3D buttons at a hand or under its beam. The
## local XRPlayerRig uses one; in co-op the host runs one per remote player
## (RemotePlayer), fed with that player's hand poses and button presses, so
## both players interact with the world by exactly the same rules.
##
## Dominant trigger: a WorldScreen, then (holding something) putting it into
## the slot next to it or under the beam, then a PointerButton, then picking
## up the item (or a new one from a crate) at the hand or under the beam,
## then primary_action_pressed. A usable item in a hand (the extinguisher)
## takes that hand's trigger instead (Grabbable.use). Off-hand trigger: a screen, a button or
## secondary_action_pressed (the gun) — never a pickup. Grip: hold to carry
## and let go to put down; a quick click keeps holding until the next click.
## Fixed things (door handles) only move while the button is held.
##
##   hands.setup({Types.Hand.LEFT: left_anchor, Types.Hand.RIGHT: right_anchor},
##       {Types.Hand.LEFT: left_pointer, Types.Hand.RIGHT: right_pointer})
##   hands.handle_button(Types.Hand.RIGHT, Types.XR_ACTION_TRIGGER_CLICK, true)
##
## Dependencies: Grabbable, ItemSocket, XRPointer, PointerButton,
##               InteractionQuery, Pools, Types autoloads
class_name HandInteractor
extends Node

## Dominant trigger that hit nothing interactive.
signal primary_action_pressed(pointer: XRPointer)
## Off-hand trigger that hit no screen or button.
signal secondary_action_pressed(pointer: XRPointer)
## The dominant trigger was let go (held actions: a turret's trigger).
signal primary_action_released(pointer: XRPointer)
## The off-hand trigger was let go (automatic guns stop firing).
signal secondary_action_released(pointer: XRPointer)
signal item_grabbed(item: Grabbable)
signal item_placed(item: Grabbable, socket: ItemSocket)
## A hand should rumble (the owner turns it into a controller pulse).
signal pulse_requested(hand: Types.Hand, strength: Types.HapticStrength)

## A hand grabs things this close to its hold point (meters).
const HAND_GRAB_REACH: float = 0.12
## Pointer grabs and button presses reach this far.
const POINTER_REACH: float = 4.5
## A grip let go sooner than this after picking something up was a click:
## the hand keeps the item until the next grip click or trigger.
const GRIP_CLICK_SECONDS: float = 0.35
## _grip_grabbed_at_msec value of a hand whose item the grip didn't pick up.
const NOT_GRIP_GRABBED: int = -1

## Hand whose trigger uses things; the other trigger is the gun.
var dominant_hand: Types.Hand = Types.Hand.RIGHT
## Mirror mode (co-op client): the host decides what the hands hold and
## mirror_held_item() reports it; nothing is grabbed or put down here.
var is_mirror: bool = false

var _hold_anchors: Dictionary[Types.Hand, Node3D] = {}
var _pointers: Dictionary[Types.Hand, XRPointer] = {}
var _held_items: Dictionary[Types.Hand, Grabbable] = {Types.Hand.LEFT: null, Types.Hand.RIGHT: null}
## When each hand's grip picked up what it holds (Time ticks, ms), or
## NOT_GRIP_GRABBED (the trigger took it: a grip release leaves it alone).
var _grip_grabbed_at_msec: Dictionary[Types.Hand, int] = {Types.Hand.LEFT: NOT_GRIP_GRABBED, Types.Hand.RIGHT: NOT_GRIP_GRABBED}
## The grip press already put the item down; its release must not act again.
var _ignores_grip_release: Dictionary[Types.Hand, bool] = {Types.Hand.LEFT: false, Types.Hand.RIGHT: false}
## Hands holding something these rules don't manage (a weapon drawn from a holster): they grab nothing.
var _busy_hands: Dictionary[Types.Hand, bool] = {Types.Hand.LEFT: false, Types.Hand.RIGHT: false}


## Wires the hands: where each holds things and the beam it points with.
func setup(hold_anchors: Dictionary[Types.Hand, Node3D], pointers: Dictionary[Types.Hand, XRPointer]) -> void:
	_hold_anchors = hold_anchors
	_pointers = pointers


## A trigger or grip changed on [param hand] (other buttons are the owner's).
func handle_button(hand: Types.Hand, action_name: StringName, is_pressed: bool) -> void:
	match action_name:
		Types.XR_ACTION_TRIGGER_CLICK:
			_on_trigger(hand, is_pressed)
		Types.XR_ACTION_GRIP_CLICK:
			_on_grip(hand, is_pressed)


## Marks [param hand] as holding something these rules don't manage (a
## weapon drawn from a holster), so it grabs nothing meanwhile.
func set_hand_busy(hand: Types.Hand, is_busy: bool) -> void:
	_busy_hands[hand] = is_busy


## True while [param hand] holds something these rules don't manage (a drawn weapon).
func is_hand_busy(hand: Types.Hand) -> bool:
	return _busy_hands[hand]


func get_held_item(hand: Types.Hand) -> Grabbable:
	return _held_items[hand]


func get_held_items() -> Array[Grabbable]:
	var held: Array[Grabbable] = []
	for hand: Types.Hand in _held_items:
		if _held_items[hand] != null:
			held.append(_held_items[hand])
	return held


func get_hold_anchor(hand: Types.Hand) -> Node3D:
	return _hold_anchors[hand]


func get_pointer(hand: Types.Hand) -> XRPointer:
	return _pointers[hand]


## Lets go of everything (a co-op player left or the level ends).
func release_all() -> void:
	for hand: Types.Hand in _held_items:
		if _held_items[hand] != null:
			_put_down(hand)


## Mirror mode: the host says [param hand] holds [param item] (or nothing).
func mirror_held_item(hand: Types.Hand, item: Grabbable) -> void:
	_held_items[hand] = item


## Button releases are lost while the headset's system menu has focus.
func forget_grip_state() -> void:
	for hand: Types.Hand in _ignores_grip_release:
		_ignores_grip_release[hand] = false


## Adds the slot each held item would go into (FITS), or the one it is
## aimed at but doesn't fit (REFUSES), to [param wanted].
func collect_highlights(wanted: Dictionary[ItemSocket, ItemSocket.Highlight]) -> void:
	_forget_lost_items()
	for hand: Types.Hand in _held_items:
		var item: Grabbable = _held_items[hand]
		if item == null:
			continue
		var socket: ItemSocket = find_drop_socket(hand, item)
		if socket != null:
			wanted[socket] = ItemSocket.Highlight.FITS
			continue
		var refusing_socket: ItemSocket = find_refusing_socket(hand, item)
		if refusing_socket != null:
			wanted[refusing_socket] = ItemSocket.Highlight.REFUSES


## Socket a held item would go into: the one next to it, or else the one
## under the hand's beam (so the player can point instead of reaching).
## Fixed things never go into sockets.
func find_drop_socket(hand: Types.Hand, item: Grabbable) -> ItemSocket:
	if item.is_fixed:
		return null
	var socket: ItemSocket = InteractionQuery.find_socket_near(get_tree(), item, item.global_position)
	if socket == null:
		var pointer: XRPointer = _pointers[hand]
		socket = InteractionQuery.find_socket_on_ray(get_tree(), item, pointer.ray_origin, pointer.ray_direction, POINTER_REACH)
	return socket


## A slot the held item is aimed at but doesn't fit (and that can say why).
func find_refusing_socket(hand: Types.Hand, item: Grabbable) -> ItemSocket:
	if item.is_fixed:
		return null
	var socket: ItemSocket = InteractionQuery.find_refusing_socket_near(get_tree(), item, item.global_position)
	if socket == null:
		var pointer: XRPointer = _pointers[hand]
		socket = InteractionQuery.find_refusing_socket_on_ray(get_tree(), item, pointer.ray_origin, pointer.ray_direction, POINTER_REACH)
	return socket


## Presses the 3D button under [param pointer]'s beam. True when one was hit.
func press_button_on_ray(pointer: XRPointer, hand: Types.Hand) -> bool:
	var button: PointerButton = InteractionQuery.find_button_on_ray(get_tree(), pointer.ray_origin, pointer.ray_direction, POINTER_REACH)
	if button == null:
		return false
	if button.press():
		pulse_requested.emit(hand, Types.HapticStrength.LIGHT)
	return true

# ============================================
# INTERNALS
# ============================================

func _on_trigger(hand: Types.Hand, is_pressed: bool) -> void:
	var pointer: XRPointer = _pointers[hand]
	var usable_item: Grabbable = _held_items[hand] if _held_items[hand] != null and _held_items[hand].is_usable() else null
	if not is_pressed:
		pointer.release()
		if usable_item != null:
			usable_item.use(false, pointer)
		if hand == dominant_hand:
			primary_action_released.emit(pointer)
		else:
			secondary_action_released.emit(pointer)
		# Something fixed (a door handle) only moves while the trigger is held.
		var held_item: Grabbable = _held_items[hand]
		if hand == dominant_hand and held_item != null and held_item.is_fixed:
			_put_down(hand)
		return
	if pointer.press() or get_tree().paused:
		return
	if usable_item != null:
		usable_item.use(true, pointer)
		return
	if hand != dominant_hand:
		if not press_button_on_ray(pointer, hand):
			secondary_action_pressed.emit(pointer)
		return
	if _held_items[hand] != null:
		_put_down(hand)
		return
	if press_button_on_ray(pointer, hand) or _grab_with_hand(hand):
		return
	primary_action_pressed.emit(pointer)


func _on_grip(hand: Types.Hand, is_pressed: bool) -> void:
	if is_pressed:
		if get_tree().paused:
			return
		if _held_items[hand] != null:
			_put_down(hand)
			_ignores_grip_release[hand] = true
		elif _grab_with_hand(hand):
			_grip_grabbed_at_msec[hand] = Time.get_ticks_msec()
		return
	if _ignores_grip_release[hand]:
		_ignores_grip_release[hand] = false
		return
	var held_item: Grabbable = _held_items[hand]
	if held_item == null or get_tree().paused or _grip_grabbed_at_msec[hand] == NOT_GRIP_GRABBED:
		return
	var held_milliseconds: int = Time.get_ticks_msec() - _grip_grabbed_at_msec[hand]
	if held_item.is_fixed or held_milliseconds >= roundi(GRIP_CLICK_SECONDS * 1000.0):
		_put_down(hand)


## Takes the item at the hand, or else under its beam (a crate hands out a
## new one and charges for it). Returns true when the hand now holds it.
func _grab_with_hand(hand: Types.Hand) -> bool:
	if is_mirror or _held_items[hand] != null or _busy_hands[hand] or get_tree().paused:
		return false
	var anchor: Node3D = _hold_anchors[hand]
	var pointer: XRPointer = _pointers[hand]
	var target: Node3D = InteractionQuery.find_grab_target_near(get_tree(), anchor.global_position, HAND_GRAB_REACH)
	if target == null:
		target = InteractionQuery.find_grab_target_on_ray(get_tree(), pointer.ray_origin, pointer.ray_direction, POINTER_REACH)
	var item: Grabbable = InteractionQuery.take_from(target)
	if item == null:
		return false
	item.attach_to(anchor)
	_held_items[hand] = item
	# The grip stamps its own grabs right after this; a trigger grab stays unstamped.
	_grip_grabbed_at_msec[hand] = NOT_GRIP_GRABBED
	pulse_requested.emit(hand, Types.HapticStrength.LIGHT)
	item_grabbed.emit(item)
	return true


## Lets go of what [param hand] holds: into the socket it would snap to
## (the highlighted one), otherwise wherever a dropped item goes.
func _put_down(hand: Types.Hand) -> void:
	var item: Grabbable = _held_items[hand]
	if item == null or is_mirror:
		return
	_held_items[hand] = null
	var socket: ItemSocket = find_drop_socket(hand, item)
	if socket != null:
		item.detach()
		socket.insert(item)
		item_placed.emit(item, socket)
		pulse_requested.emit(hand, Types.HapticStrength.MEDIUM)
		return
	var refusing_socket: ItemSocket = find_refusing_socket(hand, item)
	if refusing_socket != null:
		refusing_socket.refuse(item)
		pulse_requested.emit(hand, Types.HapticStrength.HEAVY)
	item.drop_nowhere()


## A held item that was pooled or freed elsewhere is no longer in a hand.
## (Mirrored items have no holder here: only their existence counts.)
func _forget_lost_items() -> void:
	for hand: Types.Hand in _held_items:
		var item: Grabbable = _held_items[hand]
		if item == null:
			continue
		if not is_instance_valid(item) or Pools.is_in_pool(item) or (not is_mirror and item.holder == null):
			_held_items[hand] = null

## Something a hand (or the flat simulator's cursor) can pick up, carry and
## put into an ItemSocket: ingredients, batches. While held it follows its
## holder; let go away from a socket it goes back where it belongs. A
## usable item (is_usable: the extinguisher) acts on its holder's trigger
## instead of being put down by it (the grip puts it down).
##
##   class_name IngredientItem extends Grabbable
##   func _on_released_nowhere() -> void: crate.take_back(self)
##
## Dependencies: ItemSocket, Pools, Types autoloads
class_name Grabbable
extends Node3D

signal grabbed(item: Grabbable)
signal released(item: Grabbable)

## Radius of the sphere a hand or pointer ray picks it with.
@export var grab_radius: float = 0.12
## Where it sits relative to the holder (a controller or the flat camera).
@export var hold_offset: Vector3 = Vector3(0.0, 0.0, -0.06)
## Fixed to something in the world (a door handle): it only moves while a
## hand holds the button down, never stays in the hand after a click and
## never goes into a socket.
@export var is_fixed: bool = false

## The node it follows while held (null when not held).
var holder: Node3D = null
## The socket it rests in (null when held or loose).
var socket: ItemSocket = null
## Socket it returns to when dropped nowhere (null = _on_released_nowhere decides).
var home_socket: ItemSocket = null


func _ready() -> void:
	add_to_group(Types.GROUP_GRABBABLE)
	add_to_group(Types.GROUP_NET_ENTITY)


func _process(_delta: float) -> void:
	if holder != null and is_instance_valid(holder):
		global_transform = holder.global_transform * Transform3D(Basis.IDENTITY, hold_offset)
	else:
		set_process(false)


func is_held() -> bool:
	return holder != null


func can_grab() -> bool:
	return holder == null and is_visible_in_tree() and not Pools.is_in_pool(self) and (socket == null or socket.allows_removal)


## Center of the pick sphere.
func get_grab_center() -> Vector3:
	return global_position


## Takes it into a hand: leaves its socket and follows [param new_holder].
func attach_to(new_holder: Node3D) -> void:
	if socket != null:
		socket.remove_item()
	holder = new_holder
	set_process(true)
	grabbed.emit(self)


## Lets go. The caller then puts it into a socket or calls drop_nowhere().
func detach() -> void:
	holder = null
	released.emit(self)


## Let go away from any socket that takes it: back to the home socket when
## that is free, otherwise _on_released_nowhere() decides.
func drop_nowhere() -> void:
	detach()
	if home_socket != null and home_socket.is_empty() and home_socket.is_visible_in_tree():
		home_socket.insert(self)
	else:
		_on_released_nowhere()


## @virtual What it is, in words for the player ("Shrooms ×3 · Okay"),
## shown while it is in a hand (ViewStatus). Empty: not worth naming (a
## door handle).
func get_display_name() -> String:
	return ""


## @virtual True for an item that acts while held when its holder pulls the
## trigger (the extinguisher sprays).
func is_usable() -> bool:
	return false


## @virtual The holder's trigger went down ([param is_pressed]) or up,
## aiming along [param pointer].
func use(_is_pressed: bool, _pointer: XRPointer) -> void:
	pass


## @virtual One use from a click (the flat simulator): a press and a release.
func use_once(pointer: XRPointer) -> void:
	use(true, pointer)
	use(false, pointer)


## @virtual Dropped with no socket to go to. Default: stay where it is.
func _on_released_nowhere() -> void:
	pass


## Pool reuse: forget hands and sockets (and free the socket it sat in).
func _on_pool_despawned() -> void:
	if socket != null and is_instance_valid(socket) and socket.item == self:
		socket.remove_item()
	holder = null
	socket = null
	home_socket = null

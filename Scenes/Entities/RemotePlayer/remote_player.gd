## The other player in a co-op game: their head and hands drawn where that
## player has them, their beams and their name. Poses arrive about 20 times
## a second; the drawn pose glides between them a moment behind
## (SnapshotBuffer), while button presses use the newest one. On the host it also carries the
## player's HandInteractor, so their trigger and grip act in the host's
## world by exactly the same rules as the host's own hands.
##
##   var other: RemotePlayer = REMOTE_PLAYER_SCENE.instantiate() as RemotePlayer
##   other.setup(peer_id, Coop.get_player_name(peer_id), Coop.get_player_index(peer_id), Coop.is_host())
##   avatars_root.add_child(other)
##   other.apply_pose(head, left_hold, left_origin, left_direction, right_hold, ...)
##
## Dependencies: HandInteractor, XRPointer, SnapshotBuffer, PlaceholderMesh3D, Palette, Types autoload
class_name RemotePlayer
extends Node3D

## The torso hangs this far below the head and only turns with it (no tilt).
const NECK_DROP: float = 0.12
## Metadata on a hold anchor: Vector2i(peer id, hand) of whoever holds there.
const META_HOLDER: StringName = &"coop_holder"

## The network peer this player is.
var peer_id: int = 0
## Their hands' rules (host only; null on a client, where the host acts).
var hands: HandInteractor = null

var _player_name: String = ""
var _color: Color = Palette.PRIMARY
var _acts_in_world: bool = false
var _target_head: Transform3D = Transform3D.IDENTITY
var _target_hands: Dictionary[Types.Hand, Transform3D] = {Types.Hand.LEFT: Transform3D.IDENTITY, Types.Hand.RIGHT: Transform3D.IDENTITY}
var _has_pose: bool = false
var _head_buffer: SnapshotBuffer = SnapshotBuffer.new()
var _hand_buffers: Dictionary[Types.Hand, SnapshotBuffer] = {Types.Hand.LEFT: SnapshotBuffer.new(), Types.Hand.RIGHT: SnapshotBuffer.new()}
var _pointers: Dictionary[Types.Hand, XRPointer] = {}

@onready var _head: Node3D = %Head
@onready var _head_mesh: PlaceholderMesh3D = %HeadMesh
@onready var _name_label: Label3D = %NameLabel
@onready var _body: Node3D = %Body
@onready var _collar: PlaceholderMesh3D = %Collar
@onready var _left_hand: Node3D = %LeftHand
@onready var _right_hand: Node3D = %RightHand
@onready var _left_tip: PlaceholderMesh3D = %LeftTip
@onready var _right_tip: PlaceholderMesh3D = %RightTip


## Who this is; call before adding it to the tree. [param acts_in_world]:
## the host runs this player's hands (grab, put in, press buttons).
func setup(player_peer_id: int, player_name: String, player_index: int, acts_in_world: bool) -> void:
	peer_id = player_peer_id
	_player_name = player_name
	_color = Palette.CATEGORY[player_index % Palette.CATEGORY.size()]
	_acts_in_world = acts_in_world


func _ready() -> void:
	visible = false
	_head_mesh.color = _color
	_collar.color = _color
	_left_tip.color = _color
	_right_tip.color = _color
	_name_label.text = _player_name
	for hand: Types.Hand in [Types.Hand.LEFT, Types.Hand.RIGHT]:
		var pointer: XRPointer = XRPointer.new()
		pointer.name = "LeftPointer" if hand == Types.Hand.LEFT else "RightPointer"
		pointer.beam_color = _color
		add_child(pointer)
		# Only the host's stand-in for a guest points at things (its screens and
		# buttons are the real ones); on a guest's side the host's beams would
		# poke at a mirror that doesn't act.
		pointer.is_enabled = _acts_in_world
		_pointers[hand] = pointer
		_get_hand(hand).set_meta(META_HOLDER, Vector2i(peer_id, hand))
	if _acts_in_world:
		hands = HandInteractor.new()
		hands.name = "Hands"
		add_child(hands)
		hands.setup({Types.Hand.LEFT: _left_hand, Types.Hand.RIGHT: _right_hand}, _pointers)


func _process(_delta: float) -> void:
	if not _has_pose:
		return
	var shown_time: float = _now() - SnapshotBuffer.INTERPOLATION_DELAY
	_head.global_transform = _head_buffer.sample(shown_time)
	_place_body()
	for hand: Types.Hand in _hand_buffers:
		_get_hand(hand).global_transform = _hand_buffers[hand].sample(shown_time)

# ============================================
# PUBLIC API
# ============================================

## The player's latest pose: head, and per hand where it holds things and
## where its beam points.
func apply_pose(head: Transform3D, left_hold: Transform3D, left_origin: Vector3, left_direction: Vector3, right_hold: Transform3D, right_origin: Vector3, right_direction: Vector3) -> void:
	_target_head = head
	_target_hands[Types.Hand.LEFT] = left_hold
	_target_hands[Types.Hand.RIGHT] = right_hold
	var now: float = _now()
	_head_buffer.push(now, head)
	_hand_buffers[Types.Hand.LEFT].push(now, left_hold)
	_hand_buffers[Types.Hand.RIGHT].push(now, right_hold)
	_pointers[Types.Hand.LEFT].set_ray(left_origin, left_direction)
	_pointers[Types.Hand.RIGHT].set_ray(right_origin, right_direction)
	if not _has_pose:
		_has_pose = true
		visible = true
		snap_to_pose()


## Jumps the hands to the latest pose (before acting on a button press,
## so the grab happens exactly where the player's hand is).
func snap_to_pose() -> void:
	_head.global_transform = _target_head
	_place_body()
	for hand: Types.Hand in _target_hands:
		_get_hand(hand).global_transform = _target_hands[hand]


## Host: carries out a trigger or grip press this player made.
func press_button(hand: Types.Hand, action_name: StringName, is_pressed: bool) -> void:
	if hands == null:
		return
	snap_to_pose()
	hands.handle_button(hand, action_name, is_pressed)


func get_hold_anchor(hand: Types.Hand) -> Node3D:
	return _get_hand(hand)


func get_head_transform() -> Transform3D:
	return _head.global_transform


## The point on the floor under their head (only x / z mean anything).
func get_feet_position() -> Vector3:
	var head: Vector3 = _target_head.origin
	return Vector3(head.x, global_position.y, head.z)


## Under the head, turned the way the head faces (looking down doesn't bend the body).
func _place_body() -> void:
	var forward: Vector3 = -_head.global_transform.basis.z
	var yaw: float = atan2(-forward.x, -forward.z)
	_body.global_transform = Transform3D(Basis(Vector3.UP, yaw), _head.global_position + Vector3(0.0, -NECK_DROP, 0.0))


func _get_hand(hand: Types.Hand) -> Node3D:
	return _left_hand if hand == Types.Hand.LEFT else _right_hand


## Seconds on this machine's clock (poses are timed by when they arrive).
func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0

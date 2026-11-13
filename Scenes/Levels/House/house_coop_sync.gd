## Co-op inside the House: keeps both players in the same house.
##
## Host (the real world): runs a RemotePlayer for the guest — their head and
## hands drawn where they are, and their trigger / grip presses carried out
## by the same HandInteractor rules as the host's own hands. ~15 times a
## second it sends the guest a snapshot: spawned things (NetEntities: lab
## items, customers, raiders) and station looks (Types.GROUP_NET_NODE);
## 4 times a second the shared state: cash, operation progress (stash,
## reputation), upgrades (which also show the lab's gadgets), heat, time and wrist lines.
## Announcements, floating texts, world sounds and the guest's rumbles are relayed.
##
## Guest (HouseLevel.is_mirror): its rig forwards trigger, grip and clicks
## here instead of acting; walking, turning and menus stay local. It shows
## the host's snapshots and sends its own pose ~20 times a second.
##
## Boards (every WorldScreen with its own content: sales, office, armory,
## build board...) are one object in the shared house: the host sends their
## look (ControlMirror) whenever it changes, and the guest's presses on them
## already reach the host's real boards through the forwarded hand input.
## The guest's boards only redraw while the guest is near and facing them.
##
## Guest shots: their off-hand trigger (right click in the flat simulator)
## reaches the host's defense through HouseContext.guest_fired; every
## tracer, theirs included, is relayed back.
##
## Health: the host keeps a PlayerVitals on each guest's stand-in (raiders
## that got in hunt them too) and sends the guest its numbers — on every hit
## and, while it heals, a few times a second; a guest going down ends the
## shift on the host. What only the guest's copy has (its own cabin rats)
## reports a hurt to the host (report_own_hurt).
##
## Dependencies: HouseLevel, RemotePlayer, NetEntities, HandInteractor, Lab,
##               PlayerVitals,
##               WorldScreen, ControlMirror, FloatingText3D, Coop, Profile,
##               Events, Global, Types autoloads
class_name HouseCoopSync
extends Node

const REMOTE_PLAYER_SCENE: PackedScene = preload("res://Scenes/Entities/RemotePlayer/RemotePlayer.tscn")
const TRACER_SCENE: PackedScene = preload("res://Scenes/Levels/House/Garden/BeamTracer.tscn")
## Spawned scenes the guest sees (kind index = position in this list:
## append only, the order is part of the protocol).
const STREAMED_SCENES: PackedStringArray = [
	"res://Scenes/Levels/House/Lab/IngredientItem.tscn",
	"res://Scenes/Levels/House/Lab/BatchItem.tscn",
	"res://Scenes/Levels/House/Sales/Customer.tscn",
	"res://Scenes/Levels/House/Garden/Raider.tscn",
	"res://Scenes/Levels/House/Garden/Cop.tscn",
	"res://Scenes/Levels/House/Garden/Swat.tscn",
	"res://Scenes/Levels/House/Garden/RamTeam.tscn",
	"res://Scenes/Levels/House/Garden/Vehicles/SquadCar.tscn",
	"res://Scenes/Levels/House/Garden/Vehicles/ArmoredVehicle.tscn",
	"res://Scenes/Levels/House/Garden/Vehicles/PoliceHelicopter.tscn",
]
const POSE_INTERVAL_SECONDS: float = 0.05
const SNAPSHOT_INTERVAL_SECONDS: float = 1.0 / 15.0
const WORLD_INTERVAL_SECONDS: float = 0.25
## The shared state goes out when it changes, and at least this often (the
## channel is unreliable: a lost update must not stick).
const WORLD_HEARTBEAT_SECONDS: float = 2.0
const METHOD_GET_STATE: StringName = &"get_net_state"
const METHOD_APPLY_STATE: StringName = &"apply_net_state"
const WORLD_WALLET: int = 0
const WORLD_OPERATION: int = 1
const WORLD_UPGRADES: int = 2
const WORLD_HEAT: int = 3
const WORLD_TIME: int = 4
const WORLD_WRIST_LINES: int = 5
## A guest's boards farther away than this (or behind them) stop redrawing.
const SCREEN_RENDER_DISTANCE: float = 7.0
## Most a guest's own report may hurt them at once (a rat's bite is 1)...
const MAX_REPORTED_HURT: float = 5.0
## ...and how soon after the last one another report counts (milliseconds).
const MIN_HURT_REPORT_INTERVAL_MSEC: int = 500

## Spawned things streamed to (host) or shown from (guest) the other player.
## Host: sounds sent to the other player so far (tests).
var sounds_relayed: int = 0
var entities: NetEntities = NetEntities.new(STREAMED_SCENES)

var _level: HouseLevel = null
var _players: Dictionary[int, RemotePlayer] = {}
var _seconds_until_pose: float = 0.0
var _seconds_until_snapshot: float = 0.0
var _seconds_until_world: float = 0.0
var _last_upgrades_hash: int = 0
## Host: hash of each board's last sent look (path -> hash); cleared when a
## guest arrives so it gets every board once.
var _board_hashes: Dictionary[String, int] = {}
var _known_ready_peers: Array[int] = []
var _last_world_hash: int = 0
var _seconds_since_world_sent: float = 0.0
## Host: each guest's health (on their stand-in) and the whole points last sent to them.
var _vitals: Dictionary[int, PlayerVitals] = {}
var _sent_health: Dictionary[int, int] = {}
## Host: when each guest's last own-hurt report counted (Time.get_ticks_msec()).
var _last_hurt_report_msec: Dictionary[int, int] = {}


## Called by the House level at setup (after its fronts are set up).
func setup(house_level: HouseLevel) -> void:
	_level = house_level
	entities.local_hold_anchor = _find_local_hold_anchor
	_mark_local_hold_anchors()
	Coop.players_changed.connect(_on_players_changed)
	Events.floating_text_shown.connect(_on_floating_text_shown)
	Events.beam_fired.connect(_on_beam_fired)
	Events.positional_sound_played.connect(_on_positional_sound_played)
	Events.house_breached.connect(_on_house_breached)
	Events.house_breach_ended.connect(_on_house_breach_ended)
	Coop.reconnecting.connect(_on_reconnecting)
	if _level.is_mirror:
		var rig: XRPlayerRig = _level.rig
		rig.forwards_hand_input = true
		rig.get_hands().is_mirror = true
		rig.hand_input_forwarded.connect(_on_local_hand_input)
		Coop.report_level_ready.call_deferred()


func _process(delta: float) -> void:
	if _level == null or not Coop.is_online():
		return
	_seconds_until_pose -= delta
	if _seconds_until_pose <= 0.0 and (Coop.is_host() or Coop.is_level_acknowledged()):
		_seconds_until_pose = POSE_INTERVAL_SECONDS
		_send_own_pose()
	if Coop.is_host():
		_seconds_since_world_sent += delta
		_seconds_until_snapshot -= delta
		if _seconds_until_snapshot <= 0.0:
			_seconds_until_snapshot = SNAPSHOT_INTERVAL_SECONDS
			_send_snapshot()
		_seconds_until_world -= delta
		if _seconds_until_world <= 0.0:
			_seconds_until_world = WORLD_INTERVAL_SECONDS
			_send_world()
			_send_changed_boards()
			_send_changed_health()
	elif _level.is_mirror:
		entities.smooth(delta)
		_mirror_held_items()
		_seconds_until_world -= delta
		if _seconds_until_world <= 0.0:
			_seconds_until_world = WORLD_INTERVAL_SECONDS
			_update_screen_rendering()

# ============================================
# PUBLIC API
# ============================================

## Host: shows [param message] to the guest too (HouseLevel.announce calls it).
func broadcast_announcement(message: String, color: Color, hold_seconds: float) -> void:
	for peer_id: int in Coop.get_ready_peers():
		_receive_announcement.rpc_id(peer_id, message, color, hold_seconds)


## Guest: something only this copy has (its rats) hurt this player; the host keeps the health.
func report_own_hurt(amount: float) -> void:
	if Coop.is_client() and Coop.is_level_acknowledged():
		_receive_own_hurt.rpc_id(1, amount)


## The other players currently drawn (tests).
func get_remote_players() -> Array[RemotePlayer]:
	var players: Array[RemotePlayer] = []
	for peer_id: int in _players:
		players.append(_players[peer_id])
	return players

## Host: the guests' health, one per guest (tests).
func get_remote_vitals() -> Array[PlayerVitals]:
	var vitals_list: Array[PlayerVitals] = []
	for peer_id: int in _vitals:
		if is_instance_valid(_vitals[peer_id]):
			vitals_list.append(_vitals[peer_id])
	return vitals_list

# ============================================
# MESSAGES
# ============================================

## A player's head and hands ([head, left hold, left ray origin, left ray
## direction, right hold, right ray origin, right ray direction]).
@rpc("any_peer", "unreliable_ordered", "call_remote", 2)
func _receive_pose(pose: Array) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if _level == null or not _is_trusted_sender(sender_id) or not _is_valid_pose(pose):
		return
	_apply_pose(_get_or_create_player(sender_id), pose)


## Guest -> host: a trigger or grip press, with the pose it was made at.
@rpc("any_peer", "reliable", "call_remote", 0)
func _receive_hand_button(hand: int, action_name: StringName, is_pressed: bool, pose: Array) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not Coop.is_host() or _level == null or not _is_trusted_sender(sender_id):
		return
	var is_known_action: bool = action_name == Types.XR_ACTION_TRIGGER_CLICK or action_name == Types.XR_ACTION_GRIP_CLICK
	if not is_known_action or (hand != Types.Hand.LEFT and hand != Types.Hand.RIGHT) or not _is_valid_pose(pose):
		return
	var player: RemotePlayer = _get_or_create_player(sender_id)
	_apply_pose(player, pose)
	player.press_button(hand as Types.Hand, action_name, is_pressed)


## Host -> guest: spawned things and station looks.
@rpc("authority", "unreliable_ordered", "call_remote", 1)
func _receive_snapshot(entity_entries: Array, node_states: Array) -> void:
	if _level == null or not _level.is_mirror:
		return
	entities.apply(entity_entries, Global.get_world_root())
	for node_state: Array in node_states:
		var node: Node = _find_level_node(str(node_state[0]))
		if node != null and node.is_in_group(Types.GROUP_NET_NODE) and node.has_method(METHOD_APPLY_STATE):
			node.call(METHOD_APPLY_STATE, node_state[1])


## Host -> guest: the shared state (see WORLD_*).
@rpc("authority", "unreliable_ordered", "call_remote", 3)
func _receive_world(world: Array) -> void:
	if _level == null or not _level.is_mirror:
		return
	Profile.wallet.from_dict(world[WORLD_WALLET])
	Profile.operation.from_dict(world[WORLD_OPERATION])
	var upgrades: Dictionary = world[WORLD_UPGRADES]
	if upgrades.hash() != _last_upgrades_hash:
		_last_upgrades_hash = upgrades.hash()
		Profile.upgrades.from_dict(upgrades)
		_level.apply_upgrades()
	var operation: Operation = _level.operation
	operation.stash.from_dict(Profile.operation.stash_data)
	operation.heat.value = float(world[WORLD_HEAT])
	_level.day_cycle.sync_elapsed(float(world[WORLD_TIME]))
	_level.set_mirrored_wrist_lines(world[WORLD_WRIST_LINES])


## Guest -> host: the guest's own copy hurt them (a rat's bite), a little at most.
@rpc("any_peer", "reliable", "call_remote", 0)
func _receive_own_hurt(amount: float) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not Coop.is_host() or _level == null or not _is_trusted_sender(sender_id) or not is_finite(amount):
		return
	# A rat bites a few times a run at most: reports any faster are dropped.
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_hurt_report_msec.get(sender_id, -MIN_HURT_REPORT_INTERVAL_MSEC) < MIN_HURT_REPORT_INTERVAL_MSEC:
		return
	_last_hurt_report_msec[sender_id] = now_msec
	var entry: Object = _vitals.get(sender_id)
	if is_instance_valid(entry):
		(entry as PlayerVitals).take_damage(clampf(amount, 0.0, MAX_REPORTED_HURT))


## Host -> guest: their own health (the host keeps it: raiders hit them there).
@rpc("authority", "reliable", "call_remote", 0)
func _receive_health(current: float, maximum: float) -> void:
	if _level == null or not _level.is_mirror or not is_finite(current) or not is_finite(maximum) or maximum <= 0.0:
		return
	_level.player_vitals.apply_net_health(clampf(current, 0.0, maximum), maximum)


## Host -> guest: a board's new look.
@rpc("authority", "reliable", "call_remote", 0)
func _receive_board(screen_path: String, look: Array) -> void:
	if _level == null or not _level.is_mirror:
		return
	var screen: WorldScreen = _find_level_node(screen_path) as WorldScreen
	if screen == null or screen.content == null:
		return
	ControlMirror.apply(screen.content, look)
	if screen.is_static:
		screen.request_redraw()


@rpc("authority", "reliable", "call_remote", 0)
func _receive_announcement(message: String, color: Color, hold_seconds: float) -> void:
	if _level != null:
		_level.announce(message, color, hold_seconds)


## Host -> guest: a shot's tracer (the guest's own, the host's, turrets', guards').
@rpc("authority", "unreliable", "call_remote", 0)
func _receive_beam(from_position: Vector3, to_position: Vector3) -> void:
	if _level == null or not _level.is_mirror:
		return
	var tracer: BeamTracer = Pools.spawn(TRACER_SCENE, Global.get_world_root(), from_position) as BeamTracer
	tracer.fire(from_position, to_position)


@rpc("authority", "unreliable", "call_remote", 0)
func _receive_floating_text(label_text: String, world_position: Vector3, color: Color) -> void:
	FloatingText3D.spawn(label_text, world_position, color, Global.get_world_root())


## Host -> guest: the front door broke (the guest's alarm goes off too).
@rpc("authority", "reliable", "call_remote", 0)
func _receive_breach(door_position: Vector3) -> void:
	if _level != null and _level.is_mirror:
		Events.house_breached.emit(door_position)


## Host -> guest: the raid after the break-in is beaten.
@rpc("authority", "reliable", "call_remote", 0)
func _receive_breach_ended() -> void:
	if _level != null and _level.is_mirror:
		Events.house_breach_ended.emit()


## Host -> guest: a sound of the host's world (stations, coins, shots, steps).
@rpc("authority", "unreliable", "call_remote", 0)
func _receive_sound(preset_name: StringName, world_position: Vector3, pitch_variation: float, volume_db: float) -> void:
	var stream: AudioStreamWAV = SfxSynth.get_preset(preset_name)
	if stream != null:
		Audio.play_sfx_at(stream, world_position, clampf(pitch_variation, 0.0, 0.5), clampf(volume_db, -40.0, 6.0))


## Host -> guest: their hand bumped into something (grab, put in, refusal).
@rpc("authority", "unreliable", "call_remote", 0)
func _receive_pulse(hand: int, strength: int) -> void:
	if _level != null and (hand == Types.Hand.LEFT or hand == Types.Hand.RIGHT):
		_level.rig.pulse(_level.rig.get_hand_pointer(hand as Types.Hand), strength as Types.HapticStrength)

# ============================================
# INTERNALS
# ============================================

## Host: only a guest that completed the handshake and has the level may act;
## guest: only the host speaks.
func _is_trusted_sender(sender_id: int) -> bool:
	if Coop.is_host():
		return Coop.get_ready_peers().has(sender_id)
	return sender_id == 1


## [head, left hold, left origin, left direction, right hold, right origin, right direction].
func _is_valid_pose(pose: Array) -> bool:
	return pose.size() == 7 and pose[0] is Transform3D and pose[1] is Transform3D and pose[2] is Vector3 \
		and pose[3] is Vector3 and pose[4] is Transform3D and pose[5] is Vector3 and pose[6] is Vector3


## A node of this level by a path the host sent (nothing outside the level).
func _find_level_node(relative_path: String) -> Node:
	if relative_path.is_empty() or relative_path.begins_with("/") or ".." in relative_path:
		return null
	return _level.get_node_or_null(NodePath(relative_path))


func _send_own_pose() -> void:
	var pose: Array = _get_own_pose()
	if Coop.is_host():
		for peer_id: int in Coop.get_ready_peers():
			_receive_pose.rpc_id(peer_id, pose)
	else:
		_receive_pose.rpc_id(1, pose)


func _get_own_pose() -> Array:
	var rig: XRPlayerRig = _level.rig
	var left: Array = rig.get_hand_pose(Types.Hand.LEFT)
	var right: Array = rig.get_hand_pose(Types.Hand.RIGHT)
	return [rig.get_head_transform(), left[0], left[1], left[2], right[0], right[1], right[2]]


func _apply_pose(player: RemotePlayer, pose: Array) -> void:
	if pose.size() < 7:
		return
	player.apply_pose(pose[0], pose[1], pose[2], pose[3], pose[4], pose[5], pose[6])


func _send_snapshot() -> void:
	var peers: Array[int] = Coop.get_ready_peers()
	if peers.is_empty():
		return
	var candidates: Array[Node] = get_tree().get_nodes_in_group(Types.GROUP_NET_ENTITY)
	candidates.append_array(get_tree().get_nodes_in_group(Types.GROUP_ENEMY))
	var entity_entries: Array = entities.collect(candidates)
	var node_states: Array = []
	for node: Node in get_tree().get_nodes_in_group(Types.GROUP_NET_NODE):
		if _level.is_ancestor_of(node) and node.has_method(METHOD_GET_STATE):
			node_states.append([String(_level.get_path_to(node)), node.call(METHOD_GET_STATE)])
	for peer_id: int in peers:
		_receive_snapshot.rpc_id(peer_id, entity_entries, node_states)


## Host: sends every board whose look changed since it was last sent.
func _send_changed_boards() -> void:
	var peers: Array[int] = Coop.get_ready_peers()
	if peers != _known_ready_peers:
		# Someone (re)joined: they get every board once.
		_known_ready_peers = peers
		_board_hashes.clear()
	if peers.is_empty():
		return
	for screen: WorldScreen in _get_board_screens():
		var look: Array = ControlMirror.capture(screen.content)
		var screen_path: String = String(_level.get_path_to(screen))
		var look_hash: int = look.hash()
		if _board_hashes.get(screen_path, 0) == look_hash:
			continue
		_board_hashes[screen_path] = look_hash
		for peer_id: int in peers:
			_receive_board.rpc_id(peer_id, screen_path, look)


## Guest: boards redraw only while the player is near and facing them (the
## fronts that would throttle them stand still on a guest).
func _update_screen_rendering() -> void:
	var head: Transform3D = _level.rig.get_head_transform()
	for screen: WorldScreen in _get_board_screens():
		if screen.is_static:
			continue
		var to_screen: Vector3 = screen.global_position - head.origin
		screen.set_rendering(to_screen.length() <= SCREEN_RENDER_DISTANCE and to_screen.dot(-head.basis.z) > 0.0)


## The level's in-world boards with their own content (not the popup screen).
func _get_board_screens() -> Array[WorldScreen]:
	var screens: Array[WorldScreen] = []
	for node: Node in get_tree().get_nodes_in_group(Types.GROUP_WORLD_SCREEN):
		var screen: WorldScreen = node as WorldScreen
		if screen != null and screen.content != null and _level.is_ancestor_of(screen):
			screens.append(screen)
	return screens


func _send_world() -> void:
	var peers: Array[int] = Coop.get_ready_peers()
	if peers.is_empty():
		return
	var world: Array = [
		Profile.wallet.to_dict(),
		Profile.operation.to_dict(),
		Profile.upgrades.to_dict(),
		_level.operation.heat.value,
		_level.day_cycle.clock.elapsed_seconds,
		_level.get_wrist_lines(),
	]
	var world_hash: int = world.hash()
	if world_hash == _last_world_hash and _seconds_since_world_sent < WORLD_HEARTBEAT_SECONDS and peers == _known_ready_peers:
		return
	_last_world_hash = world_hash
	_seconds_since_world_sent = 0.0
	for peer_id: int in peers:
		_receive_world.rpc_id(peer_id, world)


## Host: sends each guest their health when its whole points changed.
func _send_changed_health() -> void:
	for peer_id: int in _vitals:
		_send_health(peer_id)


func _send_health(peer_id: int) -> void:
	var entry: Object = _vitals.get(peer_id)
	if not is_instance_valid(entry) or not Coop.get_ready_peers().has(peer_id):
		return
	var vitals: PlayerVitals = entry as PlayerVitals
	var whole_points: int = ceili(vitals.get_health())
	if _sent_health.get(peer_id, -1) == whole_points:
		return
	_sent_health[peer_id] = whole_points
	_receive_health.rpc_id(peer_id, vitals.get_health(), vitals.get_max_health())


## Host: a health of their own for a guest's stand-in, tuned like the host's
## (HouseLevel.player_vitals); raiders find it in Types.GROUP_PLAYER_TARGET.
func _add_vitals(peer_id: int, player: RemotePlayer) -> void:
	var template: PlayerVitals = _level.player_vitals
	var vitals: PlayerVitals = PlayerVitals.new()
	vitals.name = "Vitals"
	vitals.max_health = template.max_health
	vitals.regen_delay_seconds = template.regen_delay_seconds
	vitals.regen_per_second = template.regen_per_second
	vitals.feet_source = player.get_feet_position
	vitals.display_name = Coop.get_player_name(peer_id)
	player.add_child(vitals)
	vitals.hit_taken.connect(func(_amount: float, _current: float) -> void: _send_health(peer_id))
	vitals.died.connect(func() -> void: _level.report_player_down(vitals.display_name))
	_vitals[peer_id] = vitals
	_sent_health.erase(peer_id)


## The guest's trigger / grip / click goes to the host with the pose it was made at.
func _on_local_hand_input(hand: Types.Hand, action_name: StringName, is_pressed: bool) -> void:
	if Coop.is_client() and Coop.is_level_acknowledged():
		_receive_hand_button.rpc_id(1, hand, action_name, is_pressed, _get_own_pose())


func _get_or_create_player(peer_id: int) -> RemotePlayer:
	if _players.has(peer_id) and is_instance_valid(_players[peer_id]):
		return _players[peer_id]
	var player: RemotePlayer = REMOTE_PLAYER_SCENE.instantiate() as RemotePlayer
	player.setup(peer_id, Coop.get_player_name(peer_id), Coop.get_player_index(peer_id), Coop.is_host())
	add_child(player)
	if player.hands != null:
		player.hands.pulse_requested.connect(func(hand: Types.Hand, strength: Types.HapticStrength) -> void:
			_receive_pulse.rpc_id(peer_id, hand, strength))
		# Their gun trigger: the defense side fires for them (same contract as the host's own shots).
		player.hands.secondary_action_pressed.connect(func(pointer: XRPointer) -> void:
			var recoil: Callable = func(strength: Types.HapticStrength) -> void: _receive_pulse.rpc_id(peer_id, Types.Hand.LEFT, strength)
			_level.context.guest_fired.emit(pointer, player.get_feet_position(), recoil))
		player.hands.secondary_action_released.connect(func(_pointer: XRPointer) -> void:
			_level.context.guest_trigger_released.emit())
	if Coop.is_host():
		_add_vitals(peer_id, player)
	_players[peer_id] = player
	return player


## Someone left (or the session ended): their stand-in lets go and disappears.
func _on_players_changed() -> void:
	for peer_id: int in _players.keys():
		if Coop.is_online() and Coop.player_names.has(peer_id):
			continue
		var player: RemotePlayer = _players[peer_id]
		if is_instance_valid(player):
			if player.hands != null:
				player.hands.release_all()
			player.queue_free()
		_players.erase(peer_id)
		_vitals.erase(peer_id)
		_sent_health.erase(peer_id)
		_last_hurt_report_msec.erase(peer_id)


func _on_beam_fired(from_position: Vector3, to_position: Vector3) -> void:
	if not Coop.is_host():
		return
	for peer_id: int in Coop.get_ready_peers():
		_receive_beam.rpc_id(peer_id, from_position, to_position)


func _on_floating_text_shown(label_text: String, world_position: Vector3, color: Color) -> void:
	if not Coop.is_host():
		return
	for peer_id: int in Coop.get_ready_peers():
		_receive_floating_text.rpc_id(peer_id, label_text, world_position, color)


## Guest: the connection dropped; show in the world that we're trying to get back.
func _on_reconnecting(attempt: int, attempts: int) -> void:
	if _level != null and is_instance_valid(_level):
		_level.announce(tr("Reconnecting (%d of %d)") % [attempt, attempts], Palette.WARNING, 1.6)


## Host: the other player hears the host's world too (synthesized sounds, by name).
func _on_house_breached(door_position: Vector3) -> void:
	if not Coop.is_host():
		return
	for peer_id: int in Coop.get_ready_peers():
		_receive_breach.rpc_id(peer_id, door_position)


func _on_house_breach_ended() -> void:
	if not Coop.is_host():
		return
	for peer_id: int in Coop.get_ready_peers():
		_receive_breach_ended.rpc_id(peer_id)


func _on_positional_sound_played(stream: AudioStream, world_position: Vector3, pitch_variation: float, volume_db: float) -> void:
	if not Coop.is_host() or Coop.get_ready_peers().is_empty():
		return
	var preset_name: StringName = SfxSynth.get_preset_name(stream)
	if preset_name.is_empty():
		return
	sounds_relayed += 1
	for peer_id: int in Coop.get_ready_peers():
		_receive_sound.rpc_id(peer_id, preset_name, world_position, pitch_variation, volume_db)


## Our own hold anchors say whose hand they are, so held items know their holder.
func _mark_local_hold_anchors() -> void:
	var rig: XRPlayerRig = _level.rig
	var local_peer_id: int = Coop.get_local_peer_id()
	var off_hand: Types.Hand = Types.Hand.LEFT if rig.dominant_hand == Types.Hand.RIGHT else Types.Hand.RIGHT
	# The flat simulator has one anchor for both: the dominant hand marks it last.
	for hand: Types.Hand in [off_hand, rig.dominant_hand]:
		rig.get_hold_anchor(hand).set_meta(RemotePlayer.META_HOLDER, Vector2i(local_peer_id, hand))


## Guest: where an item the host says we hold should be drawn.
func _find_local_hold_anchor(holder: Vector2i) -> Node3D:
	if holder.y < 0 or holder.x != Coop.get_local_peer_id():
		return null
	return _level.rig.get_hold_anchor(holder.y as Types.Hand)


## Guest: our hands "hold" the host's items for the slot highlights.
func _mirror_held_items() -> void:
	var local_peer_id: int = Coop.get_local_peer_id()
	var hands: HandInteractor = _level.rig.get_hands()
	for hand: Types.Hand in [Types.Hand.LEFT, Types.Hand.RIGHT]:
		hands.mirror_held_item(hand, entities.find_held_by(Vector2i(local_peer_id, hand)) as Grabbable)

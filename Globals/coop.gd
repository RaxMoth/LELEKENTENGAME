## Two-player co-op session: hosting, joining, who is connected and which
## level everyone plays. The host's game is the real world; a client mirrors
## it and sends its hand input there (see HouseCoopSync in the House level).
##
##   Coop.host()                         # on the router: UPnP opens the port when it can
##   Coop.join("203.0.113.5:7777")       # over the internet, or one of found_games
##   Coop.start_discovery()              # list games on the same Wi-Fi
##   if Coop.is_client(): ...            # the level mirrors the host
##
## Connection: Godot's ENet over UDP (port DEFAULT_PORT). On the same Wi-Fi
## the host is found by a broadcast (CoopDiscovery). Over the internet the
## client types the host's public address; the host's router must let the
## port through — UPnP asks it to automatically, otherwise forward UDP
## DEFAULT_PORT by hand or use a VPN (Tailscale, ZeroTier). A relay server
## for players behind strict NAT is the next step (see Docs/GAME.md).
##
## Dependencies: Events, SceneManager, SaveManager autoloads, CoopDiscovery
extends Node

enum Mode { OFFLINE, HOSTING, CLIENT }

signal mode_changed(mode: Mode)
## Someone joined (host side) or the player list arrived (client side).
signal players_changed
## Joining failed or the host went away; [param reason] is shown to the player.
signal connection_failed(reason: String)
## The list of games found on the local network changed.
signal found_games_changed
## The host's router answered (or not): the address to give a friend online.
signal internet_address_changed(address: String)

## Bump when the messages between host and client change: older builds
## can't play together and are told so.
const PROTOCOL_VERSION: int = 1
const DEFAULT_PORT: int = 7777
const DISCOVERY_PORT: int = 7778
## Two players: the host plus one.
const MAX_CLIENTS: int = 1
const ANNOUNCE_INTERVAL_SECONDS: float = 1.0
## A found game that stopped announcing for this long disappears from the list.
const FOUND_GAME_TIMEOUT_SECONDS: float = 3.5
const UPNP_TIMEOUT_MILLISECONDS: int = 2500
## The router forgets the port after this (seconds), even if the game was
## killed without closing it; a session longer than that renews it.
const UPNP_LEASE_SECONDS: int = 4 * 60 * 60
const UPNP_DESCRIPTION: String = "Porchlight VR"
const KEY_ADDRESS: String = "address"
const KEY_SEEN_AT: String = "seen_at"

var mode: Mode = Mode.OFFLINE
## peer id -> display name (both sides keep the full list).
var player_names: Dictionary[int, String] = {}
## Games announced on the local network: [{address, port, name, protocol, seen_at}].
var found_games: Array[Dictionary] = []
## The host's public "address:port" from UPnP ("" while unknown or refused).
var internet_address: String = ""

var _port: int = DEFAULT_PORT
## Clients whose copy of the current level is loaded (host side).
var _ready_peers: Array[int] = []
var _announcer: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var _seconds_until_announce: float = 0.0
## Router (UPnP) requests run one at a time on this worker so the network
## round trips never stall the headset's frames; more wait in the queue.
var _router_thread: Thread = null
var _router_jobs: Array[Callable] = []
## The port the router currently forwards to us (0 = none).
var _mapped_port: int = 0
## Guest: the host has our copy of its level and sends us its updates.
var _is_level_acknowledged: bool = false
## Guest: a level the host asked for while a scene change was still running.
var _pending_scene_path: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	Events.scene_changed.connect(_on_scene_changed)


func _process(delta: float) -> void:
	if _announcer != null and player_names.size() <= MAX_CLIENTS:
		_seconds_until_announce -= delta
		if _seconds_until_announce <= 0.0:
			_seconds_until_announce = ANNOUNCE_INTERVAL_SECONDS
			_announcer.put_packet(CoopDiscovery.encode(get_player_name(1), _port, PROTOCOL_VERSION))
	if _listener != null:
		_poll_discovery()


## Quitting: close the connection and the router port, nothing else (no
## scene or profile work while the app goes down).
func _exit_tree() -> void:
	stop_discovery()
	_stop_announcing()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	_close_router_port()
	if _router_thread != null and _router_thread.is_started():
		_router_thread.wait_to_finish()

# ============================================
# PUBLIC API
# ============================================

func is_online() -> bool:
	return mode != Mode.OFFLINE


func is_host() -> bool:
	return mode == Mode.HOSTING


## True while this game mirrors a host's world.
func is_client() -> bool:
	return mode == Mode.CLIENT


func get_local_peer_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


func get_player_name(peer_id: int) -> String:
	return player_names.get(peer_id, tr("Player %d") % (get_player_index(peer_id) + 1))


## 0 for the host, 1.. for clients in join order (picks the avatar color).
func get_player_index(peer_id: int) -> int:
	if peer_id == 1:
		return 0
	var peers: Array[int] = []
	peers.assign(player_names.keys())
	peers.sort()
	peers.erase(1)
	return peers.find(peer_id) + 1 if peers.has(peer_id) else 1


## Host side: clients that have the current level loaded and get its updates.
func get_ready_peers() -> Array[int]:
	return _ready_peers.duplicate()


## Guest: true once the host has our copy of its level (only then do we send
## it our pose and presses).
func is_level_acknowledged() -> bool:
	return _is_level_acknowledged


## Opens a game on [param port] for one friend. Also announces it on the
## local network and (unless [param opens_router] is false, as in tests)
## asks the router (UPnP) to let it through from the internet.
func host(port: int = DEFAULT_PORT, opens_router: bool = true) -> Error:
	leave()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		connection_failed.emit(tr("Could not open port %d") % port)
		return error
	multiplayer.multiplayer_peer = peer
	_port = port
	player_names = {1: tr("Host")}
	_ready_peers.clear()
	_start_announcing()
	if opens_router:
		_open_router_port(port)
	_set_mode(Mode.HOSTING)
	players_changed.emit()
	return OK


## Connects to a host at [param address] ("1.2.3.4", "1.2.3.4:7777",
## "[ipv6]:7777" or a host name). The level reloads as a mirror once the
## host welcomes us.
func join(address: String) -> Error:
	leave()
	if not CoopDiscovery.is_valid_address(address):
		connection_failed.emit(tr("That address doesn't look right"))
		return ERR_INVALID_PARAMETER
	var parts: Array = CoopDiscovery.split_address(address, DEFAULT_PORT)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(str(parts[0]), int(parts[1]))
	if error != OK:
		connection_failed.emit(tr("Could not connect to %s") % address)
		return error
	multiplayer.multiplayer_peer = peer
	_port = int(parts[1])
	_is_level_acknowledged = false
	_set_mode(Mode.CLIENT)
	return OK


## Ends the session. A client goes back to its own saved game.
func leave() -> void:
	var was_client: bool = mode == Mode.CLIENT
	if mode == Mode.OFFLINE and multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	_stop_announcing()
	_close_router_port()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	player_names.clear()
	_ready_peers.clear()
	_is_level_acknowledged = false
	_pending_scene_path = ""
	_set_mode(Mode.OFFLINE)
	players_changed.emit()
	if was_client:
		# Our own progress back first, then saving again — never the other way
		# round, or a save could land in between and overwrite it with the host's.
		SaveManager.reload_from_disk()
		SaveManager.set_saving_suspended(false)
		SceneManager.reload_current_scene()


## Starts listening for games announced on the local network.
func start_discovery() -> void:
	if _listener != null:
		return
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		# Another game on this machine listens already (two copies while testing).
		_listener = null


func stop_discovery() -> void:
	if _listener != null:
		_listener.close()
		_listener = null
	found_games.clear()


## Client: our copy of the host's level is loaded and ready for updates.
func report_level_ready() -> void:
	if is_client():
		_is_level_acknowledged = false
		_level_ready.rpc_id(1, SceneManager.current_scene_path)

# ============================================
# MESSAGES
# ============================================

## Client -> host, right after connecting.
@rpc("any_peer", "reliable")
func _hello(protocol_version: int) -> void:
	if not is_host():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if protocol_version != PROTOCOL_VERSION:
		_rejected.rpc_id(peer_id, tr("This game is a different version than the host's"))
		_drop_peer.call_deferred(peer_id)
		return
	player_names[peer_id] = tr("Player %d") % (get_player_index(peer_id) + 1)
	players_changed.emit()
	_players.rpc(player_names)
	_welcome.rpc_id(peer_id, SceneManager.current_scene_path)


## Host -> client: the version doesn't match. (A full game refuses at the
## connection already: ENet takes MAX_CLIENTS, and the host stops announcing.)
@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	connection_failed.emit(reason)
	leave()


## Host -> everyone: who plays.
@rpc("authority", "reliable")
func _players(names: Dictionary) -> void:
	player_names.clear()
	for peer_id: Variant in names:
		player_names[int(peer_id)] = str(names[peer_id])
	players_changed.emit()


## Host -> client: load the host's level as a mirror (our own save stays untouched).
@rpc("authority", "reliable")
func _welcome(scene_path: String) -> void:
	SaveManager.set_saving_suspended(true)
	_follow_scene(scene_path)


## Host -> clients: the host changed level (next day, restart).
@rpc("authority", "reliable")
func _load_scene(scene_path: String) -> void:
	_is_level_acknowledged = false
	_follow_scene(scene_path)


## Client -> host: its copy of [param scene_path] is loaded.
@rpc("any_peer", "reliable")
func _level_ready(scene_path: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not is_host() or not player_names.has(peer_id) or scene_path != SceneManager.current_scene_path:
		return
	if not _ready_peers.has(peer_id):
		_ready_peers.append(peer_id)
		players_changed.emit()
	_level_acknowledged.rpc_id(peer_id)


## Host -> client: the host has our level copy and starts sending updates.
@rpc("authority", "reliable")
func _level_acknowledged() -> void:
	_is_level_acknowledged = true

# ============================================
# INTERNALS
# ============================================

func _set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	mode_changed.emit(mode)


func _on_connected_to_server() -> void:
	_hello.rpc_id(1, PROTOCOL_VERSION)


func _on_connection_failed() -> void:
	connection_failed.emit(tr("Could not reach the host"))
	leave()


func _on_server_disconnected() -> void:
	connection_failed.emit(tr("The host left the game"))
	leave()


func _on_peer_connected(_peer_id: int) -> void:
	# Names arrive with the client's hello; nothing to do until then.
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host():
		return
	player_names.erase(peer_id)
	_ready_peers.erase(peer_id)
	players_changed.emit()
	_players.rpc(player_names)


func _drop_peer(peer_id: int) -> void:
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer != null:
		peer.disconnect_peer(peer_id)


func _on_scene_changed(scene_path: String) -> void:
	if is_client() and not _pending_scene_path.is_empty():
		var pending: String = _pending_scene_path
		_pending_scene_path = ""
		if pending != scene_path:
			_follow_scene(pending)
		return
	if not is_host():
		return
	_ready_peers.clear()
	# Only levels with co-op support (a CoopSync) can be shared; going to the
	# menu or such a level ends the session — the guest goes back to their own game.
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get_node_or_null(^"%CoopSync") == null:
		leave()
		return
	_load_scene.rpc(scene_path)


## Guest: loads the host's level as soon as no other scene change is running.
func _follow_scene(scene_path: String) -> void:
	if SceneManager.is_transitioning:
		_pending_scene_path = scene_path
		return
	SceneManager.change_scene(scene_path, {}, false)


func _start_announcing() -> void:
	_announcer = PacketPeerUDP.new()
	_announcer.set_broadcast_enabled(true)
	_announcer.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_seconds_until_announce = 0.0


func _stop_announcing() -> void:
	if _announcer != null:
		_announcer.close()
		_announcer = null


func _poll_discovery() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var has_changed: bool = false
	while _listener.get_available_packet_count() > 0:
		var game: Dictionary = CoopDiscovery.parse(_listener.get_packet())
		if game.is_empty():
			continue
		game[KEY_ADDRESS] = _listener.get_packet_ip()
		game[KEY_SEEN_AT] = now
		var known_index: int = -1
		for game_index: int in found_games.size():
			if found_games[game_index][KEY_ADDRESS] == game[KEY_ADDRESS] and found_games[game_index][CoopDiscovery.KEY_PORT] == game[CoopDiscovery.KEY_PORT]:
				known_index = game_index
		if known_index >= 0:
			found_games[known_index] = game
		else:
			found_games.append(game)
			has_changed = true
	for game_index: int in range(found_games.size() - 1, -1, -1):
		if now - float(found_games[game_index][KEY_SEEN_AT]) > FOUND_GAME_TIMEOUT_SECONDS:
			found_games.remove_at(game_index)
			has_changed = true
	if has_changed:
		found_games_changed.emit()


## Asks the router to forward [param port] (UPnP), in the background.
func _open_router_port(port: int) -> void:
	internet_address = ""
	_run_router_job(_open_router_port_blocking.bind(port))


## Lets the router close the port again (in the background).
func _close_router_port() -> void:
	internet_address = ""
	if _mapped_port != 0:
		_run_router_job(_close_router_port_blocking.bind(_mapped_port))
		_mapped_port = 0


func _run_router_job(job: Callable) -> void:
	_router_jobs.append(job)
	if _router_thread == null:
		_start_next_router_job()


func _start_next_router_job() -> void:
	if _router_jobs.is_empty():
		_router_thread = null
		return
	_router_thread = Thread.new()
	_router_thread.start(_router_jobs.pop_front())


## Back on the main thread after a router job: join it, start the next one.
func _on_router_job_done() -> void:
	if _router_thread != null:
		_router_thread.wait_to_finish()
	_start_next_router_job()


func _open_router_port_blocking(port: int) -> void:
	var upnp: UPNP = UPNP.new()
	var address: String = ""
	if upnp.discover(UPNP_TIMEOUT_MILLISECONDS, 2) == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway():
		if upnp.add_port_mapping(port, port, UPNP_DESCRIPTION, "UDP", UPNP_LEASE_SECONDS) == UPNP.UPNP_RESULT_SUCCESS:
			address = "%s:%d" % [upnp.query_external_address(), port]
	_on_router_answered.call_deferred(port, address)
	_on_router_job_done.call_deferred()


func _close_router_port_blocking(port: int) -> void:
	var upnp: UPNP = UPNP.new()
	if upnp.discover(UPNP_TIMEOUT_MILLISECONDS, 2) == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway():
		upnp.delete_port_mapping(port, "UDP")
	_on_router_job_done.call_deferred()


func _on_router_answered(port: int, address: String) -> void:
	if address.is_empty():
		return
	if not is_host() or port != _port:
		# Left (or re-hosted) while the router was answering: close what it opened.
		_run_router_job(_close_router_port_blocking.bind(port))
		return
	_mapped_port = port
	internet_address = address
	internet_address_changed.emit(address)

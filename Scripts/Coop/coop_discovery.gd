## The little UDP announcement a co-op host broadcasts on the local network
## once a second, so players on the same Wi-Fi find the game without typing
## an address. Pure data: building and checking the packet.
##
##   var packet: PackedByteArray = CoopDiscovery.encode("Max's house", 7777)
##   var game: Dictionary = CoopDiscovery.parse(bytes)   # {} when not ours
##
## Dependencies: none
class_name CoopDiscovery
extends RefCounted

## Identifies our packets among anything else on the port.
const GAME_ID: String = "porchlight-vr"
const KEY_GAME: String = "game"
const KEY_PROTOCOL: String = "protocol"
const KEY_NAME: String = "name"
const KEY_PORT: String = "port"
const MAX_NAME_LENGTH: int = 32


## The announcement for a host called [param host_name] listening on [param port].
static func encode(host_name: String, port: int, protocol_version: int) -> PackedByteArray:
	var announcement: Dictionary = {
		KEY_GAME: GAME_ID,
		KEY_PROTOCOL: protocol_version,
		KEY_NAME: host_name.left(MAX_NAME_LENGTH),
		KEY_PORT: port,
	}
	return JSON.stringify(announcement).to_utf8_buffer()


## {name, port, protocol} of a valid announcement, or {} for anything else
## (other programs, broken packets, impossible ports).
static func parse(bytes: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return {}
	var announcement: Dictionary = parsed
	if str(announcement.get(KEY_GAME, "")) != GAME_ID:
		return {}
	var port: int = int(announcement.get(KEY_PORT, 0))
	if port <= 0 or port > 65535:
		return {}
	return {
		KEY_NAME: str(announcement.get(KEY_NAME, "")).left(MAX_NAME_LENGTH),
		KEY_PORT: port,
		KEY_PROTOCOL: int(announcement.get(KEY_PROTOCOL, 0)),
	}


## True when [param address] looks like something to connect to: an IPv4 or
## IPv6 address or a host name, optionally followed by ":port".
static func is_valid_address(address: String) -> bool:
	var host: String = split_address(address)[0]
	return not host.is_empty() and (host.is_valid_ip_address() or host.is_valid_identifier() or "." in host)


## "1.2.3.4:7777" -> ["1.2.3.4", 7777]; without a port the [param default_port].
static func split_address(address: String, default_port: int = 0) -> Array:
	var trimmed: String = address.strip_edges()
	var port: int = default_port
	# IPv6 addresses contain colons themselves: only "[addr]:port" carries a port there.
	if trimmed.begins_with("[") and "]" in trimmed:
		var closing: int = trimmed.find("]")
		var after: String = trimmed.substr(closing + 1)
		if after.begins_with(":") and after.substr(1).is_valid_int():
			port = int(after.substr(1))
		return [trimmed.substr(1, closing - 1), port]
	if trimmed.count(":") == 1:
		var parts: PackedStringArray = trimmed.split(":")
		if parts[1].is_valid_int():
			port = int(parts[1])
		return [parts[0], port]
	return [trimmed, port]

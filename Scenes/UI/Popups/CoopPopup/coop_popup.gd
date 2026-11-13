## "Play Together": host a co-op game or join one — a game found on the
## same Wi-Fi with one click, or any host by address (typed with the keypad,
## since a headset has no keyboard). Shows the addresses to give a friend,
## who is connected, and leaving. Opened from the main menu, the pause menu
## and the "Play together" board in the house; inside a headset it shows on
## the in-world popup screen like every popup. Hosting from a menu starts
## the house right away (the guest comes in once it runs).
##
## Dependencies: BasePopup, Coop, CoopDiscovery, LevelBase, GameConfig
class_name CoopPopup
extends BasePopup

const BACK_ICON: Texture2D = preload("res://Assets/Icons/back.svg")
const KEYPAD_KEYS: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ".", ":"]
const KEY_HEIGHT: int = 88

@onready var _status_label: Label = %StatusLabel
@onready var _host_button: Button = %HostButton
@onready var _host_info: VBoxContainer = %HostInfo
@onready var _local_address_label: Label = %LocalAddressLabel
@onready var _internet_address_label: Label = %InternetAddressLabel
@onready var _join_section: VBoxContainer = %JoinSection
@onready var _games_list: VBoxContainer = %GamesList
@onready var _no_games_label: Label = %NoGamesLabel
@onready var _address_field: LineEdit = %AddressField
@onready var _keypad: GridContainer = %Keypad
@onready var _join_button: Button = %JoinButton
@onready var _leave_button: Button = %LeaveButton


func _on_opened(_data: Dictionary) -> void:
	_build_keypad()
	Coop.mode_changed.connect(func(_mode: Coop.Mode) -> void: _refresh())
	Coop.players_changed.connect(_refresh)
	Coop.found_games_changed.connect(_refresh)
	Coop.internet_address_changed.connect(func(_address: String) -> void: _refresh())
	Coop.connection_failed.connect(_on_connection_failed)
	closed.connect(func(_result: Variant) -> void: Coop.stop_discovery())
	Coop.start_discovery()
	_refresh()

# ============================================
# INTERNALS
# ============================================

func _refresh() -> void:
	_host_button.visible = Coop.mode == Coop.Mode.OFFLINE
	_join_section.visible = Coop.mode == Coop.Mode.OFFLINE
	_host_info.visible = Coop.is_host()
	_leave_button.visible = Coop.is_online()
	_join_button.disabled = not CoopDiscovery.is_valid_address(_address_field.text)
	match Coop.mode:
		Coop.Mode.OFFLINE:
			_status_label.text = tr("Play the same house with a friend: one hosts, the other joins.")
		Coop.Mode.HOSTING:
			var guests: int = Coop.get_ready_peers().size()
			_status_label.text = tr("You are hosting. Waiting for a friend to join.") if guests == 0 else tr("%s is playing with you.") % _get_guest_names()
		Coop.Mode.CLIENT:
			_status_label.text = tr("Playing in %s's house.") % Coop.get_player_name(1)
	if Coop.is_host():
		var local_address: String = "%s:%d" % [_get_local_address(), Coop.DEFAULT_PORT]
		_local_address_label.text = tr("Same Wi-Fi: %s") % local_address
		if Coop.internet_address.is_empty():
			_internet_address_label.text = tr("Over the internet: your router didn't open port %d. Forward UDP %d to this device, or both join a VPN such as Tailscale.") % [Coop.DEFAULT_PORT, Coop.DEFAULT_PORT]
		else:
			_internet_address_label.text = tr("Over the internet: %s") % Coop.internet_address
	_rebuild_games_list()


func _rebuild_games_list() -> void:
	for child: Node in _games_list.get_children():
		_games_list.remove_child(child)
		child.queue_free()
	_no_games_label.visible = Coop.found_games.is_empty()
	for game: Dictionary in Coop.found_games:
		var address: String = "%s:%d" % [game[Coop.KEY_ADDRESS], int(game[CoopDiscovery.KEY_PORT])]
		var button: Button = Button.new()
		button.theme_type_variation = &"SecondaryButton"
		button.custom_minimum_size = Vector2(0.0, KEY_HEIGHT)
		button.text = tr("Join %s (%s)") % [str(game[CoopDiscovery.KEY_NAME]), address]
		button.pressed.connect(func() -> void: _join(address))
		_games_list.add_child(button)


func _build_keypad() -> void:
	for key_text: String in KEYPAD_KEYS:
		var key: Button = Button.new()
		key.text = key_text
		key.theme_type_variation = &"SecondaryButton"
		key.custom_minimum_size = Vector2(0.0, KEY_HEIGHT)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.pressed.connect(func() -> void: _type(key_text))
		_keypad.add_child(key)
	var backspace: Button = Button.new()
	backspace.theme_type_variation = &"SecondaryButton"
	backspace.icon = BACK_ICON
	backspace.expand_icon = true
	backspace.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	backspace.custom_minimum_size = Vector2(0.0, KEY_HEIGHT)
	backspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backspace.pressed.connect(_erase_last_character)
	_keypad.add_child(backspace)


func _type(characters: String) -> void:
	_address_field.text += characters
	_address_field.caret_column = _address_field.text.length()
	_refresh()


func _erase_last_character() -> void:
	_address_field.text = _address_field.text.left(-1)
	_refresh()


func _join(address: String) -> void:
	_status_label.text = tr("Connecting to %s") % address
	Coop.join(address)


func _on_connection_failed(reason: String) -> void:
	_status_label.text = reason


func _get_guest_names() -> String:
	var names: PackedStringArray = PackedStringArray()
	for peer_id: int in Coop.get_ready_peers():
		names.append(Coop.get_player_name(peer_id))
	return ", ".join(names)


## The address another device on the same network reaches this one at.
func _get_local_address() -> String:
	for address: String in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "127.0.0.1"


func _on_host_button_pressed() -> void:
	if Coop.host() != OK:
		return
	if not Coop.is_coop_scene(get_tree().current_scene):
		# From a menu: into the house, where the friend joins.
		var house: LevelData = GameConfig.get_default().get_xr_start_level()
		close(null)
		if house != null:
			LevelBase.start_level(house)


func _on_join_button_pressed() -> void:
	_join(_address_field.text)


func _on_address_field_text_changed(_new_text: String) -> void:
	_refresh()


func _on_leave_button_pressed() -> void:
	Coop.leave()
	close(null)


func _on_close_button_pressed() -> void:
	close(null)

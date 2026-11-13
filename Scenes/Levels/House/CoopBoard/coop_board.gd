## A "Play together" board on the front room wall: the way into co-op for a
## headset player (who starts in the house, not at a menu). Pressing its
## button opens the CoopPopup on the in-world popup screen — host the house,
## or join a friend's game found on the same Wi-Fi — and the board shows
## who is playing. A co-op guest doesn't see it (they leave from the pause
## menu; their presses on the world act in the host's house).
##
## Dependencies: Coop, UI autoloads, PointerButton, Palette
class_name CoopBoard
extends Node3D

const COOP_POPUP: PackedScene = preload("res://Scenes/UI/Popups/CoopPopup/CoopPopup.tscn")

@onready var _status_label: Label3D = %StatusLabel
@onready var _open_button: PointerButton = %OpenButton


func _ready() -> void:
	_open_button.pressed.connect(func(_button: PointerButton) -> void: open_popup())
	Coop.mode_changed.connect(func(_mode: Coop.Mode) -> void: _refresh())
	Coop.players_changed.connect(_refresh)
	_refresh()


## Opens "Play together" (host or join) where the player looks.
func open_popup() -> void:
	if not UI.has_open_popup():
		UI.open_popup(COOP_POPUP)


## The button that opens it (tests).
func get_open_button() -> PointerButton:
	return _open_button


func _refresh() -> void:
	visible = not Coop.is_client()
	match Coop.mode:
		Coop.Mode.HOSTING:
			var guests: Array[int] = Coop.get_ready_peers()
			_status_label.text = tr("Hosting: waiting for a friend") if guests.is_empty() else tr("%s is playing with you.") % Coop.get_player_name(guests[0])
			_status_label.modulate = Palette.SUCCESS
		_:
			_status_label.text = tr("Host, or join a friend on the same Wi-Fi")
			_status_label.modulate = Palette.TEXT_MUTED

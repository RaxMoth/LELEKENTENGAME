## What the phone shows: a status bar (time, the app's name, put away), the
## app below it and a tab bar at the bottom.
##   Map     — the town around the player (PhoneMapView), zoom in / out and
##             how many officers are out there.
##   Weapons — every weapon the player owns, one big button each with its
##             ammo; the one in hand is highlighted. Tapping one takes it.
## Only shows what the Phone tells it and emits the taps; no game logic.
##
## Dependencies: PhoneMapView, WeaponData
class_name PhoneScreen
extends Control

## The player tapped [param weapon] in the weapons app.
signal weapon_chosen(weapon: WeaponData)
## The "put away" button.
signal close_requested

enum Page { MAP, WEAPONS }

const BUTTON_HEIGHT: float = 104.0

var _page: Page = Page.MAP
var _police_count: int = 0
var _weapon_buttons: Dictionary[StringName, Button] = {}

@onready var _time_label: Label = %TimeLabel
@onready var _title_label: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var _map_page: Control = %MapPage
@onready var _weapons_page: Control = %WeaponsPage
@onready var _map: PhoneMapView = %MapView
@onready var _zoom_in_button: Button = %ZoomInButton
@onready var _zoom_out_button: Button = %ZoomOutButton
@onready var _span_label: Label = %SpanLabel
@onready var _police_label: Label = %PoliceLabel
@onready var _weapon_list: VBoxContainer = %WeaponList
@onready var _map_tab: Button = %MapTab
@onready var _weapons_tab: Button = %WeaponsTab


func _ready() -> void:
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	_map_tab.pressed.connect(show_page.bind(Page.MAP))
	_weapons_tab.pressed.connect(show_page.bind(Page.WEAPONS))
	_zoom_in_button.pressed.connect(_zoom.bind(1))
	_zoom_out_button.pressed.connect(_zoom.bind(-1))
	show_page(Page.MAP)
	_update_zoom_controls()


## Switches the app: the map or the weapons.
func show_page(page: Page) -> void:
	_page = page
	_map_page.visible = page == Page.MAP
	_weapons_page.visible = page == Page.WEAPONS
	_title_label.text = tr("Map") if page == Page.MAP else tr("Weapons")
	_map_tab.theme_type_variation = &"" if page == Page.MAP else &"GhostButton"
	_weapons_tab.theme_type_variation = &"" if page == Page.WEAPONS else &"GhostButton"


## The app showing now.
func get_page() -> Page:
	return _page


## The map app's view.
func get_map() -> PhoneMapView:
	return _map


## How many officers the map shows (tests).
func get_police_count() -> int:
	return _police_count


## The clock in the status bar.
func show_time(time_text: String) -> void:
	_time_label.text = time_text


## How many officers are out (0: the streets are quiet).
func show_police_count(count: int) -> void:
	_police_count = count
	_police_label.text = tr("No police around") if count == 0 else tr("Police out: %d") % count
	_police_label.modulate = Palette.TEXT_MUTED if count == 0 else Palette.DANGER


## The weapons app: [param weapons] the player owns, [param details] one
## line each (ammo), [param in_hand] highlighted. Rebuilds the buttons only
## when the list of weapons changed.
func show_weapons(weapons: Array[WeaponData], details: PackedStringArray, in_hand: WeaponData) -> void:
	var ids: Array[StringName] = []
	for weapon: WeaponData in weapons:
		ids.append(weapon.id)
	if ids != _weapon_buttons.keys():
		_rebuild_weapon_buttons(weapons)
	for weapon_index: int in weapons.size():
		var weapon: WeaponData = weapons[weapon_index]
		var button: Button = _weapon_buttons[weapon.id]
		var detail: String = details[weapon_index] if weapon_index < details.size() else ""
		button.text = "%s   %s" % [tr(weapon.display_name), detail] if not detail.is_empty() else tr(weapon.display_name)
		button.theme_type_variation = &"" if weapon == in_hand else &"SecondaryButton"
		button.icon = preload("res://Assets/Icons/check.svg") if weapon == in_hand else null


## The button of [param weapon] in the weapons app (tests press it), or null.
func get_weapon_button(weapon: WeaponData) -> Button:
	return _weapon_buttons.get(weapon.id) if weapon != null else null


func _rebuild_weapon_buttons(weapons: Array[WeaponData]) -> void:
	for child: Node in _weapon_list.get_children():
		child.queue_free()
	_weapon_buttons.clear()
	for weapon: WeaponData in weapons:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(func() -> void: weapon_chosen.emit(weapon))
		_weapon_list.add_child(button)
		_weapon_buttons[weapon.id] = button


func _zoom(step: int) -> void:
	_map.zoom(step)
	_update_zoom_controls()


func _update_zoom_controls() -> void:
	_zoom_in_button.disabled = not _map.can_zoom(1)
	_zoom_out_button.disabled = not _map.can_zoom(-1)
	_span_label.text = tr("%d m") % roundi(_map.get_span_meters())

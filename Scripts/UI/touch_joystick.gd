## Touch joystick: Godot's native VirtualJoystick plus the safety this
## template needs. Point its actions at move_left / move_right / move_up /
## move_down and movement code can simply use Input.get_vector(), working with
## keyboard on desktop and the joystick on phones without any branching.
##
## Place it as a Control covering the area that should accept the thumb
## (e.g. the bottom part of the screen) on a CanvasLayer below the HUD, so HUD
## buttons on top still receive their touches. Size, mode (fixed / dynamic /
## following), dead zone and rest position are the native properties; the
## look comes from the VirtualJoystick styles in the theme.
##
## Added on top of the native control:
##   - keeps processing while the tree is paused, so a thumb lifted while the
##     pause menu is open is still seen and movement doesn't stick on resume
##   - releases its actions when hidden or removed (scene change mid-drag)
##
## Dependencies: none
class_name TouchJoystick
extends VirtualJoystick


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		_release_actions()


func _release_actions() -> void:
	for action: StringName in [action_left, action_right, action_up, action_down]:
		if InputMap.has_action(action):
			Input.action_release(action)

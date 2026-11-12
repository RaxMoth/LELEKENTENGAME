## Copies what a UI shows from one copy of a scene to another: texts,
## visibility, disabled / pressed buttons, bar values and tints of every
## Control under a root, addressed by child index. Co-op uses it to show the
## host's in-world boards (sales, office, armory...) on the guest's identical
## copies — the boards only display state, so their look is all that's needed.
##
##   var state: Array = ControlMirror.capture(host_board)
##   ControlMirror.apply(guest_board, state)
##
## Nodes created by code (rows, list entries) mirror too as long as both
## copies build them from the same data in the same order. A node that
## doesn't exist (or is another class) on the receiving side is skipped.
##
## Dependencies: none
class_name ControlMirror
extends RefCounted

const ENTRY_PATH: int = 0
const ENTRY_CLASS: int = 1
const ENTRY_VISIBLE: int = 2
const ENTRY_SELF_MODULATE: int = 3
const ENTRY_TEXT: int = 4
const ENTRY_DISABLED: int = 5
const ENTRY_PRESSED: int = 6
const ENTRY_VALUE: int = 7
const PROPERTY_TEXT: StringName = &"text"


## The look of every Control under [param root] (root itself included).
static func capture(root: Control) -> Array:
	var entries: Array = []
	_capture_node(root, PackedInt32Array(), entries)
	return entries


## Makes the Controls under [param root] look like [param entries] say.
static func apply(root: Control, entries: Array) -> void:
	for entry: Array in entries:
		var control: Control = _find(root, entry[ENTRY_PATH])
		if control == null or control.get_class() != str(entry[ENTRY_CLASS]):
			continue
		control.visible = bool(entry[ENTRY_VISIBLE])
		control.self_modulate = entry[ENTRY_SELF_MODULATE]
		if entry[ENTRY_TEXT] != null and PROPERTY_TEXT in control:
			control.set(PROPERTY_TEXT, str(entry[ENTRY_TEXT]))
		var button: BaseButton = control as BaseButton
		if button != null:
			button.disabled = bool(entry[ENTRY_DISABLED])
			if button.toggle_mode:
				button.set_pressed_no_signal(bool(entry[ENTRY_PRESSED]))
		var range_control: Range = control as Range
		if range_control != null:
			range_control.set_value_no_signal(float(entry[ENTRY_VALUE]))


static func _capture_node(control: Control, path: PackedInt32Array, entries: Array) -> void:
	var button: BaseButton = control as BaseButton
	var range_control: Range = control as Range
	entries.append([
		path,
		control.get_class(),
		control.visible,
		control.self_modulate,
		control.get(PROPERTY_TEXT) if PROPERTY_TEXT in control else null,
		button.disabled if button != null else false,
		button.button_pressed if button != null else false,
		range_control.value if range_control != null else 0.0,
	])
	for child_index: int in control.get_child_count():
		var child: Control = control.get_child(child_index) as Control
		if child == null or child.is_queued_for_deletion():
			continue
		var child_path: PackedInt32Array = path.duplicate()
		child_path.append(child_index)
		_capture_node(child, child_path, entries)


static func _find(root: Control, path: PackedInt32Array) -> Control:
	var node: Node = root
	for child_index: int in path:
		if child_index < 0 or child_index >= node.get_child_count():
			return null
		node = node.get_child(child_index)
	return node as Control

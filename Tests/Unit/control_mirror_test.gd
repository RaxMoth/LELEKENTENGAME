## Unit tests for ControlMirror: one UI's look copied onto an identical copy.
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func test_texts_visibility_buttons_and_bars_are_copied() -> void:
	var host: Control = auto_free(_make_board())
	var guest: Control = auto_free(_make_board())
	(host.get_child(0) as Label).text = "Regular wants Glow ×2"
	(host.get_child(1) as Button).disabled = true
	(host.get_child(1) as Button).visible = false
	(host.get_child(2) as ProgressBar).value = 35.0
	(host.get_child(0) as Label).self_modulate = Color.RED
	ControlMirror.apply(guest, ControlMirror.capture(host))
	assert_str((guest.get_child(0) as Label).text).is_equal("Regular wants Glow ×2")
	assert_bool((guest.get_child(1) as Button).disabled).is_true()
	assert_bool((guest.get_child(1) as Button).visible).is_false()
	assert_float((guest.get_child(2) as ProgressBar).value).is_equal(35.0)
	assert_object((guest.get_child(0) as Label).self_modulate).is_equal(Color.RED)


func test_rows_built_in_the_same_order_are_copied() -> void:
	var host: Control = auto_free(_make_board())
	var guest: Control = auto_free(_make_board())
	for board: Control in [host, guest]:
		var row: Label = Label.new()
		row.text = "Level 0"
		board.add_child(row)
	(host.get_child(3) as Label).text = "Level 2"
	ControlMirror.apply(guest, ControlMirror.capture(host))
	assert_str((guest.get_child(3) as Label).text).is_equal("Level 2")


func test_missing_or_different_nodes_are_skipped() -> void:
	var host: Control = auto_free(_make_board())
	var guest: Control = auto_free(VBoxContainer.new())
	guest.add_child(Button.new())
	(host.get_child(0) as Label).text = "only on the host"
	ControlMirror.apply(guest, ControlMirror.capture(host))
	assert_str((guest.get_child(0) as Button).text).is_equal("")


func _make_board() -> Control:
	var board: VBoxContainer = VBoxContainer.new()
	board.add_child(Label.new())
	board.add_child(Button.new())
	board.add_child(ProgressBar.new())
	return board

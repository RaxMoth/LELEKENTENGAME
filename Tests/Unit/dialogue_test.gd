## Unit tests for NPC talk: DialogueRunner (walking a conversation, rolls,
## outcomes), LinePicker (no repeats) and VoiceData (lines by category).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite

const STREET_TALK: DialogueData = preload("res://Ressources/Dialogue/street_talk.tres")


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	return random


func test_a_conversation_starts_with_a_greeting_and_offers_replies() -> void:
	var runner: DialogueRunner = DialogueRunner.new(STREET_TALK)
	var first: DialogueNodeData = runner.start()
	assert_str(String(first.line_category)).is_equal(String(VoiceLineData.HELLO))
	assert_int(runner.get_replies().size()).is_equal(3)
	assert_bool(runner.is_finished()).is_false()


func test_smalltalk_then_goodbye_ends_the_conversation() -> void:
	var runner: DialogueRunner = DialogueRunner.new(STREET_TALK)
	runner.start()
	assert_str(String(runner.choose(0).line_category)).is_equal(String(VoiceLineData.SMALLTALK))
	var goodbye: DialogueNodeData = runner.choose(1)
	assert_str(String(goodbye.line_category)).is_equal(String(VoiceLineData.BYE))
	assert_bool(runner.get_replies().is_empty()).is_true()
	assert_bool(runner.has_outcome(DialogueNodeData.Outcome.REFERRED_CUSTOMER)).is_false()


func test_a_sure_pitch_refers_a_customer_and_a_hopeless_one_does_not() -> void:
	var willing: DialogueRunner = DialogueRunner.new(STREET_TALK)
	willing.start(1.0)
	assert_str(String(willing.choose(1).line_category)).is_equal(String(VoiceLineData.PITCH_YES))
	assert_bool(willing.has_outcome(DialogueNodeData.Outcome.REFERRED_CUSTOMER)).is_true()
	assert_object(willing.choose(0)).is_null()
	assert_bool(willing.is_finished()).is_true()
	var unwilling: DialogueRunner = DialogueRunner.new(STREET_TALK)
	unwilling.start(0.0)
	assert_str(String(unwilling.choose(1).line_category)).is_equal(String(VoiceLineData.PITCH_NO))
	assert_bool(unwilling.has_outcome(DialogueNodeData.Outcome.REFERRED_CUSTOMER)).is_false()


func test_an_invalid_reply_changes_nothing() -> void:
	var runner: DialogueRunner = DialogueRunner.new(STREET_TALK)
	var first: DialogueNodeData = runner.start()
	assert_object(runner.choose(7)).is_same(first)


func test_the_picker_does_not_repeat_the_last_lines() -> void:
	var picker: LinePicker = LinePicker.new()
	var random: RandomNumberGenerator = _seeded(3)
	var previous: Array[int] = []
	for pick_index: int in 40:
		var picked: int = picker.pick(&"greet", 4, random)
		assert_int(picked).is_between(0, 3)
		assert_bool(previous.slice(maxi(0, previous.size() - 2)).has(picked)).is_false()
		previous.append(picked)


func test_the_picker_handles_tiny_pools() -> void:
	var picker: LinePicker = LinePicker.new()
	assert_int(picker.pick(&"bye", 0)).is_equal(-1)
	for pick_index: int in 5:
		assert_int(picker.pick(&"bye", 1)).is_equal(0)


func test_voices_group_their_lines_by_category() -> void:
	var voice: VoiceData = load("res://Ressources/Voices/polizist.tres") as VoiceData
	assert_int(voice.get_lines(VoiceLineData.RAID).size()).is_equal(4)
	assert_bool(voice.has_lines(VoiceLineData.GREET)).is_false()
	for line: VoiceLineData in voice.get_lines(VoiceLineData.HIT):
		assert_object(line.stream).is_not_null()
		assert_str(line.text).is_not_empty()

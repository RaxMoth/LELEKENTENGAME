## Smoke checks of the town around the house and of NPC voices: the town is
## built and walkable, people walk its sidewalks, pointing at one opens a
## voiced conversation, talking them into buying sends a customer to the
## window, walking off ends the talk, and customers greet at the window.
##
## Dependencies: SmokeTest, HouseLevel, Town, Pedestrian, DialogueBoard,
##               SalesWindow, NpcVoice, VoiceLineData
class_name TownSmokeChecks
extends RefCounted

## Where the player stands for the talk: the sidewalk in front of the gate.
const TALK_SPOT: Vector3 = Vector3(0.0, 0.0, -31.5)


static func run(test: SmokeTest, level: HouseLevel) -> void:
	var rig: XRPlayerRig = level.rig
	var town: Town = level.get_front(Town) as Town
	test.check(town != null and town.layout.building_footprints.size() > 40, "the town is built around the house")
	var pedestrians: Array[Pedestrian] = town.get_pedestrians()
	test.check(pedestrians.size() == town.town_data.pedestrian_count, "people walk the town's sidewalks")
	# Anyone may be pausing at a corner for a few seconds: watch everybody and
	# wait until most of them have moved.
	var starts: Array[Vector3] = []
	for pedestrian: Pedestrian in pedestrians:
		starts.append(pedestrian.global_position)
	var most_have_walked: Callable = func() -> bool:
		var walked: int = 0
		for person_index: int in pedestrians.size():
			if pedestrians[person_index].global_position.distance_to(starts[person_index]) > 0.1:
				walked += 1
		return walked * 2 > pedestrians.size()
	test.check(await test.wait_until(most_have_walked), "people in the street keep walking")

	_place_player(rig, TALK_SPOT)
	var partner: Pedestrian = pedestrians[0]
	partner.global_position = TALK_SPOT + Vector3(0.3, 0.0, -1.8)
	partner.was_pitched = false
	var data: TownData = town.town_data
	var saved_chances: Vector2 = Vector2(data.recruit_chance, data.max_recruit_chance)
	data.recruit_chance = 1.0
	data.max_recruit_chance = 1.0
	rig.tap_world_point(partner.get_node("%TalkButton").global_position)
	await test.frames(3)
	var board: DialogueBoard = town.get_dialogue_board()
	test.check(town.get_talk_partner() == partner and town.get_dialogue_screen().is_active, "pointing at a passer-by starts a conversation")
	test.check(partner.voice.is_speaking() and partner.voice.current_line.category == VoiceLineData.HELLO, "they answer out loud with a greeting")
	test.check(board.get_reply_count() == 3, "the panel offers the player's replies")
	var operation: Operation = level.operation
	var referred_before: int = operation.referred_customers
	var screen: WorldScreen = town.get_dialogue_screen()
	var pitch_button: Button = board.find_child("Reply2", true, false) as Button
	rig.tap_world_point(screen.pixel_to_world(pitch_button.get_global_rect().get_center()))
	await test.frames(3)
	test.check(partner.was_pitched and partner.voice.current_line != null and partner.voice.current_line.category == VoiceLineData.PITCH_YES, "asking them to buy gets a voiced yes")
	test.check(operation.referred_customers == referred_before + 1 or (level.get_front(SalesWindow) as SalesWindow).get_queue_size() > 0, "a talked-into buyer is on the way to the window")
	data.recruit_chance = saved_chances.x
	data.max_recruit_chance = saved_chances.y
	_place_player(rig, TALK_SPOT + Vector3(8.0, 0.0, 0.0))
	await test.physics_frames(3)
	test.check(town.get_talk_partner() == null and not town.get_dialogue_screen().is_active, "walking off ends the conversation")
	_place_player(rig, Vector3(2.2, 0.0, -3.6))

	var window: SalesWindow = level.get_front(SalesWindow) as SalesWindow
	window.clear_queue()
	await test.physics_frames(2)
	var customer: Customer = window.flow.spawn_customer()
	test.check(await test.wait_until(func() -> bool: return window.get_front_customer() == customer), "a customer walks up to the window")
	await test.wait_until(func() -> bool: return customer.has_greeted)
	test.check(customer.has_greeted and customer.voice.voice != null, "a customer at the window greets the player in their voice")
	level.operation.referred_customers = 0
	window.clear_queue()


static func _place_player(rig: XRPlayerRig, feet_target: Vector3) -> void:
	var feet: Vector3 = rig.get_feet_position()
	rig.move_origin_by(Vector3(feet_target.x - feet.x, 0.0, feet_target.z - feet.z))

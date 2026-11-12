## Stages a co-op moment for screenshots: the house with a second player in
## the lab (their head, hands, beam and name), holding a glowcap.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_coop`.
##
## Dependencies: HouseLevel, Lab, RemotePlayer, IngredientCrate
extends RefCounted

const REMOTE_PLAYER_SCENE: PackedScene = preload("res://Scenes/Entities/RemotePlayer/RemotePlayer.tscn")


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var lab: Lab = level.get_front(Lab) as Lab
	var other: RemotePlayer = REMOTE_PLAYER_SCENE.instantiate() as RemotePlayer
	other.setup(2, "Player 2", 1, true)
	level.add_child(other)
	# Standing by the crates, facing the lab's middle, the right hand reaching toward the grinder.
	var head: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(-70.0)), Vector3(-3.9, 1.72, -0.2))
	var left_hold: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(-70.0)), Vector3(-3.75, 1.15, -0.45))
	var right_hold: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(-100.0)), Vector3(-3.55, 1.25, -0.1))
	var grinder_slot: Vector3 = lab.get_station(&"Grinder").get_input_sockets()[0].global_position
	other.apply_pose(head, left_hold, left_hold.origin, -left_hold.basis.z, right_hold, right_hold.origin, (grinder_slot - right_hold.origin).normalized())
	var item: Grabbable = lab.get_crate(&"glowcap").take_item()
	item.attach_to(other.get_hold_anchor(Types.Hand.RIGHT))

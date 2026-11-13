## What a headset player has on them, shown on a stand-in in the front room
## (the flat view can't see its own body): the walking body mid-stride with
## the knife at the hip, the axe on the back and the pistol on the chest,
## and a pair of gloves — one open, one closed into a fist.
## Loaded by Tests/screenshot_tool.gd with `showcase=house_gear`.
##
## Dependencies: HouseLevel, WalkingBody, WeaponHolsters, GloveHand, WeaponCatalog
extends RefCounted

const BODY_SCENE: PackedScene = preload("res://Scenes/Entities/WalkingBody/WalkingBody.tscn")
const GLOVE_SCENE: PackedScene = preload("res://Scenes/Entities/XRPlayerRig/GloveHand.tscn")
const CATALOG: WeaponCatalog = preload("res://Ressources/Weapons/weapon_catalog.tres")
## Two stand-ins (feet x, z and facing yaw): one facing the camera (the
## pistol on the chest), one turned away (the axe on the back, the knife
## at the hip).
const STAND_INS: Array[Vector3] = [Vector3(1.0, -4.0, 2.5), Vector3(-0.7, -4.1, -0.6)]
const HOLSTERED: Dictionary[StringName, StringName] = {&"hip": &"knife", &"back": &"axe", &"chest": &"pistol"}


static func apply(scene: Node) -> void:
	var level: HouseLevel = scene as HouseLevel
	var stage: Node3D = level.get_node("World/Stage") as Node3D
	for stand_in: Vector3 in STAND_INS:
		_add_stand_in(stage, Vector3(stand_in.x, 0.0, stand_in.y), stand_in.z)
	var open_glove: GloveHand = GLOVE_SCENE.instantiate() as GloveHand
	open_glove.is_left = true
	open_glove.accent_color = Color(0.9608, 0.7216, 0.2549)
	stage.add_child(open_glove)
	open_glove.global_transform = Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.FORWARD, -0.6), Vector3(-0.32, 1.42, -2.6))
	open_glove.set_curl(0.0, 0.0)
	var fist: GloveHand = GLOVE_SCENE.instantiate() as GloveHand
	stage.add_child(fist)
	fist.global_transform = Transform3D(Basis(Vector3.UP, -0.5) * Basis(Vector3.FORWARD, 0.6), Vector3(0.08, 1.42, -2.6))
	fist.set_curl(1.0, 1.0)


## A walking body mid-stride at [param feet], facing [param yaw], with the
## knife, the axe and the pistol in their holsters.
static func _add_stand_in(stage: Node3D, feet: Vector3, yaw: float) -> void:
	var body: WalkingBody = BODY_SCENE.instantiate() as WalkingBody
	stage.add_child(body)
	var head: Transform3D = Transform3D(Basis(Vector3.UP, yaw), feet + Vector3(0.0, 1.72, 0.0))
	body.follow(head, 0.0, 0.0)
	for step_index: int in 10:
		head.origin += -head.basis.z * 0.035
		body.follow(head, 0.0, 1.0 / 60.0)
	for slot: StringName in HOLSTERED:
		var model: WeaponModel = CATALOG.find_weapon(HOLSTERED[slot]).model_scene.instantiate() as WeaponModel
		body.get_holster_anchor(slot).add_child(model)
		model.transform = Transform3D(WeaponHolsters.get_hang_basis(slot, 1.0), Vector3.ZERO)

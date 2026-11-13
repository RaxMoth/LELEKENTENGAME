## The weapons hanging on the player's body in a headset: the knife on the
## hip, the axe on the back, the gun across the chest (HolsterRules picks
## which). Close a hand's grip near one to draw it — the weapon is in that
## hand while the grip is held, and goes back when it opens. One weapon is
## out at a time (drawing another puts the first one back); an empty hand
## fights with its fist. The holstered models hang on the rig's WalkingBody
## and show only in a headset; the drawn weapon's model in the hand, its
## firing and its strikes are the FrontGarden's (HouseContext.holsters).
##
##   holsters.setup(rig)                   # claims grip presses near a holster
##   holsters.get_drawn(Types.Hand.LEFT)   # the knife, or null
##
## Dependencies: HolsterRules, WeaponCatalog, WeaponData, WeaponModel,
##               WalkingBody, XRPlayerRig, Profile, Audio, Types autoloads, SfxSynth
class_name WeaponHolsters
extends Node

## A hand drew [param weapon], or put it back ([param weapon] null).
signal drawn_changed(hand: Types.Hand, weapon: WeaponData)

const HANDS: Array[Types.Hand] = [Types.Hand.LEFT, Types.Hand.RIGHT]

## Every weapon there is (fists first).
@export var weapon_catalog: WeaponCatalog
## A hand closing its grip this close (meters) to a holster draws its weapon.
@export var draw_reach: float = 0.22

var _rig: XRPlayerRig = null
## Slot -> the weapon hanging there.
var _holstered: Dictionary[StringName, WeaponData] = {}
## Slot -> its model on the body.
var _models: Dictionary[StringName, WeaponModel] = {}
var _drawn: Dictionary[Types.Hand, WeaponData] = {Types.Hand.LEFT: null, Types.Hand.RIGHT: null}


## Hangs the owned weapons on [param rig]'s body and claims its grip presses near them.
func setup(rig: XRPlayerRig) -> void:
	_rig = rig
	rig.grip_filter = _on_grip
	Profile.armory.loadout.changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if Profile.armory.loadout.changed.is_connected(refresh):
		Profile.armory.loadout.changed.disconnect(refresh)
	for model: WeaponModel in _models.values():
		if is_instance_valid(model):
			model.queue_free()
	_models.clear()

# ============================================
# PUBLIC API
# ============================================

## The weapon [param hand] drew, or null (an empty hand: fists).
func get_drawn(hand: Types.Hand) -> WeaponData:
	return _drawn[hand]


## True while either hand holds a drawn weapon.
func has_drawn() -> bool:
	return _drawn[Types.Hand.LEFT] != null or _drawn[Types.Hand.RIGHT] != null


## The weapon hanging in [param slot] (WalkingBody.HOLSTER_*), or null.
func get_holstered(slot: StringName) -> WeaponData:
	return _holstered.get(slot)


## Where the holster [param slot] is in the world (Vector3.INF without one).
func get_holster_position(slot: StringName) -> Vector3:
	var anchor: Node3D = _rig.get_body().get_holster_anchor(slot) if _rig != null else null
	return anchor.global_position if anchor != null else Vector3.INF


## Draws the weapon in [param slot] into [param hand] (the other hand puts
## its weapon back first). Returns false when the slot is empty.
func draw(slot: StringName, hand: Types.Hand) -> bool:
	var weapon: WeaponData = _holstered.get(slot)
	if weapon == null:
		return false
	for other_hand: Types.Hand in HANDS:
		if other_hand != hand and _drawn[other_hand] != null:
			put_back(other_hand)
	_drawn[hand] = weapon
	if _rig != null:
		_rig.get_hands().set_hand_busy(hand, true)
	_update_models()
	Audio.play_sfx_at(SfxSynth.get_preset(&"click"), get_holster_position(slot), 0.1, -8.0)
	if _rig != null:
		_rig.pulse(_rig.get_hand_pointer(hand), Types.HapticStrength.LIGHT)
	drawn_changed.emit(hand, weapon)
	return true


## [param hand]'s weapon goes back into its holster.
func put_back(hand: Types.Hand) -> void:
	if _drawn[hand] == null:
		return
	_drawn[hand] = null
	if _rig != null:
		_rig.get_hands().set_hand_busy(hand, false)
	_update_models()
	drawn_changed.emit(hand, null)


## Re-hangs the weapons after the loadout changed (bought, equipped).
func refresh() -> void:
	_holstered = HolsterRules.assign(weapon_catalog, Profile.armory.loadout)
	for hand: Types.Hand in HANDS:
		var drawn: WeaponData = _drawn[hand]
		if drawn != null and _holstered.get(drawn.holster_slot) != drawn:
			put_back(hand)
	_update_models()

# ============================================
# INTERNALS
# ============================================

## Grip near a holster with an empty hand draws; opening the grip puts it back.
func _on_grip(hand: Types.Hand, is_pressed: bool) -> bool:
	if not is_pressed:
		if _drawn[hand] == null:
			return false
		put_back(hand)
		return true
	if _drawn[hand] != null:
		return true
	if not _rig.is_hand_empty(hand):
		return false
	# The controller's own hold point (the flat cursor's isn't a hand).
	var slot: StringName = _find_slot_near(_rig.get_hands().get_hold_anchor(hand).global_position)
	return slot != &"" and draw(slot, hand)


func _find_slot_near(point: Vector3) -> StringName:
	var nearest: StringName = &""
	var nearest_distance: float = draw_reach
	for slot: StringName in _holstered:
		var distance: float = point.distance_to(get_holster_position(slot))
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = slot
	return nearest


## One model per holstered weapon on the body (shown in a headset), hidden
## while it is drawn (the FrontGarden shows it in the hand then).
func _update_models() -> void:
	if _rig == null:
		return
	for slot: StringName in _models.keys():
		var model: WeaponModel = _models[slot]
		var weapon: WeaponData = _holstered.get(slot)
		if weapon == null or model.get_meta(&"weapon_id", &"") != weapon.id:
			model.queue_free()
			_models.erase(slot)
	for slot: StringName in _holstered:
		var weapon: WeaponData = _holstered[slot]
		if weapon.model_scene == null:
			continue
		if not _models.has(slot):
			var anchor: Node3D = _rig.get_body().get_holster_anchor(slot)
			if anchor == null:
				continue
			var model: WeaponModel = weapon.model_scene.instantiate() as WeaponModel
			model.set_meta(&"weapon_id", weapon.id)
			anchor.add_child(model)
			model.transform = Transform3D(get_hang_basis(slot, 1.0 if _rig.dominant_hand == Types.Hand.RIGHT else -1.0), Vector3.ZERO)
			_models[slot] = model
		var is_drawn: bool = _drawn[Types.Hand.LEFT] == weapon or _drawn[Types.Hand.RIGHT] == weapon
		_models[slot].visible = _rig.is_xr_active and not is_drawn


## How a weapon hangs in [param slot] on the body (its -Z is the muzzle or
## blade): the knife blade down at the hip, the gun across the chest
## pointing to the off side, the axe head up over the off shoulder.
## [param side]: 1 for a right-handed player, -1 for a left-handed one.
static func get_hang_basis(slot: StringName, side: float) -> Basis:
	match slot:
		WalkingBody.HOLSTER_HIP:
			return Basis.looking_at(Vector3.DOWN, Vector3.FORWARD)
		WalkingBody.HOLSTER_CHEST:
			return Basis.looking_at(Vector3(-side, 0.0, 0.0), Vector3.UP)
		WalkingBody.HOLSTER_BACK:
			return Basis.looking_at(Vector3(-0.5 * side, 0.86, 0.0).normalized(), Vector3.FORWARD)
	return Basis.IDENTITY

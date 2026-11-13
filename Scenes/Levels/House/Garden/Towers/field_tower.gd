## A tower the player set up outside — in the garden or anywhere in the
## streets (TowerField). A HouseTurret on a post, so the Security PC, the
## monitor wall and the turret goggles control it like the roof turrets;
## what it shoots depends on its TowerData:
##   GUN    — fast single shots at the nearest officer it can see.
##   MORTAR — a shell lobbed at the target; the blast hits everyone around.
##   BEAM   — a heat beam that stays on one target and burns hotter the
##            longer it holds it (and starts over on a new target).
##   SHOCK  — a discharge that jumps from the target to up to chain_count
##            officers next to it.
## Upgrade it with the button on its post (TowerField pays and records it).
## Pooled (the TowerField spawns one per placement).
##
## Dependencies: HouseTurret, TowerData, Yard, Raider, BeamTracer,
##               PopEffect3D, PointerButton, PlaceholderMesh3D, Pools, Audio
##               autoloads, SfxSynth, Palette
class_name FieldTower
extends HouseTurret

## The player pressed the upgrade button on the post.
signal upgrade_requested(tower: FieldTower)

## Height of the head above the ground (meters).
const HEAD_HEIGHT: float = 2.0
## A mortar shell's arc: highest point above the straight line (meters).
const SHELL_ARC_HEIGHT: float = 6.0

## What it is (set by configure()).
var data: TowerData = null
## Upgrade level (0 = as built).
var level: int = 0
## Its entry in Profile.towers.placements.
var placement_index: int = -1

var _beam_target: Raider = null
var _beam_seconds: float = 0.0
var _beam_tick: float = 0.0
var _decor: Node3D = null
var _barrel_decor: Node3D = null
var _base_decor: Node3D = null
## Counts spawns, so a shell fired before the tower went back to its pool never lands.
var _generation: int = 0
## Taken over: the beam burned this frame (fire() came from the trigger).
var _burned_this_frame: bool = false

@onready var _upgrade_button: PointerButton = %UpgradeButton
@onready var _label: Label3D = %TowerLabel
@onready var _beam: MeshInstance3D = %Beam
@onready var _aim_marker: MeshInstance3D = %AimMarker
@onready var _pole: MeshInstance3D = %Pole


func _ready() -> void:
	super()
	add_to_group(Types.GROUP_NET_ENTITY)
	_upgrade_button.pressed.connect(func(_button: PointerButton) -> void: upgrade_requested.emit(self))
	_beam.visible = false


## Makes it a [param tower_data] tower at upgrade [param tower_level],
## fighting in [param yard]. [param next_upgrade_cost] is shown on its
## button (0 = fully upgraded).
func configure(tower_data: TowerData, tower_level: int, yard: Yard, next_upgrade_cost: int) -> void:
	data = tower_data
	level = tower_level
	damage = data.get_damage(level)
	range_meters = data.get_range(level)
	fire_interval_seconds = data.fire_interval_seconds
	turn_speed_degrees = data.turn_speed_degrees
	setup(yard)
	set_mounted(true)
	# Taken over, it first points where it faces (not where the pool spawned it).
	_manual_aim_point = get_muzzle_position() + get_aim_direction() * 10.0
	_build_decor()
	var blast: float = maxf(1.0, data.splash_radius * 2.0)
	_aim_marker.scale = Vector3(blast, 1.0, blast)
	_label.text = "%s · %s" % [tr(data.display_name), tr("Lv %d") % (level + 1)]
	_upgrade_button.caption = tr("Upgrade $%s") % NumberFormat.with_separators(next_upgrade_cost) if next_upgrade_cost > 0 else tr("Max level")
	_upgrade_button.is_enabled = next_upgrade_cost > 0


func _on_pool_spawned() -> void:
	_generation += 1
	_beam_target = null
	_beam_seconds = 0.0
	_beam_tick = 0.0
	_beam.visible = false
	_cooldown = 0.0
	_aim_marker.visible = false
	_seconds_until_retarget = 0.0
	_head.rotation = Vector3.ZERO
	_barrel_pivot.rotation = Vector3.ZERO
	if _recoil_tween != null:
		_recoil_tween.kill()
	_flash.visible = false
	set_manual(false)


## Taken over or handed back: the beam goes out and cools down.
func set_manual(should_be_manual: bool) -> void:
	super(should_be_manual)
	if _aim_marker != null and not should_be_manual:
		_aim_marker.visible = false
	_beam_target = null
	_beam_seconds = 0.0
	if _beam != null:
		_beam.visible = false


func _on_pool_despawned() -> void:
	_beam.visible = false

# ============================================
# FIGHTING
# ============================================

func step(delta: float) -> void:
	if data == null:
		return
	if data.kind != TowerData.Kind.BEAM:
		super(delta)
		return
	_step_beam(delta)


func fire() -> Raider:
	if data == null:
		return null
	match data.kind:
		TowerData.Kind.MORTAR:
			return _fire_mortar()
		TowerData.Kind.SHOCK:
			return _fire_shock()
		TowerData.Kind.BEAM:
			# Taken over from the PC: the beam burns along the barrel while the trigger is held.
			return _burn_along_barrel(get_physics_process_delta_time())
	return super()


## The tower's name and level for the goggles' overlay and the monitors.
func get_display_name() -> String:
	return "%s · %s" % [tr(data.display_name), tr("Lv %d") % (level + 1)] if data != null else super()


## This kind's ability and whether it is ready (mortar shell, beam heat, discharge).
func get_ability_text() -> String:
	if data == null:
		return super()
	match data.kind:
		TowerData.Kind.MORTAR:
			return tr("Shell · blast %.1f m") % data.splash_radius if _cooldown <= 0.0 else tr("Shell · reloading")
		TowerData.Kind.BEAM:
			return tr("Heat beam · ×%.1f") % (_get_beam_damage_per_second() / maxf(0.01, damage))
		TowerData.Kind.SHOCK:
			return tr("Discharge · jumps to %d") % data.chain_count if _cooldown <= 0.0 else tr("Discharge · charging")
	return super()


## 0..1: reload or charge; the beam reports how hot it burns.
func get_ability_ready() -> float:
	if data != null and data.kind == TowerData.Kind.BEAM:
		# The beam's bar is its heat.
		return clampf(_beam_seconds / maxf(0.1, data.beam_ramp_seconds), 0.0, 1.0)
	return super()


## Taken over: the point to aim at. A mortar lobs its shell right there
## (on the ground, within its range); a ring shows where it lands.
func set_manual_aim(world_point: Vector3) -> void:
	super(world_point)
	if data == null or data.kind != TowerData.Kind.MORTAR:
		return
	var impact: Vector3 = _get_manual_impact()
	_aim_marker.visible = is_manual and impact.is_finite()
	if _aim_marker.visible:
		_aim_marker.global_position = impact + Vector3(0.0, 0.04, 0.0)


## Where a taken-over mortar's shell lands: the aim point on the ground,
## pulled into its reach (INF when the aim is behind it or too close).
func _get_manual_impact() -> Vector3:
	var ground: Vector3 = Vector3(_manual_aim_point.x, 0.0, _manual_aim_point.z)
	var base: Vector3 = Vector3(global_position.x, 0.0, global_position.z)
	var reach: float = base.distance_to(ground)
	if reach < data.min_range_meters:
		return Vector3.INF
	if reach > range_meters:
		ground = base + (ground - base).normalized() * range_meters
	return ground


func _find_target() -> Raider:
	return _yard.find_raider_nearest(get_muzzle_position(), range_meters, data.min_range_meters)


## A shell at the target (or where the barrel points); the blast comes when it lands.
func _fire_mortar() -> Raider:
	if _yard == null or _cooldown > 0.0:
		return null
	# On its own it only fires at a live target; by hand at the aim point (clamped to range).
	var has_target: bool = _target != null and _target.is_alive()
	if not is_manual and not has_target:
		return null
	var impact: Vector3 = _get_manual_impact() if is_manual else _target.global_position
	if not impact.is_finite():
		return null
	_cooldown = fire_interval_seconds
	var origin: Vector3 = get_muzzle_position()
	var effects: Node3D = _yard.get_effects_root()
	# The shell's way up and down: two tracer legs over the arc's top.
	var top: Vector3 = (origin + impact) * 0.5 + Vector3(0.0, SHELL_ARC_HEIGHT, 0.0)
	(Pools.spawn(TRACER_SCENE, effects, origin) as BeamTracer).fire(origin, top)
	(Pools.spawn(TRACER_SCENE, effects, top) as BeamTracer).fire(top, impact)
	PopEffect3D.spawn(origin, Palette.WARNING, 0.6, effects)
	Audio.play_sfx_at(SfxSynth.get_preset(&"shot_shotgun"), origin, 0.1, 2.0)
	_play_recoil()
	get_tree().create_timer(data.shell_flight_seconds, false).timeout.connect(_blast.bind(impact, _generation))
	return _target


## The mortar shell lands: everyone within the blast takes damage (less at the edge).
func _blast(impact: Vector3, generation: int) -> void:
	if _yard == null or not is_inside_tree() or generation != _generation:
		return
	var effects: Node3D = _yard.get_effects_root()
	PopEffect3D.spawn(impact + Vector3(0.0, 0.4, 0.0), Palette.WARNING, data.splash_radius * 1.4, effects)
	PopEffect3D.spawn(impact + Vector3(0.0, 0.8, 0.0), Palette.DANGER, data.splash_radius * 0.8, effects)
	Audio.play_sfx_at(SfxSynth.get_preset(&"explosion"), impact, 0.1, 6.0)
	for raider: Raider in _yard.find_raiders_around(impact, data.splash_radius):
		var distance: float = Vector2(raider.global_position.x - impact.x, raider.global_position.z - impact.z).length()
		var share: float = lerpf(1.0, 0.4, clampf(distance / maxf(0.1, data.splash_radius), 0.0, 1.0))
		raider.take_hit(damage * share, self, true, data.pierces_armor)


## A discharge at the target that jumps on to the officers next to it.
func _fire_shock() -> Raider:
	if _yard == null or _cooldown > 0.0:
		return null
	var first: Raider = _target if _target != null and _target.is_alive() and not is_manual else _yard.pick_raider(get_muzzle_position(), get_aim_direction(), range_meters)
	if first == null:
		return null
	_cooldown = fire_interval_seconds
	var effects: Node3D = _yard.get_effects_root()
	var hit: Array[Raider] = [first]
	var from: Vector3 = get_muzzle_position()
	var current: Raider = first
	while current != null:
		(Pools.spawn(TRACER_SCENE, effects, from) as BeamTracer).fire(from, current.get_hit_center())
		PopEffect3D.spawn(current.get_hit_center(), Palette.GEM, 0.7, effects)
		current.take_hit(damage, self, true, data.pierces_armor)
		from = current.get_hit_center()
		current = null
		if hit.size() >= data.chain_count:
			break
		var nearest_distance: float = data.chain_range
		for other: Raider in _yard.find_raiders_around(from, data.chain_range):
			var distance: float = other.get_hit_center().distance_to(from)
			if not hit.has(other) and distance < nearest_distance:
				nearest_distance = distance
				current = other
		if current != null:
			hit.append(current)
	Audio.play_sfx_at(SfxSynth.get_preset(&"crackle"), get_muzzle_position(), 0.1, 0.0)
	_play_recoil()
	return first


## The heat beam on its own: holds the nearest target, hotter every second on it.
func _step_beam(delta: float) -> void:
	if _yard == null:
		return
	if is_manual:
		_swing_toward(_manual_aim_point, delta)
		# The trigger was let go: the beam goes out.
		if not _burned_this_frame:
			_beam.visible = false
			_beam_target = null
			_beam_seconds = 0.0
		_burned_this_frame = false
		return
	_seconds_until_retarget -= delta
	if _beam_target == null or not _beam_target.is_alive() or Pools.is_in_pool(_beam_target) or get_muzzle_position().distance_to(_beam_target.get_hit_center()) > range_meters:
		if _seconds_until_retarget <= 0.0:
			_seconds_until_retarget = retarget_interval_seconds
			_beam_target = _find_target()
			_beam_seconds = 0.0
	if _beam_target == null:
		_beam.visible = false
		return
	var aligned: bool = _swing_toward(_beam_target.get_hit_center(), delta)
	if not aligned:
		_beam.visible = false
		return
	_beam_seconds += delta
	_beam_tick += delta
	_show_beam(_beam_target.get_hit_center())
	if _beam_tick >= fire_interval_seconds:
		_beam_tick = 0.0
		_beam_target.take_hit(_get_beam_damage_per_second() * fire_interval_seconds, self, true, true)


## Taken over from the PC: burns whatever the barrel points at.
func _burn_along_barrel(delta: float) -> Raider:
	_burned_this_frame = true
	var target: Raider = _yard.pick_raider(get_muzzle_position(), get_aim_direction(), range_meters) if _yard != null else null
	if target != _beam_target:
		_beam_target = target
		_beam_seconds = 0.0
	if target == null:
		_beam.visible = false
		return null
	_beam_seconds += delta
	_beam_tick += delta
	_show_beam(target.get_hit_center())
	if _beam_tick >= fire_interval_seconds:
		_beam_tick = 0.0
		target.take_hit(_get_beam_damage_per_second() * fire_interval_seconds, self, true, true)
	return target


## Damage per second now: from the base up to beam_max_multiplier the longer it holds its target.
func _get_beam_damage_per_second() -> float:
	var heat: float = clampf(_beam_seconds / maxf(0.1, data.beam_ramp_seconds), 0.0, 1.0)
	return damage * lerpf(1.0, data.beam_max_multiplier, heat)


## Stretches the beam from the muzzle to [param point]; thicker and brighter as it heats up.
func _show_beam(point: Vector3) -> void:
	var origin: Vector3 = get_muzzle_position()
	var length: float = origin.distance_to(point)
	if length < 0.05:
		return
	var heat: float = clampf(_beam_seconds / maxf(0.1, data.beam_ramp_seconds), 0.0, 1.0)
	_beam.visible = true
	_beam.global_transform = Transform3D(Basis.looking_at(point - origin, Vector3.UP), (origin + point) * 0.5)
	_beam.scale = Vector3(lerpf(0.4, 1.4, heat), lerpf(0.4, 1.4, heat), length)

# ============================================
# LOOKS
# ============================================

## Paints the head in the kind's color and adds what makes it recognizable.
func _build_decor() -> void:
	for old: Node3D in [_decor, _barrel_decor, _base_decor]:
		if old != null:
			old.queue_free()
	_decor = Node3D.new()
	_head.add_child(_decor)
	_barrel_decor = Node3D.new()
	_barrel.add_child(_barrel_decor)
	_base_decor = Node3D.new()
	add_child(_base_decor)
	# The turret's generic wall-mount parts give way to the kind's own model.
	_hide_generic_parts()
	_head.position.y = data.head_height
	_muzzle.position = Vector3(0.0, 0.0, -0.1 if data.kind == TowerData.Kind.SHOCK else -0.86)
	_label.position.y = data.head_height + 0.85
	(_beam as PlaceholderMesh3D).color = data.color
	TowerModelBuilder.build(data, _base_decor, _decor, _barrel_decor, data.head_height)
	# Level stripes on the head: one per upgrade.
	for stripe_index: int in level:
		_add_decor(_decor, Vector3(0.0, 0.45 + stripe_index * 0.06, 0.22), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.3, 0.03, 0.02), Palette.GOLD, 0.0, 0.6)


## Hides the wall turret's mount, housing, sensor and tube (and the old post).
func _hide_generic_parts() -> void:
	_mount_mesh.visible = false
	_housing.visible = false
	_sensor.visible = false
	_pole.visible = false
	var tube: Node3D = _barrel.get_node_or_null("Tube") as Node3D
	if tube != null:
		tube.visible = false


## In the goggles the head's model hides so it doesn't block the view.
func set_seated(is_seated: bool) -> void:
	_hide_generic_parts()
	if _decor != null:
		_decor.visible = not is_seated


func _add_decor(parent: Node3D, at: Vector3, shape: PlaceholderMesh3D.ShapeKind, part_size: Vector3, color: Color, roll_x: float = 0.0, glow: float = 0.0) -> void:
	var part: PlaceholderMesh3D = PlaceholderMesh3D.new()
	part.shape_kind = shape
	part.size = part_size
	part.color = color
	part.glow = glow
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.position = at
	part.rotation.x = roll_x
	parent.add_child(part)

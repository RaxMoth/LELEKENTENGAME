## Base for the police's vehicles in a raid (squad car, armored vehicle,
## helicopter). A vehicle is a Raider to the rest of the game — the Yard
## keeps it in its list, guns, turrets and guards hit it through take_hit
## (armor counts), it counts toward the wave until it is destroyed — but it
## doesn't take cover, rush the door or hunt players: it drives its way
## through the town (Raider.march) and then does its own job
## (_on_arrived, _act). Its model is built in code from a few shared
## PlaceholderMesh3D shapes (_build_model).
##
## Scenes: SquadCar.tscn, ArmoredVehicle.tscn, PoliceHelicopter.tscn. Each
## has the nodes a Raider needs (%Visual, %Voice, %HealthComponent,
## %HitFlash3DComponent, %StateChart with Alive/Moving and Dead).
##
## Dependencies: Raider, Yard, PlaceholderMesh3D, PopEffect3D, Pools, Audio
##               autoloads, SfxSynth, Palette
class_name PoliceVehicle
extends Raider

## Seconds a destroyed vehicle burns before it is gone.
const WRECK_SECONDS: float = 0.6
## How fast (radians per second) a driving vehicle turns into a new street.
const STEER_SPEED: float = 3.0

## Diameter of the blast when it is destroyed.
@export var wreck_blast_diameter: float = 4.0

var _model_root: Node3D = null


func _ready() -> void:
	super()
	_model_root = Node3D.new()
	_model_root.name = "Model"
	_visual.add_child(_model_root)
	_build_model()


## Faces down the first street right away (a reused vehicle keeps no old heading).
func march(route: PackedVector2Array, yard: Yard) -> void:
	if route.size() > 1:
		var first_leg: Vector2 = route[1] - route[0]
		rotation = Vector3(0.0, atan2(first_leg.x, first_leg.y), 0.0)
	super(route, yard)


## Vehicles don't hunt players (they keep doing their job).
func start_hunting() -> void:
	pass


## Vehicles are always drawn as themselves (no crowd figure).
func uses_crowd_figure() -> bool:
	return false


## Vehicles never stand at the door.
func is_at_door() -> bool:
	return false


func _on_pool_spawned() -> void:
	super()
	_reset_vehicle()

# ============================================
# STATE CHART CALLBACKS (connected in the vehicle scenes)
# ============================================

func _on_moving_state_entered() -> void:
	_is_in_motion = true


func _on_moving_state_physics_processing(delta: float) -> void:
	if _yard == null or _is_frozen:
		return
	if is_marching():
		_step_march(delta)
	else:
		_act(delta)


func _on_dead_state_entered() -> void:
	_is_in_motion = false
	Profile.stats.increment(Types.STAT_ENEMIES_DEFEATED)
	Events.enemy_defeated.emit(self)
	defeated.emit(self)
	voice.say_last_words(VoiceLineData.DOWN)
	_on_destroyed()
	var blast_root: Node3D = _yard.get_effects_root() if _yard != null else Global.get_world_root()
	PopEffect3D.spawn(get_hit_center(), Palette.WARNING, wreck_blast_diameter, blast_root)
	PopEffect3D.spawn(get_hit_center() + Vector3(0.0, 0.6, 0.0), Palette.DANGER, wreck_blast_diameter * 0.6, blast_root)
	Audio.play_sfx_at(SfxSynth.get_preset(&"shot_shotgun"), get_hit_center(), 0.1, 4.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_visual, "scale", Vector3(1.0, 0.25, 1.0), WRECK_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(Pools.despawn.bind(self))

# ============================================
# VIRTUAL HOOKS
# ============================================

## @virtual Builds the vehicle's model under _model_root.
func _build_model() -> void:
	pass


## @virtual Back to a fresh vehicle (pool reuse).
func _reset_vehicle() -> void:
	pass


## @virtual At the end of its way through the town.
func _on_arrived() -> void:
	pass


## @virtual One frame after arriving (unloading, shelling, circling).
func _act(_delta: float) -> void:
	pass


## @virtual Destroyed (before the blast; e.g. the crew inside is lost).
func _on_destroyed() -> void:
	pass

# ============================================
# DRIVING
# ============================================

## Drives instead of jogging: turns smoothly into the next street.
func _step_march(delta: float) -> void:
	var here: Vector2 = Vector2(global_position.x, global_position.z)
	var target: Vector2 = _street_route[_street_index]
	var to_target: Vector2 = target - here
	var step_length: float = march_speed * delta
	if to_target.length() <= step_length:
		global_position = Vector3(target.x, global_position.y, target.y)
		_street_index += 1
		if _street_index >= _street_route.size():
			_finish_march()
		return
	var direction: Vector2 = to_target.normalized()
	global_position += Vector3(direction.x, 0.0, direction.y) * step_length
	var target_yaw: float = atan2(direction.x, direction.y)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(STEER_SPEED * delta, 0.0, 1.0))


func _finish_march() -> void:
	_street_route = PackedVector2Array()
	_street_index = 0
	_on_arrived()


## Adds one part of the model: a shared shape at [param local_position].
func _part(local_position: Vector3, shape: PlaceholderMesh3D.ShapeKind, part_size: Vector3, color: Color, glow: float = 0.0, parent: Node3D = null) -> PlaceholderMesh3D:
	var part: PlaceholderMesh3D = PlaceholderMesh3D.new()
	part.shape_kind = shape
	part.size = part_size
	part.color = color
	part.glow = glow
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.position = local_position
	(parent if parent != null else _model_root).add_child(part)
	return part

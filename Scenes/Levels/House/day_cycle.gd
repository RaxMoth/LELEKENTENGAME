## The house's day and night: runs the DayClock and drives the sun / moon
## light, sky, ambient and fog colors and the lamps, so the time of day reads
## at a glance. Tells the level when night falls.
## State: Day -> Night (a shift ends at the next dawn).
##
## Dependencies: DayClock, PlaceholderMesh3D, Palette, Types autoload
class_name DayCycle
extends Node

signal nightfall

## Share of a phase spent blending into the next one (dawn / dusk light).
const BLEND_SHARE: float = 0.15
## Seconds between lighting updates (daylight changes slowly).
const LIGHTING_INTERVAL_SECONDS: float = 0.25

## Day -> Night chart of this cycle.
@export var cycle_chart: StateChart
@export var day_seconds: float = 300.0
@export var night_seconds: float = 240.0
@export var start_hour: float = 7.0
@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export_group("Lamps")
## Its PlaceholderMesh3D children light up at night.
@export var lamps: Node3D
## They switch on below this much daylight ...
@export_range(0.0, 1.0, 0.05) var lamps_on_below: float = 0.5
## ... and glow this bright.
@export_range(0.0, 4.0, 0.1) var lamp_glow: float = 1.6

@export_group("Light")
@export var day_light_energy: float = 1.35
@export var night_light_energy: float = 0.4
@export var day_ambient_energy: float = 1.3
@export var night_ambient_energy: float = 0.75

var clock: DayClock = null

var _sky_material: ProceduralSkyMaterial = null
var _are_lamps_on: bool = false
var _seconds_until_lighting: float = 0.0


func _ready() -> void:
	clock = DayClock.new(day_seconds, night_seconds, start_hour)
	if world_environment != null and world_environment.environment.sky != null:
		_sky_material = world_environment.environment.sky.sky_material as ProceduralSkyMaterial
	_set_lamps(get_daylight() < lamps_on_below)
	_apply_lighting()


## Moves time on (called by the level while playing).
func advance(delta: float) -> void:
	var was_day: bool = clock.get_phase() == DayClock.Phase.DAY
	clock.advance(delta)
	if was_day and clock.get_phase() == DayClock.Phase.NIGHT:
		cycle_chart.send_event(Types.EVENT_NIGHTFALL)
		_seconds_until_lighting = 0.0
	_seconds_until_lighting -= delta
	if _seconds_until_lighting <= 0.0:
		_seconds_until_lighting = LIGHTING_INTERVAL_SECONDS
		_apply_lighting()


## Co-op guest: moves the clock on to the host's [param elapsed_seconds]
## (lighting and nightfall follow as if the time had passed here).
func sync_elapsed(elapsed_seconds: float) -> void:
	var behind: float = elapsed_seconds - clock.elapsed_seconds
	if behind > 0.0:
		advance(behind)


func is_night() -> bool:
	return clock.get_phase() == DayClock.Phase.NIGHT


func _on_night_state_entered() -> void:
	nightfall.emit()


## 1 in full daylight, 0 in full night, blending at dawn and dusk.
func get_daylight() -> float:
	var progress: float = clock.get_phase_progress()
	if clock.get_phase() == DayClock.Phase.DAY:
		return smoothstep(0.0, 1.0, minf(progress, 1.0 - progress) / BLEND_SHARE)
	return 0.0


func _apply_lighting() -> void:
	var daylight: float = clampf(get_daylight(), 0.0, 1.0)
	if sun != null:
		sun.light_color = Palette.MOONLIGHT.lerp(Palette.DAYLIGHT, daylight)
		sun.light_energy = lerpf(night_light_energy, day_light_energy, daylight)
		# The light swings across the sky over the shift; it never points up.
		sun.rotation.x = deg_to_rad(lerpf(-35.0, -60.0, daylight))
		sun.rotation.y = deg_to_rad(lerpf(-40.0, 40.0, clock.get_phase_progress()))
	if world_environment != null:
		var environment: Environment = world_environment.environment
		environment.ambient_light_color = Palette.AMBIENT_NIGHT.lerp(Palette.AMBIENT_DAY, daylight)
		environment.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, daylight)
		environment.fog_light_color = Palette.SKY_NIGHT_HORIZON.lerp(Palette.SKY_DAY_HORIZON, daylight)
	if _sky_material != null:
		_sky_material.sky_top_color = Palette.SKY_NIGHT.lerp(Palette.SKY_DAY, daylight)
		_sky_material.sky_horizon_color = Palette.SKY_NIGHT_HORIZON.lerp(Palette.SKY_DAY_HORIZON, daylight)
		_sky_material.ground_horizon_color = _sky_material.sky_horizon_color
	var should_light_lamps: bool = daylight < lamps_on_below
	if should_light_lamps != _are_lamps_on:
		_set_lamps(should_light_lamps)


func _set_lamps(is_on: bool) -> void:
	_are_lamps_on = is_on
	if lamps == null:
		return
	for lamp: Node in lamps.get_children():
		var lamp_mesh: PlaceholderMesh3D = lamp as PlaceholderMesh3D
		if lamp_mesh != null:
			lamp_mesh.glow = lamp_glow if is_on else 0.0

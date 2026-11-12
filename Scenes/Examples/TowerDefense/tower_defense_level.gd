## Example: tower defense. Tap a build spot to place a tower, tap again to
## upgrade. Stop every wave before your lives run out.
##
## Shows: Path2D + PathMoverComponent, WaveSpawner (path mode), TapArea,
## TargetingComponent (first-on-path), homing projectiles, pooled enemies,
## level-local economy, shop meta-upgrade (starting gold).
##
## Dependencies: LevelBase, Profile, Audio autoloads
extends LevelBase

const TOWER_SCENE: PackedScene = preload("res://Scenes/Examples/TowerDefense/TDTower.tscn")
const UPGRADE_WAR_CHEST: StringName = &"td_war_chest"

@export var starting_gold: int = 120
@export var starting_lives: int = 10
@export var tower_cost: int = 50
@export var upgrade_costs: Array[int] = [60, 90]
@export var score_per_kill: int = 10
@export var score_per_life_left: int = 50

var gold: int = 0
var lives: int = 0

@onready var wave_spawner: WaveSpawner = %WaveSpawner
@onready var build_spots: Node2D = %BuildSpots


func _on_level_setup() -> void:
	hud.set_currency_visible(false)
	var war_chest: UpgradeData = GameConfig.get_default().find_upgrade(UPGRADE_WAR_CHEST)
	gold = starting_gold + (int(Profile.upgrades.get_value(war_chest)) if war_chest != null else 0)
	lives = starting_lives
	for spot: Node in build_spots.get_children():
		var build_spot: TDBuildSpot = spot as TDBuildSpot
		build_spot.tapped.connect(_on_build_spot_tapped)
		build_spot.set_label("%d" % tower_cost)
	wave_spawner.enemy_spawned.connect(_on_enemy_spawned)
	wave_spawner.wave_started.connect(func(wave_number: int, _wave: WaveData) -> void:
		hud.show_message(tr("Wave %d") % wave_number, 1.2)
		_update_status())
	wave_spawner.all_waves_cleared.connect(_on_all_waves_cleared)
	_update_status()


func _on_level_started() -> void:
	wave_spawner.start()


func _on_level_finished(_result: LevelResult) -> void:
	wave_spawner.stop()


func _on_enemy_spawned(enemy: Node2D) -> void:
	var creep: TDEnemy = enemy as TDEnemy
	if not creep.killed.is_connected(_on_enemy_killed):
		creep.killed.connect(_on_enemy_killed)
		creep.escaped.connect(_on_enemy_escaped)


func _on_enemy_killed(enemy: TDEnemy) -> void:
	gold += enemy.gold_reward
	add_score(score_per_kill)
	_update_status()


func _on_enemy_escaped(_enemy: TDEnemy) -> void:
	if not is_playing():
		return
	lives -= 1
	Events.camera_shake_requested.emit(0.4)
	Platform.vibrate(Types.HapticStrength.MEDIUM)
	_update_status()
	if lives <= 0:
		lose()


func _on_all_waves_cleared() -> void:
	add_score(lives * score_per_life_left)
	win()


func _on_build_spot_tapped(spot: TDBuildSpot) -> void:
	if not is_playing():
		return
	if spot.tower == null:
		if not _try_spend(tower_cost, spot):
			return
		var tower: TDTower = TOWER_SCENE.instantiate() as TDTower
		spot.add_child(tower)
		spot.tower = tower
		spot.set_label("%d" % upgrade_costs[0])
	elif spot.tower.can_upgrade():
		var upgrade_cost: int = upgrade_costs[mini(spot.tower.level - 1, upgrade_costs.size() - 1)]
		if not _try_spend(upgrade_cost, spot):
			return
		spot.tower.upgrade()
		spot.set_label("%d" % upgrade_costs[mini(spot.tower.level - 1, upgrade_costs.size() - 1)] if spot.tower.can_upgrade() else tr("Max"))
	Audio.play_ui(Audio.UI_CONFIRM)
	_update_status()


func _try_spend(cost: int, spot: TDBuildSpot) -> bool:
	if gold < cost:
		Audio.play_ui(Audio.UI_ERROR)
		TweenFX.shake(spot, 8.0)
		return false
	gold -= cost
	return true


func _update_status() -> void:
	var total_waves: int = wave_spawner.get_total_waves()
	var wave_text: String = tr("Wave %d") % maxi(1, wave_spawner.current_wave_number)
	hud.set_progress(wave_spawner.current_wave_number, total_waves, "%s/%d   ·   Lives %d   ·   Gold %d" % [wave_text, total_waves, lives, gold])

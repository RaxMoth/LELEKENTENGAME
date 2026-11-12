## Example: arena survivor ("bullet heaven"). Move with the joystick, the hero
## auto-fires, enemies come in waves around you, XP gems level you up and
## each level-up offers 3 perks. Survive the timer to win.
##
## Shows: TopDownPlayer, ChaserEnemy, WaveSpawner (ring mode), pickups,
## PerkChoicePopup + StatsComponent, AbilityComponent + CooldownButton,
## TouchJoystick, camera follow/shake, shop meta-upgrades.
##
## Dependencies: LevelBase, Profile, UI, Events, Audio autoloads
extends LevelBase

const PERK_CHOICE_POPUP: PackedScene = preload("res://Scenes/UI/Popups/PerkChoicePopup/PerkChoicePopup.tscn")
const UPGRADE_VITALITY: StringName = &"survivor_vitality"
const UPGRADE_POWER: StringName = &"survivor_power"
const PICKUP_XP: StringName = &"xp"
const PICKUP_COINS: StringName = &"coins"

@export var perks: Array[PerkData] = []
@export var first_level_xp: int = 5
@export var xp_growth: float = 1.35
@export var score_per_kill: int = 10

var player_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 5

var _perk_stacks: Dictionary[StringName, int] = {}
var _pending_level_ups: int = 0
var _is_choosing_perk: bool = false

@onready var player: TopDownPlayer = %Player
@onready var wave_spawner: WaveSpawner = %WaveSpawner
@onready var ability_component: AbilityComponent = %AbilityComponent


func _on_level_setup() -> void:
	camera.follow_target = player
	xp_to_next_level = first_level_xp
	_apply_meta_upgrades()
	_update_xp_bar()
	player.died.connect(_on_player_died)
	Events.pickup_collected.connect(_on_pickup_collected)
	Events.enemy_defeated.connect(_on_enemy_defeated)
	wave_spawner.wave_started.connect(func(wave_number: int, _wave: WaveData) -> void: hud.show_message(tr("Wave %d") % wave_number, 1.2))
	var nova_button: CooldownButton = CooldownButton.new()
	nova_button.custom_minimum_size = Vector2(200, 110)
	nova_button.theme_type_variation = &"SuccessButton"
	hud.add_action_control(nova_button)
	nova_button.bind_ability(ability_component, 0)


func _on_level_started() -> void:
	wave_spawner.start()


func _on_time_limit_reached() -> void:
	win()


func _on_level_finished(_result: LevelResult) -> void:
	wave_spawner.stop()


## Persistent shop upgrades become stat modifiers at the start of every run.
func _apply_meta_upgrades() -> void:
	var config: GameConfig = GameConfig.get_default()
	var vitality: UpgradeData = config.find_upgrade(UPGRADE_VITALITY)
	if vitality != null and Profile.upgrades.get_level(vitality.id) > 0:
		player.stats_component.add_modifier(StatModifier.create(Types.ENTITY_STAT_MAX_HEALTH, Types.StatModifierKind.FLAT, Profile.upgrades.get_value(vitality)))
	var power: UpgradeData = config.find_upgrade(UPGRADE_POWER)
	if power != null and Profile.upgrades.get_level(power.id) > 0:
		player.stats_component.add_modifier(StatModifier.create(Types.ENTITY_STAT_DAMAGE, Types.StatModifierKind.PERCENT, Profile.upgrades.get_value(power) / 100.0))


func _on_enemy_defeated(_enemy: Node) -> void:
	add_score(score_per_kill)


func _on_pickup_collected(pickup_id: StringName, amount: int, world_position: Vector2) -> void:
	match pickup_id:
		PICKUP_XP:
			_gain_xp(amount)
		PICKUP_COINS:
			Profile.wallet.add(Types.CURRENCY_COINS, amount)
			FloatingText.spawn("+%d" % amount, world_position, Palette.GOLD)


func _gain_xp(amount: int) -> void:
	current_xp += amount
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		player_level += 1
		xp_to_next_level = ceili(xp_to_next_level * xp_growth)
		_pending_level_ups += 1
	_update_xp_bar()
	if _pending_level_ups > 0 and not _is_choosing_perk:
		_offer_perks()


func _offer_perks() -> void:
	_is_choosing_perk = true
	while _pending_level_ups > 0 and is_playing():
		_pending_level_ups -= 1
		var choices: Array[PerkData] = RandomUtils.pick_weighted_perks(perks, 3, _can_take_perk)
		if choices.is_empty():
			break
		Audio.play_ui(Audio.UI_REWARD)
		var popup: BasePopup = UI.open_popup(PERK_CHOICE_POPUP, {"perks": choices, "stacks": _perk_stacks})
		var popup_result: Variant = await popup.closed
		var chosen_perk: PerkData = popup_result as PerkData
		if chosen_perk != null:
			_perk_stacks[chosen_perk.id] = _perk_stacks.get(chosen_perk.id, 0) + 1
			player.stats_component.add_modifiers(chosen_perk.modifiers)
	_pending_level_ups = 0
	_is_choosing_perk = false


func _can_take_perk(perk: PerkData) -> bool:
	return perk.max_stacks <= 0 or _perk_stacks.get(perk.id, 0) < perk.max_stacks


func _update_xp_bar() -> void:
	hud.set_progress(current_xp, xp_to_next_level, "Lv %d" % player_level)


func _on_player_died() -> void:
	await Global.wait(0.8)
	lose()

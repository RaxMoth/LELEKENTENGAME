## Global event bus. Systems that don't know each other talk through these
## typed signals instead of holding references (e.g. a level reward emits
## currency_changed via Profile, and every CurrencyDisplay updates itself).
##
## Emit:    Events.score_changed.emit(new_score, delta)
## Listen:  Events.score_changed.connect(_on_score_changed)
##
## Dependencies: none
extends Node
@warning_ignore_start("unused_signal")

# --- Application lifecycle (emitted by Platform) ---
signal app_paused
signal app_resumed
signal back_requested
signal safe_area_changed(safe_margins: Rect2)

# --- Navigation (emitted by SceneManager) ---
signal scene_change_started(scene_path: String)
signal scene_changed(scene_path: String)

# --- Level flow (emitted by LevelBase) ---
signal level_started(level_id: StringName)
signal level_finished(result: LevelResult)
signal level_paused(is_paused: bool)
signal score_changed(new_score: int, score_delta: int)

# --- Economy & progression (emitted by Profile modules) ---
signal currency_changed(currency_id: StringName, new_amount: int, amount_delta: int)
signal item_changed(item_id: StringName, new_count: int)
signal upgrade_purchased(upgrade_id: StringName, new_level: int)
signal stat_changed(stat_id: StringName, new_value: float)
signal achievement_unlocked(achievement: AchievementData)
signal daily_reward_claimed(streak_day: int, rewards: Dictionary)
signal energy_changed(current_energy: int, max_energy: int)
signal reputation_changed(new_reputation: int, amount_delta: int)
signal progress_reset

# --- Gameplay feedback ---
signal enemy_defeated(enemy: Node)

# --- Settings ---
signal setting_changed(setting_key: StringName, value: Variant)

# --- Monetization (emitted by Ads / Store) ---
signal rewarded_ad_finished(placement: StringName, was_rewarded: bool)
signal purchase_completed(product_id: StringName)
signal purchase_failed(product_id: StringName, reason: String)

# --- Co-op ---
## A floating number or note appeared in the world (the co-op host shows it
## to the other player too).
signal floating_text_shown(label_text: String, world_position: Vector3, color: Color)
## A shot's tracer flashed between two points (the co-op host shows it to the other player too).
signal beam_fired(from_position: Vector3, to_position: Vector3)

## Analytics facade. Gameplay code only talks to this autoload; the backend is
## a swappable AnalyticsProvider. Core funnel events are logged automatically.
##
##   Analytics.log_event(&"tutorial_step", {"step": 3})
##
## Dependencies: Events autoload, AnalyticsProvider
extends Node

const EVENT_SESSION_START: StringName = &"session_start"
const EVENT_LEVEL_START: StringName = &"level_start"
const EVENT_LEVEL_END: StringName = &"level_end"
const EVENT_PURCHASE: StringName = &"purchase"
const EVENT_AD_REWARDED: StringName = &"ad_rewarded"
const EVENT_ACHIEVEMENT: StringName = &"achievement_unlocked"

var _provider: AnalyticsProvider = AnalyticsProvider.new()


func _ready() -> void:
	_provider.initialize()
	Events.level_started.connect(func(level_id: StringName) -> void: log_event(EVENT_LEVEL_START, {"level_id": String(level_id)}))
	Events.level_finished.connect(func(result: LevelResult) -> void: log_event(EVENT_LEVEL_END, result.to_analytics()))
	Events.purchase_completed.connect(func(product_id: StringName) -> void: log_event(EVENT_PURCHASE, {"product_id": String(product_id)}))
	Events.rewarded_ad_finished.connect(func(placement: StringName, was_rewarded: bool) -> void: log_event(EVENT_AD_REWARDED, {"placement": String(placement), "rewarded": was_rewarded}))
	Events.achievement_unlocked.connect(func(achievement: AchievementData) -> void: log_event(EVENT_ACHIEVEMENT, {"id": String(achievement.id)}))
	log_event(EVENT_SESSION_START, {"platform": OS.get_name()})


func set_provider(provider: AnalyticsProvider) -> void:
	_provider = provider
	_provider.initialize()


func log_event(event_name: StringName, parameters: Dictionary = {}) -> void:
	_provider.log_event(event_name, parameters)

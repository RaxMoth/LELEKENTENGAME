## Base analytics backend. The default implementation prints events in debug
## builds. Subclass it to forward events to Firebase, GameAnalytics, etc. and
## assign the instance in Analytics.set_provider().
##
## Dependencies: none
class_name AnalyticsProvider
extends RefCounted


## @virtual
func initialize() -> void:
	pass


## @virtual
func log_event(event_name: StringName, parameters: Dictionary) -> void:
	if OS.is_debug_build():
		print("[Analytics] %s %s" % [event_name, parameters])

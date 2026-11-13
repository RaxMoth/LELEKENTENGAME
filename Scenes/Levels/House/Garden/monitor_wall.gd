## The Monitor Wall in the office (a defense upgrade after the Security PC):
## four big screens on the wall behind the desk, each showing a turret or a
## field tower live — switch, take over, aim and fire from any of them.
## Hidden until the upgrade is bought. Part of the defense front (the
## FrontGarden owns it); it only hangs in the office.
##
## Dependencies: TurretMonitor, SecurityPc, Yard, HouseFront
class_name MonitorWall
extends Node3D

var _monitors: Array[TurretMonitor] = []
var _is_available: bool = false


## Called by the FrontGarden: the screens show the turrets the Security PC knows.
func setup(security_pc: SecurityPc, yard: Yard) -> void:
	for child: Node in get_children():
		var monitor: TurretMonitor = child as TurretMonitor
		if monitor != null:
			monitor.setup(security_pc, yard, _monitors.size())
			_monitors.append(monitor)
	set_available(false)


## Shown and working once the upgrade is bought.
func set_available(is_available: bool) -> void:
	_is_available = is_available
	visible = is_available
	for monitor: TurretMonitor in _monitors:
		monitor.get_screen().set_active(is_available)
		if not is_available:
			monitor.release_control()


func is_available() -> bool:
	return _is_available


func get_monitors() -> Array[TurretMonitor]:
	return _monitors


## Per frame while the shift runs (FrontGarden).
func step(delta: float) -> void:
	if not _is_available:
		return
	for monitor: TurretMonitor in _monitors:
		monitor.step(delta)


## Lets each screen redraw only while it is near and in sight.
func refresh_display(front: HouseFront) -> void:
	if not _is_available:
		return
	for monitor: TurretMonitor in _monitors:
		front.update_screen_rendering(monitor.get_screen())

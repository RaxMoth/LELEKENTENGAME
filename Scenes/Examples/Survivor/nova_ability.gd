## Example AbilityData: damages and pushes back every enemy around the caster.
##
## Dependencies: Global, Events, Audio, Types autoloads
class_name NovaAbility
extends AbilityData

@export var radius: float = 280.0
@export var damage: float = 45.0
@export var knockback_force: float = 700.0
@export var ring_color: Color = Palette.GEM


func activate(caster: Node2D) -> bool:
	for enemy: Node2D in Global.get_group_nodes_in_radius(Types.GROUP_ENEMY, caster.global_position, radius):
		var health: HealthComponent = Global.find_component(enemy, HealthComponent) as HealthComponent
		if health != null:
			var push: Vector2 = caster.global_position.direction_to(enemy.global_position) * knockback_force
			health.apply_damage(DamageInfo.create(damage, caster, push))
	_spawn_ring(caster)
	Events.camera_shake_requested.emit(0.3)
	Audio.play_sfx(SfxSynth.get_preset(&"explosion"), 0.1, -4.0)
	Platform.vibrate(Types.HapticStrength.MEDIUM)
	return true


func _spawn_ring(caster: Node2D) -> void:
	var ring: PlaceholderShape = PlaceholderShape.new()
	ring.size = Vector2.ONE * radius * 2.0
	ring.color = Color(ring_color, 0.15)
	ring.outline_color = ring_color
	ring.outline_width = 6.0
	ring.shading = 0.0
	ring.shadow_enabled = false
	ring.global_position = caster.global_position
	Global.get_world_root().add_child(ring)
	ring.scale = Vector2.ONE * 0.2
	var tween: Tween = ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)

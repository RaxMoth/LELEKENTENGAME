## Object pooling for anything spawned often (attackers, bolts, sparks,
## floating text, effects). Avoids instantiate/queue_free spikes, which show
## up as dropped frames on standalone headsets.
##
##   var bolt: LaneBolt = Pools.spawn(BOLT_SCENE, effects_root, muzzle.global_position) as LaneBolt
##   Pools.despawn(bolt)   # instead of queue_free()
##
## Pooled nodes may implement _on_pool_spawned() / _on_pool_despawned()
## (see Types.METHOD_POOL_*) to reset their state. Pools are cleared on every
## scene change by SceneManager.
##
## Dependencies: Types autoload
extends Node

const META_POOL_KEY: StringName = &"_pool_key"
const META_IN_POOL: StringName = &"_in_pool"

## scene path -> idle instances
var _idle_instances: Dictionary[String, Array] = {}


## Returns a ready instance of [param scene] added under [param parent], with
## an unrotated [Node3D] root placed at the global [param spawn_position].
func spawn(scene: PackedScene, parent: Node, spawn_position: Vector3 = Vector3.ZERO) -> Node:
	var instance: Node = _take_instance(scene)
	parent.add_child(instance)
	if instance is Node3D:
		(instance as Node3D).global_transform = Transform3D(Basis.IDENTITY, spawn_position)
	if instance.has_method(Types.METHOD_POOL_SPAWNED):
		instance.call(Types.METHOD_POOL_SPAWNED)
	return instance


## Returns an instance to its pool. Safe to call from physics callbacks.
## Nodes that were not created by spawn() are simply freed.
func despawn(instance: Node) -> void:
	if not is_instance_valid(instance) or bool(instance.get_meta(META_IN_POOL, false)):
		return
	if not instance.has_meta(META_POOL_KEY):
		instance.queue_free()
		return
	instance.set_meta(META_IN_POOL, true)
	if instance.has_method(Types.METHOD_POOL_DESPAWNED):
		instance.call(Types.METHOD_POOL_DESPAWNED)
	# Hide now, detach at a safe point: removing collision objects inside a
	# physics callback is not allowed. Pooled scripts guard with is_in_pool().
	if instance is Node3D:
		(instance as Node3D).visible = false
	_detach.call_deferred(instance)


func is_in_pool(instance: Node) -> bool:
	return bool(instance.get_meta(META_IN_POOL, false))


## Instantiates [param count] instances ahead of time to avoid first-use hitches.
func prewarm(scene: PackedScene, count: int) -> void:
	var pool_key: String = scene.resource_path
	var idle_list: Array = _idle_instances.get(pool_key, [])
	for prewarm_index: int in count:
		var instance: Node = scene.instantiate()
		instance.set_meta(META_POOL_KEY, pool_key)
		instance.set_meta(META_IN_POOL, true)
		idle_list.append(instance)
	_idle_instances[pool_key] = idle_list


## Frees every pooled instance (called on scene changes).
func clear_all() -> void:
	for idle_list: Array in _idle_instances.values():
		for instance: Variant in idle_list:
			if is_instance_valid(instance):
				(instance as Node).queue_free()
	_idle_instances.clear()


func _exit_tree() -> void:
	# Idle instances live outside the tree, so free them explicitly on shutdown.
	for idle_list: Array in _idle_instances.values():
		for instance: Variant in idle_list:
			if is_instance_valid(instance):
				(instance as Node).free()
	_idle_instances.clear()
	PlaceholderMesh3D.clear_cache()
	TexturedBox3D.clear_cache()
	BlobShadow3D.clear_cache()
	# The town's generated window textures: freed before the renderer shuts down.
	TownMeshBuilder.clear_cache()
	TowerModelBuilder.clear_cache()


func get_idle_count() -> int:
	var total_idle: int = 0
	for idle_list: Array in _idle_instances.values():
		total_idle += idle_list.size()
	return total_idle


## Pops an idle instance of [param scene] (or creates one) and makes it visible.
func _take_instance(scene: PackedScene) -> Node:
	var pool_key: String = scene.resource_path
	var instance: Node = null
	var idle_list: Array = _idle_instances.get(pool_key, [])
	while instance == null and not idle_list.is_empty():
		var candidate: Variant = idle_list.pop_back()
		if is_instance_valid(candidate):
			instance = candidate as Node
	if instance == null:
		instance = scene.instantiate()
		instance.set_meta(META_POOL_KEY, pool_key)
	instance.set_meta(META_IN_POOL, false)
	if instance is Node3D:
		(instance as Node3D).visible = true
	return instance


func _detach(instance: Node) -> void:
	if not is_instance_valid(instance) or not is_in_pool(instance):
		return
	var parent: Node = instance.get_parent()
	if parent != null:
		parent.remove_child(instance)
	var pool_key: String = str(instance.get_meta(META_POOL_KEY))
	var idle_list: Array = _idle_instances.get(pool_key, [])
	idle_list.append(instance)
	_idle_instances[pool_key] = idle_list

## Stages a mid-game moment in the Porchlight level for screenshots: a planted
## lawn, attackers in every lane, sparks in the air and a blaster shot.
## Loaded by Tests/screenshot_tool.gd with `showcase=porchlight`.
##
## Dependencies: the Porchlight level (LevelBase, LaneBoard, XRPlayerRig)
extends RefCounted

const HUSK: PackedScene = preload("res://Scenes/Levels/Porchlight/Husk.tscn")
const DASHER: PackedScene = preload("res://Scenes/Levels/Porchlight/Dasher.tscn")
const BRUTE: PackedScene = preload("res://Scenes/Levels/Porchlight/Brute.tscn")
const WISP: PackedScene = preload("res://Scenes/Levels/Porchlight/Wisp.tscn")
const SEED_SPARKBLOOM: int = 0
const SEED_BOLTBLOOM: int = 1
const SEED_STONECAP: int = 2
## How far the first attackers have already walked (meters).
const HEAD_START: float = 5.2


static func apply(scene: Node) -> void:
	var level: Node = scene
	var board: LaneBoard = level.get("board") as LaneBoard
	level.call("add_sparks", 2000)
	var seed_board: SeedBoard = (level.get_node("%BoardScreen") as WorldScreen).content as SeedBoard
	for lane: int in board.lane_count:
		_plant(level, seed_board, SEED_SPARKBLOOM, Vector2i(lane, 0))
		_plant(level, seed_board, SEED_BOLTBLOOM, Vector2i(lane, 1))
	for lane: int in [1, 2, 3]:
		_plant(level, seed_board, SEED_BOLTBLOOM, Vector2i(lane, 2))
	for lane: int in [0, 2, 4]:
		_plant(level, seed_board, SEED_STONECAP, Vector2i(lane, 3))
	level.call("add_sparks", 175 - int(level.get("sparks")))
	level.call("select_seed", SEED_BOLTBLOOM)
	var scenes: Array[PackedScene] = [HUSK, HUSK, BRUTE, DASHER, HUSK, WISP, WISP, HUSK, HUSK, DASHER]
	for enemy_index: int in scenes.size():
		var enemy: LaneEnemy = board.spawn_enemy(scenes[enemy_index])
		enemy.global_position.z += HEAD_START - (enemy_index / 5) * 2.2 - (enemy_index % 3) * 0.5
	for spark_index: int in 3:
		board.drop_sky_spark(25, 2.0 + spark_index, 2.0 + spark_index)


## Plants through the level's own path, bypassing only the seed cooldown.
static func _plant(level: Node, seed_board: SeedBoard, seed_index: int, cell: Vector2i) -> void:
	level.call("select_seed", seed_index)
	(level.get("_seed_cooldowns") as Array).fill(0.0)
	level.call("try_plant", cell)
	seed_board.set_cooldown_ratio(seed_index, 0.0)

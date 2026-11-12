## The town around the house: a grid of streets with sidewalks, blocks of
## brick, plaster and glass buildings growing into downtown towers, parks
## and a plaza, street lamps and parked cars — and people walking it. The
## player can walk anywhere outside (streets, sidewalks, parks, alleys) and
## talk to anyone: point, pull the trigger, and a conversation panel appears
## next to them (voiced lines, the player's replies as buttons). Talk a
## passer-by into buying and they come to the back window.
##
## Built at load from TownData (TownLayout works out the town, TownMeshBuilder
## turns it into a few chunked meshes). Shared state goes through the
## operation only (referred buyers); fronts never call each other.
##
## Dependencies: HouseFront, TownData, TownLayout, TownMeshBuilder, Pedestrian,
##               DialogueRunner, DialogueBoard, WorldScreen, GroundPlane3D,
##               PropScatter3D, PlaceholderMesh3D, FloatingText3D, NpcVoice,
##               Pools, Profile, Coop autoloads, Palette
class_name Town
extends HouseFront

## A passer-by agreed to come and buy.
signal customer_referred(pedestrian: Pedestrian)

const PEDESTRIAN_SCENE: PackedScene = preload("res://Scenes/Levels/House/Town/Pedestrian.tscn")
## Seconds between checks for people far from the player.
const RECYCLE_CHECK_SECONDS: float = 1.0
## A recycled person reappears at a corner this far from the player (meters).
const RECYCLE_NEAR: float = 16.0
const RECYCLE_FAR: float = 42.0

## The street grid, blocks, buildings and people (Ressources/Town/town.tres).
@export var town_data: TownData

@export_group("Materials")
@export var brick_material: Material
@export var plaster_material: Material
@export var concrete_material: Material
@export var roof_material: Material
@export var sidewalk_material: Material
@export var asphalt_material: Material
@export var lawn_material: Material

@export_group("Park trees")
## Tree meshes (impostors) and their materials, used in turn for park trees.
@export var tree_meshes: Array[Mesh] = []
@export var tree_materials: Array[Material] = []

## The worked-out town (blocks, buildings, walkable floor, corners).
var layout: TownLayout = null

var _window_material: StandardMaterial3D = null
var _glow_material: StandardMaterial3D = null
var _pedestrians: Array[Pedestrian] = []
var _talk_partner: Pedestrian = null
var _runner: DialogueRunner = null
var _board: DialogueBoard = null
var _seconds_until_recycle: float = 0.0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_night_lit: bool = false

@onready var _visuals: Node3D = %Visuals
@onready var _people: Node3D = %People
@onready var _dialogue_screen: WorldScreen = %DialogueScreen


func _ready() -> void:
	_random.randomize()
	if town_data == null:
		return
	layout = TownLayout.build(town_data)
	_build_visuals()
	_dialogue_screen.set_active(false)

# ============================================
# FRONT HOOKS
# ============================================

func _on_setup() -> void:
	if layout == null:
		return
	_board = _dialogue_screen.content as DialogueBoard
	_board.reply_chosen.connect(choose_reply)
	var walkable: WalkableArea = context.rig.walkable_area
	if walkable != null:
		for region: Rect2 in layout.walkable_regions:
			walkable.add_region(region)
		walkable.add_rect_blockers(layout.building_footprints)
		walkable.add_rect_blockers(layout.car_blockers)
		walkable.add_blockers(layout.tree_blockers)
		walkable.add_blockers(layout.fountains)
	# A co-op guest's world stands still (the host runs it): no walkers there.
	if not Coop.is_client():
		_spawn_pedestrians()
	_apply_night_lights(context.day_cycle.is_night())


func _shift_process(delta: float) -> void:
	if _talk_partner != null:
		var feet: Vector3 = context.rig.get_feet_position()
		if feet.distance_to(_talk_partner.global_position) > town_data.talk_distance:
			end_talk()
	_seconds_until_recycle -= delta
	if _seconds_until_recycle <= 0.0:
		_seconds_until_recycle = RECYCLE_CHECK_SECONDS
		_recycle_far_pedestrians()


func _refresh_displays() -> void:
	_apply_night_lights(context.day_cycle.is_night())
	if _talk_partner != null:
		update_screen_rendering(_dialogue_screen)


func on_nightfall() -> void:
	_apply_night_lights(true)


func finish_shift(_result: LevelResult) -> void:
	end_talk()

# ============================================
# PUBLIC API
# ============================================

## Everyone walking the streets now.
func get_pedestrians() -> Array[Pedestrian]:
	return _pedestrians


## The person the player is talking to (null when nobody).
func get_talk_partner() -> Pedestrian:
	return _talk_partner


## The conversation panel (tests read its replies).
func get_dialogue_board() -> DialogueBoard:
	return _board


## The in-world screen the conversation panel is shown on.
func get_dialogue_screen() -> WorldScreen:
	return _dialogue_screen


## Starts a conversation with [param pedestrian]: they stop, face the
## player and say hello; the panel shows the player's replies.
func start_talk(pedestrian: Pedestrian) -> void:
	if pedestrian == null or pedestrian == _talk_partner or town_data.dialogue == null:
		return
	end_talk()
	_talk_partner = pedestrian
	pedestrian.begin_talk(context.rig.get_head_transform().origin)
	# Someone already asked today won't be talked into it twice.
	var chance: float = 0.0 if pedestrian.was_pitched else town_data.get_recruit_chance(Profile.operation.reputation)
	_runner = DialogueRunner.new(town_data.dialogue)
	_present(_runner.start(chance, _random))


## The player picks reply [param reply_index] on the panel.
func choose_reply(reply_index: int) -> void:
	if _runner == null:
		return
	_present(_runner.choose(reply_index))


## Ends the conversation: the panel goes away, the person walks on.
func end_talk() -> void:
	if _talk_partner != null:
		_talk_partner.end_talk()
	_talk_partner = null
	_runner = null
	_dialogue_screen.set_active(false)

# ============================================
# CONVERSATION
# ============================================

func _present(node: DialogueNodeData) -> void:
	if node == null or _talk_partner == null:
		end_talk()
		return
	var partner: Pedestrian = _talk_partner
	partner.voice.say(node.line_category, true)
	if node.line_category == VoiceLineData.PITCH_YES or node.line_category == VoiceLineData.PITCH_NO:
		partner.was_pitched = true
	if node.outcome == DialogueNodeData.Outcome.REFERRED_CUSTOMER:
		context.operation.refer_customer()
		FloatingText3D.spawn(tr("A buyer is on the way"), partner.global_position + Vector3(0.0, 2.3, 0.0), Palette.SUCCESS, Global.get_world_root())
		customer_referred.emit(partner)
	var line_text: String = partner.voice.current_line.text if partner.voice.current_line != null else ""
	var replies: PackedStringArray = PackedStringArray()
	for reply: DialogueReplyData in _runner.get_replies():
		replies.append(tr(reply.text))
	_board.show_step(partner.get_display_name(), line_text, replies)
	_place_dialogue_screen()
	if replies.is_empty():
		# A closing line ("Ciao Kakao!"): the talk ends once it is said.
		var runner: DialogueRunner = _runner
		if partner.voice.is_speaking():
			await partner.voice.line_finished
		if _runner == runner:
			end_talk()


## The panel stands beside the person, at chest height, turned to the player.
func _place_dialogue_screen() -> void:
	var head: Vector3 = context.rig.get_head_transform().origin
	var partner_position: Vector3 = _talk_partner.global_position
	var toward_player: Vector3 = Vector3(head.x - partner_position.x, 0.0, head.z - partner_position.z).normalized()
	var beside: Vector3 = Vector3(toward_player.z, 0.0, -toward_player.x)
	_dialogue_screen.global_position = partner_position + toward_player * 0.45 + beside * 0.65 + Vector3(0.0, 1.35, 0.0)
	_dialogue_screen.set_active(true)
	_dialogue_screen.look_at(Vector3(head.x, _dialogue_screen.global_position.y, head.z), Vector3.UP, true)
	_dialogue_screen.set_rendering(true)

# ============================================
# PEOPLE
# ============================================

func _spawn_pedestrians() -> void:
	if town_data.pedestrian_voices.is_empty() or layout.corners.is_empty():
		return
	var feet: Vector3 = context.rig.get_feet_position()
	for person_index: int in town_data.pedestrian_count:
		var corner: int = _pick_corner_near(Vector2(feet.x, feet.z), 8.0, RECYCLE_FAR * 1.4)
		var spot: Vector2 = layout.corners[corner]
		var pedestrian: Pedestrian = Pools.spawn(PEDESTRIAN_SCENE, _people, Vector3(spot.x, 0.0, spot.y)) as Pedestrian
		var voice: VoiceData = town_data.pedestrian_voices[_random.randi_range(0, town_data.pedestrian_voices.size() - 1)]
		pedestrian.setup(layout, corner, voice)
		if not pedestrian.talk_requested.is_connected(start_talk):
			pedestrian.talk_requested.connect(start_talk)
		_pedestrians.append(pedestrian)


## People far from the player reappear at a corner nearby (out of sight
## range is fine: the streets around the player never run empty).
func _recycle_far_pedestrians() -> void:
	var feet: Vector3 = context.rig.get_feet_position()
	var player_point: Vector2 = Vector2(feet.x, feet.z)
	for pedestrian: Pedestrian in _pedestrians:
		if pedestrian == _talk_partner:
			continue
		if Vector2(pedestrian.global_position.x, pedestrian.global_position.z).distance_to(player_point) > town_data.pedestrian_recycle_distance:
			pedestrian.place_at_corner(_pick_corner_near(player_point, RECYCLE_NEAR, RECYCLE_FAR))


## A random sidewalk corner between [param near] and [param far] meters from
## [param point] (the nearest corner when none is in that ring).
func _pick_corner_near(point: Vector2, near: float, far: float) -> int:
	var candidates: Array[int] = []
	for corner_index: int in layout.corners.size():
		var distance: float = layout.corners[corner_index].distance_to(point)
		if distance >= near and distance <= far:
			candidates.append(corner_index)
	if candidates.is_empty():
		return layout.get_nearest_corner(point)
	return candidates[_random.randi_range(0, candidates.size() - 1)]

# ============================================
# BUILDING THE TOWN
# ============================================

func _build_visuals() -> void:
	var materials: Array[Material] = [brick_material, plaster_material, concrete_material, roof_material, null, sidewalk_material, null, null]
	var builder: TownMeshBuilder = TownMeshBuilder.new(layout, town_data, materials)
	for chunk: ArrayMesh in builder.build_chunks():
		var chunk_instance: MeshInstance3D = MeshInstance3D.new()
		chunk_instance.mesh = chunk
		chunk_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visuals.add_child(chunk_instance)
	_window_material = builder.get_window_material()
	_glow_material = builder.get_glow_material()
	# The streets: one asphalt plane under the whole town and its outskirts.
	var asphalt: GroundPlane3D = GroundPlane3D.new()
	var ground: Rect2 = layout.bounds.grow(town_data.outskirts_depth)
	asphalt.size = ground.size
	asphalt.ground_material = asphalt_material
	asphalt.position = Vector3(ground.get_center().x, TownMeshBuilder.ASPHALT_TOP, ground.get_center().y)
	asphalt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(asphalt)
	for block_index: int in layout.blocks.size():
		var inner: Rect2 = layout.get_block_inner(layout.blocks[block_index])
		match layout.block_kinds[block_index]:
			TownLayout.BlockKind.PARK:
				_add_ground(inner, lawn_material, -0.03)
			TownLayout.BlockKind.PLAZA:
				_add_ground(inner, sidewalk_material, TownMeshBuilder.SIDEWALK_TOP)
	for fountain: Vector3 in layout.fountains:
		_add_fountain(fountain)
	_plant_trees()


func _add_ground(area: Rect2, material: Material, height: float) -> void:
	var patch: GroundPlane3D = GroundPlane3D.new()
	patch.size = area.size
	patch.ground_material = material
	patch.position = Vector3(area.get_center().x, height, area.get_center().y)
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(patch)


func _add_fountain(fountain: Vector3) -> void:
	var base: Vector3 = Vector3(fountain.x, 0.0, fountain.y)
	var radius: float = fountain.z
	_add_shape(base + Vector3(0.0, 0.3, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(radius * 2.0, 0.6, radius * 2.0), Palette.TEXT_FAINT, 0.0)
	_add_shape(base + Vector3(0.0, 0.58, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(radius * 1.8, 0.06, radius * 1.8), Palette.GEM.darkened(0.45), 0.25)
	_add_shape(base + Vector3(0.0, 1.1, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.5, 1.6, 0.5), Palette.TEXT_FAINT, 0.0)
	_add_shape(base + Vector3(0.0, 1.95, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(1.6, 0.14, 1.6), Palette.TEXT_FAINT, 0.0)


func _add_shape(at: Vector3, shape: PlaceholderMesh3D.ShapeKind, shape_size: Vector3, color: Color, glow: float) -> void:
	var part: PlaceholderMesh3D = PlaceholderMesh3D.new()
	part.shape_kind = shape
	part.size = shape_size
	part.color = color
	part.glow = glow
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.position = at
	_visuals.add_child(part)


## Park trees: one PropScatter3D (a single draw call) per tree kind.
func _plant_trees() -> void:
	if tree_meshes.is_empty() or layout.park_trees.is_empty():
		return
	var placements_by_kind: Array[Array] = []
	for kind_index: int in tree_meshes.size():
		placements_by_kind.append([])
	for tree_index: int in layout.park_trees.size():
		placements_by_kind[tree_index % tree_meshes.size()].append(layout.park_trees[tree_index])
	for kind_index: int in tree_meshes.size():
		var scatter: PropScatter3D = PropScatter3D.new()
		scatter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scatter.scatter_mesh = tree_meshes[kind_index]
		scatter.scatter_material = tree_materials[kind_index] if kind_index < tree_materials.size() else null
		var placements: Array[Vector4] = []
		placements.assign(placements_by_kind[kind_index])
		scatter.placements = placements
		_visuals.add_child(scatter)


## Windows light up and lamps glow at night.
func _apply_night_lights(is_night: bool) -> void:
	# The materials start in their daytime state.
	if _window_material == null or is_night == _is_night_lit:
		return
	_is_night_lit = is_night
	_window_material.emission_energy_multiplier = 1.1 if is_night else 0.0
	_glow_material.emission_energy_multiplier = 2.5 if is_night else 0.2

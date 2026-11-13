## The town around the house: its street grid, which blocks are parks or a
## plaza, how tall the buildings grow toward downtown, street furniture and
## the people walking its sidewalks. TownLayout turns this into buildings,
## sidewalks and walkable floor; the Town front builds and runs it.
##
## Blocks are counted between streets: block (column, row) lies between
## street_x[column] and street_x[column + 1] and street_z[row] and
## street_z[row + 1]. The house's own block keeps its garden and lawn.
##
## Dependencies: VoiceData, DialogueData
class_name TownData
extends Resource

@export_group("Streets")
## Centre lines (world X) of the streets running north-south, ascending.
@export var street_x: PackedFloat32Array = PackedFloat32Array([-259.0, -212.0, -165.0, -118.0, -71.0, -24.0, 24.0, 71.0, 118.0, 165.0, 212.0, 259.0])
## Centre lines (world Z) of the streets running east-west, ascending.
@export var street_z: PackedFloat32Array = PackedFloat32Array([-280.0, -231.0, -182.0, -133.0, -84.0, -35.0, 19.0, 68.0, 117.0, 166.0, 215.0, 264.0])
## Curb to curb (meters).
@export var street_width: float = 10.0
## Sidewalk along every block edge (meters).
@export var sidewalk_width: float = 3.0
## Depth of the ring of buildings beyond the outer streets that closes off
## the view (scenery: not walkable).
@export var outskirts_depth: float = 26.0

@export_group("Blocks")
## The block the house stands on (column, row).
@export var home_block: Vector2i = Vector2i(5, 5)
@export var park_blocks: Array[Vector2i] = [Vector2i(5, 4), Vector2i(3, 6), Vector2i(8, 2), Vector2i(1, 8), Vector2i(9, 8)]
@export var plaza_blocks: Array[Vector2i] = [Vector2i(5, 6), Vector2i(8, 5)]
## The house's walls (world X / Z): the town's floor stops here, the house's
## own rooms take over.
@export var house_footprint: Rect2 = Rect2(-5.3, -5.3, 10.6, 10.6)

@export_group("Buildings")
@export var layout_seed: int = 7
## Buildings grow taller toward this point (world X / Z)...
@export var downtown_center: Vector2 = Vector2(165.0, -180.0)
## ...within this distance (meters).
@export var downtown_radius: float = 160.0
## Height range (meters) of ordinary buildings and of downtown towers.
@export var low_height: Vector2 = Vector2(7.0, 15.0)
@export var high_height: Vector2 = Vector2(24.0, 58.0)
## The industrial quarter: low, wide halls and warehouses within
## industrial_radius of industrial_center (world X / Z).
@export var industrial_center: Vector2 = Vector2(-190.0, 190.0)
@export var industrial_radius: float = 110.0
@export var industrial_height: Vector2 = Vector2(6.0, 11.0)
## Width of the alleys between neighbouring buildings (walkable).
@export var alley_width: float = 1.4
## Narrowest building front (meters).
@export var min_lot_width: float = 10.0
## Blocks deeper than this are split into a front and a back row of buildings.
@export var two_row_depth: float = 26.0

@export_group("Street furniture")
## Meters between street lamps along a sidewalk.
@export var lamp_spacing: float = 18.0
## Meters between parking spots along a curb, and the chance a spot is taken.
@export var parking_spacing: float = 6.5
@export var parked_car_chance: float = 0.4
## Trees per 100 m² of park lawn.
@export var park_tree_density: float = 0.55

@export_group("People")
## People walking the sidewalks at once.
@export var pedestrian_count: int = 12
## Voices the people in the street speak with (one picked per person).
@export var pedestrian_voices: Array[VoiceData] = []
## What the player can talk about with them.
@export var dialogue: DialogueData
## Chance a pitched passer-by agrees to come and buy, plus a bonus per point
## of reputation, capped.
@export var recruit_chance: float = 0.45
@export var recruit_chance_per_reputation: float = 0.003
@export var max_recruit_chance: float = 0.85
## The player must stay this close (meters) for a conversation to go on.
@export var talk_distance: float = 4.0
## People farther than this from the player (meters) move to a corner near
## them, so the streets around the player never run empty.
@export var pedestrian_recycle_distance: float = 65.0


## The chance a pitched passer-by says yes at [param reputation].
func get_recruit_chance(reputation: float) -> float:
	return minf(max_recruit_chance, recruit_chance + reputation * recruit_chance_per_reputation)

## One stage of the house: its walls, doors, windows, floor and where the
## player can walk inside. HouseStages hands it to the HouseShell (which
## rebuilds) and the player's WalkableArea when the house grows — from the
## one-room cabin to the full house.
##
## Dependencies: none
class_name HouseLayout
extends Resource

## Shown in the docs and tests ("Cabin", "House").
@export var stage_name: String = ""
## Wall segments (x1, z1, x2, z2) on the floor plane; axis-aligned.
@export var walls: Array[Vector4] = []
## Door gaps (x1, z1, x2, z2) on a wall line.
@export var doors: Array[Vector4] = []
## Window gaps (x1, z1, x2, z2) on a wall line.
@export var windows: Array[Vector4] = []
## Interior floor (and roof) rectangle: position = (min x, min z).
@export var floor_rect: Rect2 = Rect2(-5.0, -5.0, 10.0, 10.0)
## Openings in the floor (the cellar's stairwell).
@export var floor_openings: Array[Rect2] = []
## Where the player can walk inside (world X / Z).
@export var walk_regions: Array[Rect2] = []

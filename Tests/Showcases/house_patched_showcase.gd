## Stages the house half way: every renovation and look upgrade at level 1
## (patched walls, new floor boards, repointed bricks, patched roof, the
## first door straps, the steel door frame, real stash shelves).
## Loaded by Tests/screenshot_tool.gd with `showcase=house_patched`.
##
## Dependencies: house_renovated_showcase.gd
extends RefCounted

const RENOVATED_SHOWCASE: GDScript = preload("res://Tests/Showcases/house_renovated_showcase.gd")


static func apply(scene: Node) -> void:
	RENOVATED_SHOWCASE.apply_levels(scene, 1)

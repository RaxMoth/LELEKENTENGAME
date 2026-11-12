## Unit tests for the town around the house: TownLayout (blocks, buildings,
## walkable floor, sidewalk corners).
##
## Dependencies: gdUnit4
extends GdUnitTestSuite


func _layout() -> TownLayout:
	return TownLayout.build(TownData.new())


func test_the_same_seed_builds_the_same_town() -> void:
	var first: TownLayout = _layout()
	var second: TownLayout = _layout()
	assert_int(first.building_footprints.size()).is_greater(40)
	assert_int(second.building_footprints.size()).is_equal(first.building_footprints.size())
	assert_bool(first.building_footprints[10] == second.building_footprints[10]).is_true()


func test_buildings_stay_off_streets_and_the_home_block() -> void:
	var data: TownData = TownData.new()
	var layout: TownLayout = TownLayout.build(data)
	var home: Rect2 = layout.get_block(data.home_block)
	assert_bool(home.has_area()).is_true()
	for footprint: Rect2 in layout.building_footprints:
		assert_bool(footprint.intersects(home)).is_false()
		# Every building sits inside a block (or the outskirts beyond the streets).
		var inside_block: bool = false
		for block: Rect2 in layout.blocks:
			if block.encloses(footprint):
				inside_block = true
		assert_bool(inside_block).is_true()
		for street_x: float in data.street_x:
			assert_bool(footprint.position.x < street_x + data.street_width * 0.5 and footprint.end.x > street_x - data.street_width * 0.5 and layout.bounds.intersects(footprint)).is_false()


func test_downtown_is_taller_than_the_suburbs() -> void:
	var data: TownData = TownData.new()
	var layout: TownLayout = TownLayout.build(data)
	var downtown_tallest: float = 0.0
	var suburb_tallest: float = 0.0
	for building_index: int in layout.building_footprints.size():
		var distance: float = layout.building_footprints[building_index].get_center().distance_to(data.downtown_center)
		if distance < 40.0:
			downtown_tallest = maxf(downtown_tallest, layout.building_heights[building_index])
		elif distance > data.downtown_radius:
			suburb_tallest = maxf(suburb_tallest, layout.building_heights[building_index])
	assert_float(downtown_tallest).is_greater(suburb_tallest)


func test_the_town_is_walkable_but_not_through_walls() -> void:
	var data: TownData = TownData.new()
	var layout: TownLayout = TownLayout.build(data)
	var blockers: Array[Rect2] = layout.building_footprints.duplicate()
	blockers.append_array(layout.car_blockers)
	# A street crossing far from the house.
	var crossing: Vector2 = Vector2(data.street_x[1], data.street_z[4])
	assert_bool(WalkableArea.contains_point(layout.walkable_regions, crossing, [], blockers)).is_true()
	assert_bool(WalkableArea.contains_point(layout.walkable_regions, layout.building_footprints[0].get_center(), [], blockers)).is_false()
	# The house's walls: its own rooms decide, not the town.
	assert_bool(WalkableArea.contains_point(layout.walkable_regions, Vector2(0.0, 0.0))).is_false()
	assert_bool(WalkableArea.contains_point(layout.walkable_regions, Vector2(0.0, -8.0))).is_true()
	# Beyond the outer streets the town ends.
	assert_bool(WalkableArea.contains_point(layout.walkable_regions, Vector2(0.0, layout.bounds.position.y - 2.0))).is_false()


func test_sidewalk_corners_lead_around_blocks_and_across_streets() -> void:
	var data: TownData = TownData.new()
	var layout: TownLayout = TownLayout.build(data)
	assert_int(layout.corners.size()).is_equal(layout.corner_links.size())
	var blockers: Array[Rect2] = layout.building_footprints.duplicate()
	var crosses_a_street: bool = false
	for corner_index: int in layout.corners.size():
		assert_int(layout.corner_links[corner_index].size()).is_greater_equal(2)
		assert_bool(WalkableArea.contains_point(layout.walkable_regions, layout.corners[corner_index], [], blockers)).is_true()
		for next_index: int in layout.corner_links[corner_index]:
			if layout.corners[corner_index].distance_to(layout.corners[next_index]) < data.street_width + data.sidewalk_width + 0.1:
				crosses_a_street = true
	assert_bool(crosses_a_street).is_true()


func test_recruiting_gets_easier_with_reputation_up_to_a_cap() -> void:
	var data: TownData = TownData.new()
	assert_float(data.get_recruit_chance(0.0)).is_equal_approx(data.recruit_chance, 0.0001)
	assert_float(data.get_recruit_chance(50.0)).is_greater(data.get_recruit_chance(0.0))
	assert_float(data.get_recruit_chance(100000.0)).is_equal_approx(data.max_recruit_chance, 0.0001)

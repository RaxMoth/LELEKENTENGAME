## IngredientLook: pieces are hand-sized, one mesh each; heaps stay in their container.
extends GdUnitTestSuite

const STYLES: Array[IngredientData.PieceStyle] = [IngredientData.PieceStyle.MUSHROOM, IngredientData.PieceStyle.ROOT, IngredientData.PieceStyle.LEAF, IngredientData.PieceStyle.CRYSTAL]


func after_test() -> void:
	IngredientLook.clear_cache()


func test_every_piece_is_one_hand_sized_mesh_on_its_base() -> void:
	for style: IngredientData.PieceStyle in STYLES:
		for is_powder: bool in [false, true]:
			var piece: ArrayMesh = IngredientLook.get_piece_mesh(style, Color.GREEN, is_powder)
			var bounds: AABB = piece.get_aabb()
			assert_int(piece.get_surface_count()).is_equal(1)
			assert_float(bounds.size.y).is_between(0.02, 0.15)
			assert_float(maxf(bounds.size.x, bounds.size.z)).is_less(0.22)
			assert_float(bounds.position.y).is_greater_equal(-0.02)


func test_pieces_are_cached_per_look() -> void:
	var first: ArrayMesh = IngredientLook.get_piece_mesh(IngredientData.PieceStyle.ROOT, Color.CYAN, false)
	assert_object(IngredientLook.get_piece_mesh(IngredientData.PieceStyle.ROOT, Color.CYAN, false)).is_same(first)
	assert_object(IngredientLook.get_piece_mesh(IngredientData.PieceStyle.ROOT, Color.CYAN, true)).is_not_same(first)


func test_a_heap_stays_inside_its_container() -> void:
	var area: Vector2 = Vector2(0.44, 0.34)
	for style: IngredientData.PieceStyle in STYLES:
		var bounds: AABB = IngredientLook.build_heap_mesh(style, Color.WHITE, area, false, 5).get_aabb()
		assert_float(bounds.size.x).is_less_equal(area.x + 0.02)
		assert_float(bounds.size.z).is_less_equal(area.y + 0.02)
		assert_float(bounds.end.y).is_less(0.2)

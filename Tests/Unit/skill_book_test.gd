## Unit tests for SkillBook (skills grow by doing) and HolsterRules (which
## weapon hangs where on the body).
##
## Dependencies: gdUnit4, SkillBook, SkillTuning, HolsterRules, WeaponCatalog, WeaponLoadout, WeaponData
extends GdUnitTestSuite


func _tuning() -> SkillTuning:
	var tuning: SkillTuning = SkillTuning.new()
	tuning.level_thresholds = PackedFloat32Array([5.0, 15.0])
	return tuning


func test_experience_raises_the_level_at_each_threshold() -> void:
	var tuning: SkillTuning = _tuning()
	var book: SkillBook = SkillBook.new()
	assert_int(book.get_level(SkillBook.Skill.CRAFTING, tuning)).is_equal(0)
	assert_int(book.add_xp(SkillBook.Skill.CRAFTING, 4.0, tuning)).is_equal(-1)
	assert_float(book.get_progress(SkillBook.Skill.CRAFTING, tuning)).is_equal_approx(0.8, 0.001)
	assert_int(book.add_xp(SkillBook.Skill.CRAFTING, 1.0, tuning)).is_equal(1)
	assert_int(book.add_xp(SkillBook.Skill.CRAFTING, 50.0, tuning)).is_equal(2)
	assert_bool(book.is_maxed(SkillBook.Skill.CRAFTING, tuning)).is_true()
	assert_float(book.get_progress(SkillBook.Skill.CRAFTING, tuning)).is_equal(1.0)
	# Other skills are untouched; nothing negative counts.
	assert_int(book.get_level(SkillBook.Skill.FIGHTING, tuning)).is_equal(0)
	assert_int(book.add_xp(SkillBook.Skill.FIGHTING, -3.0, tuning)).is_equal(-1)


func test_skills_survive_a_save() -> void:
	var tuning: SkillTuning = _tuning()
	var book: SkillBook = SkillBook.new()
	book.add_xp(SkillBook.Skill.HARVESTING, 7.5, tuning)
	var restored: SkillBook = SkillBook.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(book.to_dict())))
	assert_float(restored.get_xp(SkillBook.Skill.HARVESTING)).is_equal_approx(7.5, 0.001)
	assert_int(restored.get_level(SkillBook.Skill.HARVESTING, tuning)).is_equal(1)
	restored.from_dict({"9": 100.0, "1": -4.0})
	assert_float(restored.get_xp(SkillBook.Skill.FIGHTING)).is_equal(0.0)


func _weapon(weapon_id: StringName, cost: int, slot: StringName) -> WeaponData:
	var weapon: WeaponData = WeaponData.new()
	weapon.id = weapon_id
	weapon.cost = cost
	weapon.holster_slot = slot
	weapon.has_unlimited_ammo = true
	return weapon


func test_owned_weapons_hang_in_their_slots() -> void:
	var catalog: WeaponCatalog = WeaponCatalog.new()
	catalog.weapons = [_weapon(&"fists", 0, &""), _weapon(&"knife", 60, &"hip"), _weapon(&"axe", 160, &"back"), _weapon(&"pistol", 200, &"chest"), _weapon(&"rifle", 800, &"chest")]
	var loadout: WeaponLoadout = WeaponLoadout.new()
	assert_dict(HolsterRules.assign(catalog, loadout)).is_empty()
	loadout.buy_weapon(catalog.find_weapon(&"knife"))
	loadout.buy_weapon(catalog.find_weapon(&"pistol"))
	var holstered: Dictionary[StringName, WeaponData] = HolsterRules.assign(catalog, loadout)
	assert_str(String(holstered[&"hip"].id)).is_equal("knife")
	assert_str(String(holstered[&"chest"].id)).is_equal("pistol")
	assert_bool(holstered.has(&"back")).is_false()
	# The strongest gun goes on the chest — unless another one is equipped.
	loadout.buy_weapon(catalog.find_weapon(&"rifle"))
	assert_str(String(HolsterRules.assign(catalog, loadout)[&"chest"].id)).is_equal("rifle")
	loadout.equip(catalog.find_weapon(&"pistol"))
	assert_str(String(HolsterRules.assign(catalog, loadout)[&"chest"].id)).is_equal("pistol")

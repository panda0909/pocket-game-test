extends GutTest

func test_first_wave_is_only_basic_bears() -> void:
	var comp := WaveTable.composition(1)
	for kind in comp:
		assert_eq(kind, WaveTable.EnemyKind.BEAR, "第一波只該有基本熊")

func test_small_bears_appear_from_wave_two() -> void:
	assert_false(WaveTable.composition(1).has(WaveTable.EnemyKind.SMALL_BEAR))
	assert_true(WaveTable.composition(2).has(WaveTable.EnemyKind.SMALL_BEAR))

func test_medium_bears_appear_from_wave_three() -> void:
	assert_false(WaveTable.composition(2).has(WaveTable.EnemyKind.MEDIUM_BEAR))
	assert_true(WaveTable.composition(3).has(WaveTable.EnemyKind.MEDIUM_BEAR))

func test_big_bears_appear_from_wave_four() -> void:
	assert_false(WaveTable.composition(3).has(WaveTable.EnemyKind.BIG_BEAR))
	assert_true(WaveTable.composition(4).has(WaveTable.EnemyKind.BIG_BEAR))

func test_scary_bears_appear_from_wave_six() -> void:
	assert_false(WaveTable.composition(5).has(WaveTable.EnemyKind.SCARY_BEAR))
	assert_true(WaveTable.composition(6).has(WaveTable.EnemyKind.SCARY_BEAR))

func test_zombie_bears_appear_from_wave_eight() -> void:
	assert_false(WaveTable.composition(7).has(WaveTable.EnemyKind.ZOMBIE_BEAR))
	assert_true(WaveTable.composition(8).has(WaveTable.EnemyKind.ZOMBIE_BEAR))

func test_bats_appear_from_wave_twenty() -> void:
	assert_false(WaveTable.composition(19).has(WaveTable.EnemyKind.BAT))
	assert_true(WaveTable.composition(20).has(WaveTable.EnemyKind.BAT))
	assert_true(WaveTable.is_airborne(WaveTable.EnemyKind.BAT))
	assert_false(WaveTable.is_airborne(WaveTable.EnemyKind.BEAR))

func test_boss_appears_every_five_waves() -> void:
	assert_false(WaveTable.composition(4).has(WaveTable.EnemyKind.BOSS_BEAR))
	assert_true(WaveTable.composition(5).has(WaveTable.EnemyKind.BOSS_BEAR))
	assert_true(WaveTable.composition(10).has(WaveTable.EnemyKind.BOSS_BEAR))

func test_only_one_boss_per_wave() -> void:
	var count := 0
	for kind in WaveTable.composition(10):
		if kind == WaveTable.EnemyKind.BOSS_BEAR:
			count += 1
	assert_eq(count, 1)

func test_wave_size_grows_but_is_capped() -> void:
	assert_lt(WaveTable.composition(1).size(), WaveTable.composition(8).size())
	# 沒有上限的話後期一波會塞進上百隻，畫面與效能都會爆掉
	assert_lt(WaveTable.composition(99).size(), 40)

func test_hp_grows_with_wave() -> void:
	var w1 := WaveTable.hp_for(WaveTable.EnemyKind.BEAR, 1)
	var w2 := WaveTable.hp_for(WaveTable.EnemyKind.BEAR, 2)
	assert_almost_eq(w1, float(WaveTable.BASE[WaveTable.EnemyKind.BEAR]["hp"]), 0.001)
	# 斷言關係而不是寫死數字：成長率是調參旋鈕，寫死的話每次微調
	# 都要跟著改測試，測試就退化成常數的複寫。
	assert_almost_eq(w2 / w1, WaveTable.HP_GROWTH, 0.001)

func test_hp_growth_is_gentle_enough_for_long_runs() -> void:
	# 1.28 的成長讓第 10 波就變成高牆。要打到三位數波次，
	# 曲線必須平緩得多，難度才由「玩家追不追得上」而不是「幾波就爆」決定。
	assert_lt(WaveTable.HP_GROWTH, 1.2)
	assert_gt(WaveTable.HP_GROWTH, 1.0, "還是要成長，否則後期毫無壓力")

func test_wave_fits_in_the_wave_timer() -> void:
	# 波次時間到就推進。一波的敵人數若超過生成間隔塞得下的量，
	# 未生成的部分會被下一波蓋掉，等於白做。
	var max_spawnable := int(20.0 / 0.5)
	assert_lte(WaveTable.composition(999).size(), max_spawnable)

func test_boss_steals_more_lives() -> void:
	assert_eq(WaveTable.steal_for(WaveTable.EnemyKind.BEAR), 1)
	assert_eq(WaveTable.steal_for(WaveTable.EnemyKind.BOSS_BEAR), 3)

func test_small_bear_is_fastest() -> void:
	var small_bear := WaveTable.speed_for(WaveTable.EnemyKind.SMALL_BEAR)
	for kind in [WaveTable.EnemyKind.BEAR, WaveTable.EnemyKind.MEDIUM_BEAR,
			WaveTable.EnemyKind.BIG_BEAR, WaveTable.EnemyKind.SCARY_BEAR,
			WaveTable.EnemyKind.ZOMBIE_BEAR, WaveTable.EnemyKind.BOSS_BEAR]:
		assert_gt(small_bear, WaveTable.speed_for(kind))

func test_texture_paths_exist() -> void:
	for kind in [WaveTable.EnemyKind.BEAR, WaveTable.EnemyKind.SMALL_BEAR,
			WaveTable.EnemyKind.MEDIUM_BEAR, WaveTable.EnemyKind.BIG_BEAR,
			WaveTable.EnemyKind.SCARY_BEAR, WaveTable.EnemyKind.ZOMBIE_BEAR,
			WaveTable.EnemyKind.BOSS_BEAR]:
		var path := WaveTable.texture_path(kind)
		assert_true(ResourceLoader.exists(path), "找不到貼圖 %s" % path)
	var bat_path := WaveTable.texture_path(WaveTable.EnemyKind.BAT)
	assert_true(ResourceLoader.exists(bat_path), "找不到蝙蝠貼圖 %s" % bat_path)

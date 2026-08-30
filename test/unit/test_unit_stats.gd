extends GutTest

func test_tier_one_damage_matches_base() -> void:
	# 一階傷害就是設定表上的基礎值，沒有任何倍率
	for kind in range(UnitStats.BASE_KIND_FIRST, UnitStats.BASE_KIND_LAST + 1):
		assert_almost_eq(UnitStats.damage(kind, 1),
			float(UnitStats.BASE[kind]["damage"]), 0.001)

func test_bull_hits_hardest_gecko_fires_fastest() -> void:
	# 三種守衛的定位差異：紅牛單體重擊、橘壁虎連射。
	# 這個關係壞掉的話種類就只剩換皮。
	assert_gt(UnitStats.damage(UnitStats.Kind.BULL, 1),
		UnitStats.damage(UnitStats.Kind.GECKO, 1))
	assert_lt(UnitStats.attack_interval(UnitStats.Kind.GECKO),
		UnitStats.attack_interval(UnitStats.Kind.BULL))

func test_each_tier_multiplies_damage() -> void:
	var t1 := UnitStats.damage(UnitStats.Kind.BULL, 1)
	var t2 := UnitStats.damage(UnitStats.Kind.BULL, 2)
	# 斷言關係而不是寫死倍率：那是調參旋鈕，寫死會讓測試退化成常數複寫
	assert_almost_eq(t2 / t1, UnitStats.TIER_DAMAGE_MULTIPLIER, 0.001)

func test_max_tier_damage_beats_two_of_previous_tier() -> void:
	# 合成消耗兩隻低階換一隻高階。若倍率不大於 2，合成就只是把兩格併成
	# 一格而沒有變強，玩家沒有動機合成——這個測試守住這個設計前提。
	for tier in range(1, UnitStats.MAX_TIER):
		var lower := UnitStats.damage(UnitStats.Kind.DINO, tier)
		var higher := UnitStats.damage(UnitStats.Kind.DINO, tier + 1)
		assert_gt(higher, lower * 2.0, "第 %d 階合成後應強於兩隻低階相加" % tier)

func test_max_tier_is_deep_enough_for_long_runs() -> void:
	# 階級深度直接決定數字能長到多大。較淺的階級頂多讓傷害到四位數，
	# 撐不起打到三位數波次時該有的量級。
	assert_gte(UnitStats.MAX_TIER, 12)
	assert_gt(UnitStats.damage(UnitStats.Kind.BULL, UnitStats.MAX_TIER), 100000.0,
		"滿階單次傷害應該進到六位數")

func test_range_grows_with_tier() -> void:
	var base := UnitStats.attack_range(UnitStats.Kind.BULL, 1)
	assert_almost_eq(base, 340.0, 0.001)
	assert_almost_eq(UnitStats.attack_range(UnitStats.Kind.BULL, 3), base + 24.0, 0.001)

func test_attack_interval_does_not_change_with_tier() -> void:
	assert_almost_eq(UnitStats.attack_interval(UnitStats.Kind.GECKO), 0.35, 0.001)

func test_roles_have_different_range_damage_and_speed() -> void:
	assert_eq(UnitStats.splash_radius(UnitStats.Kind.BULL), 0.0)
	assert_eq(UnitStats.splash_radius(UnitStats.Kind.GECKO), 0.0)
	assert_almost_eq(UnitStats.splash_radius(UnitStats.Kind.DINO), 70.0, 0.001)
	assert_ne(UnitStats.attack_range(UnitStats.Kind.FOX, 1),
		UnitStats.attack_range(UnitStats.Kind.RHINO, 1))
	assert_ne(UnitStats.damage(UnitStats.Kind.RABBIT, 1),
		UnitStats.damage(UnitStats.Kind.RHINO, 1))
	assert_ne(UnitStats.attack_interval(UnitStats.Kind.RABBIT),
		UnitStats.attack_interval(UnitStats.Kind.FOX))
	assert_gt(UnitStats.splash_radius(UnitStats.Kind.RHINO),
		UnitStats.splash_radius(UnitStats.Kind.DINO))

func test_attack_visual_changes_with_tier() -> void:
	assert_ne(UnitStats.attack_tint(UnitStats.Kind.BULL, 1),
		UnitStats.attack_tint(UnitStats.Kind.BULL, 2))
	assert_gt(UnitStats.attack_scale_multiplier(UnitStats.Kind.BULL, 6),
		UnitStats.attack_scale_multiplier(UnitStats.Kind.BULL, 1))

func test_texture_paths_exist() -> void:
	for kind in range(UnitStats.BASE_KIND_FIRST, UnitStats.Kind.BULL_MARKET_PLANE + 1):
		var path := UnitStats.texture_path(kind)
		assert_true(ResourceLoader.exists(path), "找不到貼圖 %s" % path)
		var attack_path := UnitStats.attack_texture_path(kind)
		assert_true(ResourceLoader.exists(attack_path), "找不到攻擊貼圖 %s" % attack_path)
		if UnitStats.is_fusion(kind):
			assert_eq(UnitStats.tier_texture_path(kind), "")
		elif UnitStats.tier_texture_path(kind).is_empty():
			# 新職業採單張透明角色稿，階級由尺寸、角標與攻擊能量色呈現。
			assert_true(ResourceLoader.exists(path), "找不到新職業待機貼圖 %s" % path)
		else:
			var tier_path := UnitStats.tier_texture_path(kind)
			assert_true(ResourceLoader.exists(tier_path), "找不到階級貼圖 %s" % tier_path)

func test_fusion_roles_have_distinct_attack_profiles() -> void:
	assert_true(UnitStats.is_fusion(UnitStats.Kind.DUO_SHOOTER))
	assert_true(UnitStats.is_fusion(UnitStats.Kind.MARKET_TANK))
	assert_true(UnitStats.is_fusion(UnitStats.Kind.BULL_MARKET_PLANE))
	assert_gt(UnitStats.splash_radius(UnitStats.Kind.MARKET_TANK),
		UnitStats.splash_radius(UnitStats.Kind.DUO_SHOOTER))
	assert_lt(UnitStats.attack_interval(UnitStats.Kind.DUO_SHOOTER),
		UnitStats.attack_interval(UnitStats.Kind.MARKET_TANK))

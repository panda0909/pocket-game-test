extends GutTest

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_same_tier_can_merge() -> void:
	assert_true(MergeRules.can_merge(1, 1))
	assert_true(MergeRules.can_merge(6, 6))

func test_different_tier_cannot_merge() -> void:
	assert_false(MergeRules.can_merge(1, 2))

func test_max_tier_cannot_merge() -> void:
	assert_false(MergeRules.can_merge(UnitStats.MAX_TIER, UnitStats.MAX_TIER),
		"滿階已是上限，不應再做一般合成")

func test_final_pairs_produce_fusions() -> void:
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.GECKO,
		UnitStats.MAX_TIER, UnitStats.MAX_TIER), UnitStats.Kind.DUO_SHOOTER)
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.DINO,
		UnitStats.MAX_TIER, UnitStats.MAX_TIER), UnitStats.Kind.MARKET_TANK)
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.GECKO, UnitStats.Kind.DINO,
		UnitStats.MAX_TIER, UnitStats.MAX_TIER), UnitStats.Kind.BULL_MARKET_PLANE)

func test_fusion_requires_final_tier_and_different_kinds() -> void:
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.GECKO,
		UnitStats.MAX_TIER - 1, UnitStats.MAX_TIER), -1)
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.BULL,
		UnitStats.MAX_TIER, UnitStats.MAX_TIER), -1)
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.GECKO,
		UnitStats.MAX_TIER, UnitStats.MAX_TIER - 1), -1)

func test_merge_raises_tier_by_one() -> void:
	var result := MergeRules.merge_result(3, _rng(1))
	assert_eq(result["tier"], 4)

func test_merge_kind_is_one_of_three() -> void:
	for seed_value in range(30):
		var result := MergeRules.merge_result(1, _rng(seed_value))
		assert_between(result["kind"], UnitStats.Kind.BULL, UnitStats.Kind.DINO,
			"一般合成種類必須落在三種基礎守衛之內")

func test_same_seed_gives_same_result() -> void:
	# 亂數可注入是刻意的設計。沒有這個性質，所有牽涉合成的測試
	# 都會變成間歇性失敗。
	var a := MergeRules.merge_result(2, _rng(42))
	var b := MergeRules.merge_result(2, _rng(42))
	assert_eq(a["kind"], b["kind"])

func test_kind_actually_varies_across_seeds() -> void:
	# 反過來守住「不是永遠回傳同一種」——隨機性壞掉時上面那個測試抓不到
	var seen := {}
	for seed_value in range(50):
		seen[MergeRules.merge_result(1, _rng(seed_value))["kind"]] = true
	assert_gt(seen.size(), 1, "不同種子應該產生不同種類")

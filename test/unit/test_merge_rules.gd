extends GutTest

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_same_kind_same_tier_can_merge() -> void:
	assert_true(MergeRules.can_merge(UnitStats.Kind.BULL, UnitStats.Kind.BULL, 1, 1))
	assert_true(MergeRules.can_merge(UnitStats.Kind.OCTOPUS, UnitStats.Kind.OCTOPUS, 6, 6))

func test_different_kind_cannot_merge_before_fusion_unlock() -> void:
	assert_false(MergeRules.can_merge(UnitStats.Kind.BULL, UnitStats.Kind.GECKO, 1, 1))
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.GECKO, 5, 5), -1)
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.GECKO, 6, 6),
		UnitStats.Kind.DUO_SHOOTER)

func test_max_tier_cannot_merge() -> void:
	assert_false(MergeRules.can_merge(UnitStats.Kind.BULL, UnitStats.Kind.BULL,
		UnitStats.MAX_TIER, UnitStats.MAX_TIER),
		"滿階已是上限，不應再做一般合成")

func test_final_pairs_produce_fusions() -> void:
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.GECKO,
		UnitStats.MAX_TIER, UnitStats.MAX_TIER), UnitStats.Kind.DUO_SHOOTER)
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.DINO,
		UnitStats.MAX_TIER, UnitStats.MAX_TIER), UnitStats.Kind.MARKET_TANK)
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.GECKO, UnitStats.Kind.DINO,
		UnitStats.MAX_TIER, UnitStats.MAX_TIER), UnitStats.Kind.BULL_MARKET_PLANE)

func test_fusion_requires_same_unlocked_tier_and_different_kinds() -> void:
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.GECKO,
		UnitStats.FUSION_UNLOCK_TIER - 1, UnitStats.FUSION_UNLOCK_TIER - 1), -1)
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.BULL,
		UnitStats.FUSION_UNLOCK_TIER, UnitStats.FUSION_UNLOCK_TIER), -1)
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.BULL, UnitStats.Kind.GECKO,
		UnitStats.FUSION_UNLOCK_TIER, UnitStats.FUSION_UNLOCK_TIER - 1), -1)
	assert_eq(MergeRules.fusion_kind_for(UnitStats.Kind.DUO_SHOOTER, UnitStats.Kind.BULL,
		UnitStats.FUSION_UNLOCK_TIER, UnitStats.FUSION_UNLOCK_TIER), -1)

func test_merge_raises_tier_by_one() -> void:
	var result := MergeRules.merge_result(UnitStats.Kind.BULL, 3, _rng(1))
	assert_eq(result["tier"], 4)
	assert_eq(result["kind"], UnitStats.Kind.BULL)

func test_fusion_allows_new_roles_after_unlock() -> void:
	var fusion := MergeRules.fusion_kind_for(UnitStats.Kind.FOX, UnitStats.Kind.OWL,
		UnitStats.FUSION_UNLOCK_TIER, UnitStats.FUSION_UNLOCK_TIER)
	assert_true(UnitStats.is_fusion(fusion), "六階以上的異職業應該產生融合角色")

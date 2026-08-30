class_name MergeRules
extends RefCounted

## 合成規則。低階合成保持職業一致，高階才開放跨職業融合，
## 讓玩家先經營角色，再把成形的配置轉成特殊融合角色。


static func can_merge(kind_a: int, kind_b: int, tier_a: int, tier_b: int) -> bool:
	## 一至五階只能把同職業、同階角色合成，避免低階隨機召喚讓配置失去意義。
	return kind_a == kind_b \
		and not UnitStats.is_fusion(kind_a) \
		and tier_a == tier_b \
		and tier_a < UnitStats.MAX_TIER


## 六階以上的不同角色才可融合成新角色。保留三個招牌融合角色，
## 新職業也能依固定規則接入，不需要為每一對職業另外製作 28 套素材。
static func fusion_kind_for(kind_a: int, kind_b: int, tier_a: int, tier_b: int) -> int:
	if tier_a != tier_b \
		or tier_a < UnitStats.FUSION_UNLOCK_TIER \
		or kind_a == kind_b \
		or UnitStats.is_fusion(kind_a) \
		or UnitStats.is_fusion(kind_b):
		return -1
	var pair := [mini(kind_a, kind_b), maxi(kind_a, kind_b)]
	if pair == [UnitStats.Kind.BULL, UnitStats.Kind.GECKO]:
		return UnitStats.Kind.DUO_SHOOTER
	if pair == [UnitStats.Kind.BULL, UnitStats.Kind.DINO]:
		return UnitStats.Kind.MARKET_TANK
	if pair == [UnitStats.Kind.GECKO, UnitStats.Kind.DINO]:
		return UnitStats.Kind.BULL_MARKET_PLANE
	# 其餘新職業組合使用固定輪替，結果可預期且每一對都能產生新角色。
	return [
		UnitStats.Kind.DUO_SHOOTER,
		UnitStats.Kind.MARKET_TANK,
		UnitStats.Kind.BULL_MARKET_PLANE,
	][(kind_a * 7 + kind_b * 3) % 3]


## 回傳 {"tier": 新階級, "kind": 新種類}。
## 保留 rng 參數以相容既有呼叫端；目前同職業合成不再隨機換職業。
static func merge_result(kind: int, tier: int, _rng: RandomNumberGenerator = null) -> Dictionary:
	return {
		"tier": tier + 1,
		"kind": kind,
	}

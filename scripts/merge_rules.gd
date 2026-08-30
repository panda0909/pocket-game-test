class_name MergeRules
extends RefCounted

## 合成規則。種類隨機是參考作品樂趣的來源：玩家得一邊應對手上拿到的牌、
## 一邊規劃防線。可預測的合成會讓遊戲退化成單純的數值累積。


static func can_merge(tier_a: int, tier_b: int) -> bool:
	return tier_a == tier_b and tier_a < UnitStats.MAX_TIER


## 最終階的不同角色不走隨機合成，而是依組合變成專用融合角色。
## 回傳 -1 代表不是融合組合，讓一般同階合成維持原本的隨機性。
static func fusion_kind_for(kind_a: int, kind_b: int, tier_a: int, tier_b: int) -> int:
	if tier_a != UnitStats.MAX_TIER or tier_b != UnitStats.MAX_TIER or kind_a == kind_b:
		return -1
	var pair := [mini(kind_a, kind_b), maxi(kind_a, kind_b)]
	if pair == [UnitStats.Kind.BULL, UnitStats.Kind.GECKO]:
		return UnitStats.Kind.DUO_SHOOTER
	if pair == [UnitStats.Kind.BULL, UnitStats.Kind.DINO]:
		return UnitStats.Kind.MARKET_TANK
	if pair == [UnitStats.Kind.GECKO, UnitStats.Kind.DINO]:
		return UnitStats.Kind.BULL_MARKET_PLANE
	return -1


## 回傳 {"tier": 新階級, "kind": 新種類}。
## rng 由呼叫端傳入，測試給固定種子就能穩定重現。
static func merge_result(tier: int, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"tier": tier + 1,
		"kind": rng.randi_range(UnitStats.Kind.BULL, UnitStats.Kind.DINO),
	}

class_name UnitStats
extends RefCounted

## 守衛的數值表。不繼承 Node，測試不必建立場景樹。

enum Kind {
	BULL,
	GECKO,
	DINO,
	FOX,
	RABBIT,
	OWL,
	RHINO,
	OCTOPUS,
	DUO_SHOOTER,
	MARKET_TANK,
	BULL_MARKET_PLANE,
}

const FUSION_KINDS := [Kind.DUO_SHOOTER, Kind.MARKET_TANK, Kind.BULL_MARKET_PLANE]
const BASE_KIND_FIRST := Kind.BULL
const BASE_KIND_LAST := Kind.OCTOPUS
## 六階開始才允許不同職業融合，避免低階隨機召喚破壞配置策略。
const FUSION_UNLOCK_TIER := 6

## 階級深度決定數字能長到多大。7 階的傷害頂多四位數，撐不起打到
## 三位數波次時該有的量級；12 階讓滿階單次傷害進到六位數。
const MAX_TIER := 12
## 每升一階的傷害倍率。必須大於 2：合成要消耗兩隻低階，倍率若只有 2，
## 合成就只是把兩格併成一格而沒有變強。3.4 是模型掃出來的值——
## 配合 1.09 的敵人生命成長，能讓一局走到第 107 波左右。
const TIER_DAMAGE_MULTIPLIER := 3.4
## 階級變多了，每階的射程加成要跟著調小，否則滿階單位射程會蓋滿全場，
## 位置就完全不重要了。
const RANGE_PER_TIER := 12.0

## 基礎傷害刻意放大（原本 12/4/7 的 25 倍）。這是純粹的數字通膨：
## 傷害與敵人生命同步放大，平衡完全不變，但畫面上跳出來的數字會從
## 五位數變成六七位數。這個類型的滿足感有很大一部分來自看著位數變長。
const BASE := {
	Kind.BULL: {
		"damage": 300.0, "interval": 1.2, "range": 340.0, "splash": 0.0,
		"texture": "res://assets/characters/red_bull.png",
		"attack_texture": "res://assets/characters/red_bull_attack.png",
		"tier_texture": "res://assets/characters/tiers/red_bull_tiers.png",
	},
	Kind.GECKO: {
		"damage": 100.0, "interval": 0.35, "range": 320.0, "splash": 0.0,
		"texture": "res://assets/characters/gecko.png",
		"attack_texture": "res://assets/characters/gecko_attack.png",
		"tier_texture": "res://assets/characters/tiers/gecko_tiers.png",
	},
	Kind.DINO: {
		"damage": 175.0, "interval": 1.0, "range": 330.0, "splash": 70.0,
		"texture": "res://assets/characters/dino.png",
		"attack_texture": "res://assets/characters/dino_attack.png",
		"tier_texture": "res://assets/characters/tiers/dino_tiers.png",
	},
	Kind.FOX: {
		"damage": 240.0, "interval": 1.45, "range": 520.0, "splash": 0.0,
		"texture": "res://assets/characters/new/trend_fox.png",
		"attack_texture": "res://assets/characters/new/trend_fox_attack.png",
		"tier_texture": "",
	},
	Kind.RABBIT: {
		"damage": 85.0, "interval": 0.22, "range": 300.0, "splash": 0.0,
		"texture": "res://assets/characters/new/quant_rabbit.png",
		"attack_texture": "res://assets/characters/new/quant_rabbit_attack.png",
		"tier_texture": "",
	},
	Kind.OWL: {
		"damage": 160.0, "interval": 0.8, "range": 600.0, "splash": 25.0,
		"texture": "res://assets/characters/new/radar_owl.png",
		"attack_texture": "res://assets/characters/new/radar_owl_attack.png",
		"tier_texture": "",
	},
	Kind.RHINO: {
		"damage": 420.0, "interval": 1.8, "range": 280.0, "splash": 150.0,
		"texture": "res://assets/characters/new/turret_rhino.png",
		"attack_texture": "res://assets/characters/new/turret_rhino_attack.png",
		"tier_texture": "",
	},
	Kind.OCTOPUS: {
		"damage": 140.0, "interval": 0.55, "range": 360.0, "splash": 95.0,
		"texture": "res://assets/characters/new/arbitrage_octopus.png",
		"attack_texture": "res://assets/characters/new/arbitrage_octopus_attack.png",
		"tier_texture": "",
	},
	Kind.DUO_SHOOTER: {
		"damage": 460.0, "interval": 0.38, "range": 360.0, "splash": 0.0,
		"texture": "res://assets/characters/fusion_duo_shooter.png",
		"attack_texture": "res://assets/characters/fusion_duo_shooter_attack.png",
		"tier_texture": "",
	},
	Kind.MARKET_TANK: {
		"damage": 850.0, "interval": 1.05, "range": 350.0, "splash": 110.0,
		"texture": "res://assets/characters/fusion_market_tank.png",
		"attack_texture": "res://assets/characters/fusion_market_tank_attack.png",
		"tier_texture": "",
	},
	Kind.BULL_MARKET_PLANE: {
		"damage": 550.0, "interval": 0.7, "range": 390.0, "splash": 75.0,
		"texture": "res://assets/characters/fusion_bull_market_plane.png",
		"attack_texture": "res://assets/characters/fusion_bull_market_plane_attack.png",
		"tier_texture": "",
	},
}


static func damage(kind: int, tier: int) -> float:
	return float(BASE[kind]["damage"]) * pow(TIER_DAMAGE_MULTIPLIER, tier - 1)


## 攻擊間隔只由種類決定，不隨階級改變——升階加傷害不加攻速，
## 這樣三個種類的定位差異在後期才不會被抹平。
static func attack_interval(kind: int) -> float:
	return float(BASE[kind]["interval"])


static func attack_range(kind: int, tier: int) -> float:
	return float(BASE[kind]["range"]) + RANGE_PER_TIER * (tier - 1)


static func splash_radius(kind: int) -> float:
	return float(BASE[kind]["splash"])


static func texture_path(kind: int) -> String:
	return String(BASE[kind]["texture"])


static func tier_texture_path(kind: int) -> String:
	return String(BASE[kind]["tier_texture"])


static func attack_texture_path(kind: int) -> String:
	return String(BASE[kind]["attack_texture"])


## 同一張攻擊稿在不同階級會有不同的市場能量色與尺寸脈衝，
## 讓玩家能在攻擊瞬間讀出階級差異，而不是所有等級都像複製貼上。
static func attack_tint(kind: int, tier: int) -> Color:
	var base := TierPalette.color_for(tier)
	var role_shift: Color = [
		Color(1.0, 0.92, 0.86), Color(0.86, 1.0, 0.92), Color(0.88, 0.94, 1.0),
		Color(1.0, 0.90, 0.72), Color(0.92, 0.84, 1.0), Color(0.78, 1.0, 0.98),
		Color(1.0, 0.82, 0.82), Color(0.90, 1.0, 0.80),
	][kind % 8]
	return Color(
		minf(base.r * role_shift.r * 1.25, 1.0),
		minf(base.g * role_shift.g * 1.25, 1.0),
		minf(base.b * role_shift.b * 1.25, 1.0),
		1.0
	)


static func attack_scale_multiplier(kind: int, tier: int) -> float:
	return 1.0 + minf(float(tier - 1), 11.0) * 0.018


static func is_fusion(kind: int) -> bool:
	return kind >= Kind.DUO_SHOOTER


static func display_name(kind: int) -> String:
	return [
		"紅牛", "橘壁虎", "綠恐龍", "趨勢狐", "量化兔", "雷達貓頭鷹",
		"砲台犀牛", "套利章魚", "雙人連擊", "市場戰車", "牛市飛機",
	][kind]


static func ex_name(kind: int) -> String:
	return [
		"牛市重砲", "閃電追價", "多空爆破", "趨勢狙擊", "量化連射", "雷達掃描",
		"犀牛砲擊", "套利潮汐", "雙人連擊", "戰車突襲", "牛市空襲",
	][kind]


static func combat_effect_kind(kind: int) -> int:
	# 攻擊特效圖集只有三種守衛效果，融合角色沿用最接近的攻擊語言。
	match kind:
		Kind.BULL, Kind.MARKET_TANK:
			return Kind.BULL
		Kind.GECKO, Kind.RABBIT, Kind.DUO_SHOOTER:
			return Kind.GECKO
		Kind.FOX, Kind.OWL:
			return Kind.GECKO
		Kind.RHINO, Kind.OCTOPUS:
			return Kind.DINO
		_:
			return Kind.DINO

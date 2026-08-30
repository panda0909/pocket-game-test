class_name WaveTable
extends RefCounted

## 每一波的熊市入侵者組成與數值。無限波次，難度靠生命值指數成長推進。

enum EnemyKind {
	BEAR,
	SMALL_BEAR,
	MEDIUM_BEAR,
	BIG_BEAR,
	SCARY_BEAR,
	ZOMBIE_BEAR,
	BOSS_BEAR,
	BAT,
}

## 玩家的戰力大約隨波次的 1.38 次方成長（多項式），敵人生命是指數，
## 指數終究會超車——交叉點就是死亡波次。要讓交叉落在三位數波次，
## 1.075 配合 3.4 倍率與「棋盤保持滿載」的玩法：模型預估死亡落在
## 第 124 波、平均佔格 34/36。1.28 會讓第 10 波就變成高牆。
const HP_GROWTH := 1.075

## 單波敵人總數上限。沒有上限的話後期一波會塞進上百隻，
## 畫面看不清楚、效能也會被拖垮。
## 上限也受波次計時器限制：一波 20 秒、生成間隔 0.5 秒，最多塞得下
## 40 隻。超出的部分會被下一波蓋掉，等於白做。
const MAX_BEARS := 11
const MAX_SMALL_BEARS := 8
const MAX_MEDIUM_BEARS := 6
const MAX_BIG_BEARS := 4
const MAX_SCARY_BEARS := 4
const MAX_ZOMBIE_BEARS := 3
const MAX_BATS := 3
const BAT_START_WAVE := 20

## 基礎生命有兩層放大：與守衛傷害同步的 25 倍（純數字通膨，平衡不受
## 影響），再乘 2.5 倍調整早期節奏。
##
## 第二層是實測後加的：原本第一波只用掉玩家 13% 的傷害預算，敵人一
## 出場就被秒殺，畫面上幾乎看不到人。拉到 32% 之後敵人存活時間變成
## 2.5 倍，看得見了。這裡有一道很陡的懸崖——壓力超過 0.6 時前幾波
## 清不掉，漏怪會複利，模型顯示會從第 124 波直接崩到第 9 波。
const BASE := {
	EnemyKind.BEAR: {
		"hp": 1875.0, "speed": 60.0, "steal": 1,
		"texture": "res://assets/generated/stock_bear_enemy_sheet.png",
	},
	EnemyKind.SMALL_BEAR: {
		"hp": 1125.0, "speed": 110.0, "steal": 1,
		"texture": "res://assets/generated/stock_bear_enemy_sheet.png",
	},
	EnemyKind.MEDIUM_BEAR: {
		"hp": 3000.0, "speed": 72.0, "steal": 1,
		"texture": "res://assets/generated/stock_bear_enemy_sheet.png",
	},
	EnemyKind.BIG_BEAR: {
		"hp": 5625.0, "speed": 40.0, "steal": 1,
		"texture": "res://assets/generated/stock_bear_enemy_sheet.png",
	},
	EnemyKind.SCARY_BEAR: {
		"hp": 9000.0, "speed": 48.0, "steal": 2,
		"texture": "res://assets/generated/stock_bear_enemy_sheet.png",
	},
	EnemyKind.ZOMBIE_BEAR: {
		"hp": 13000.0, "speed": 30.0, "steal": 2,
		"texture": "res://assets/generated/stock_bear_enemy_sheet.png",
	},
	EnemyKind.BOSS_BEAR: {
		"hp": 25000.0, "speed": 45.0, "steal": 3,
		"texture": "res://assets/generated/stock_bear_enemy_sheet.png",
	},
	EnemyKind.BAT: {
		"hp": 4800.0, "speed": 118.0, "steal": 2,
		"texture": "res://assets/generated/stock_bat_enemy.png",
	},
}


static func hp_for(kind: int, wave: int) -> float:
	return float(BASE[kind]["hp"]) * pow(HP_GROWTH, wave - 1)


static func speed_for(kind: int) -> float:
	return float(BASE[kind]["speed"])


static func steal_for(kind: int) -> int:
	return int(BASE[kind]["steal"])


static func texture_path(kind: int) -> String:
	return String(BASE[kind]["texture"])


static func uses_sheet(kind: int) -> bool:
	return kind != EnemyKind.BAT


static func is_airborne(kind: int) -> bool:
	return kind == EnemyKind.BAT


## 這一波要出的熊市敵人清單，依序生成。
static func composition(wave: int) -> Array:
	var result := []
	for i in mini(3 + wave, MAX_BEARS):
		result.append(EnemyKind.BEAR)
	if wave >= 2:
		for i in mini(1 + wave / 2, MAX_SMALL_BEARS):
			result.append(EnemyKind.SMALL_BEAR)
	if wave >= 3:
		for i in mini(wave / 3, MAX_MEDIUM_BEARS):
			result.append(EnemyKind.MEDIUM_BEAR)
	if wave >= 4:
		for i in mini(wave / 4, MAX_BIG_BEARS):
			result.append(EnemyKind.BIG_BEAR)
	if wave >= 6:
		for i in mini(wave / 6, MAX_SCARY_BEARS):
			result.append(EnemyKind.SCARY_BEAR)
	if wave >= 8:
		for i in mini(wave / 8, MAX_ZOMBIE_BEARS):
			result.append(EnemyKind.ZOMBIE_BEAR)
	if wave >= BAT_START_WAVE:
		for i in mini(1 + (wave - BAT_START_WAVE) / 4, MAX_BATS):
			result.append(EnemyKind.BAT)
	if wave % 5 == 0:
		result.append(EnemyKind.BOSS_BEAR)
	return result

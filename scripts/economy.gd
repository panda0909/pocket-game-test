class_name Economy
extends RefCounted

## 資金、生命與召喚費用。整個遊戲的難度旋鈕都集中在這裡，
## 試玩後要調手感只需要動這個檔案。

const STARTING_GOLD := 120
const STARTING_LIVES := 20

## 召喚費用的模型：基準隨「波次」等比成長，另外在「同一波之內」
## 每多召喚一次就加成一次。
##
## 這個拆法是實測後改的。舊版是 20 + 4×累計召喚數且永不重置，買 N 隻的
## 總花費是 2N² 的二次成長，而收入只是等比——玩家中期就再也買不起，
## 階級永遠推不上去，模擬跑到第 17 波就結束而且一次都沒合成。
## 改成基準跟著波次走之後，收入與支出同步成長，每一波能買的隻數大致
## 穩定；波內遞增保留「不能在單一波無限刷」的節制，真正的上限交給
## 16 格的棋盤空間。
##
## 數值是模型掃出來的：1.02 的基準成長遠低於收入的 1.05～1.06，
## 所以後期每一波買得起的隻數會越來越多，玩家得在有限格子裡持續合成，
## 並把高階單位放到中央匯流點附近。若成長率設得太高（例如 1.05），
## 棋盤會只剩幾隻高階單位，位置策略就會消失。
const SUMMON_BASE_COST := 20.0
const SUMMON_WAVE_GROWTH := 1.02
const SUMMON_WITHIN_WAVE_STEP := 0.05
## 清倉返還部分投入成本，讓滿盤又沒有可合成組合時仍能繼續遊玩。
const SALVAGE_REFUND_RATE := 0.60

## 獎勵同樣等比成長，成長率略高於召喚基準，玩家才感覺得到「越來越有錢」。
const KILL_REWARD_BASE := 2.0
const KILL_REWARD_GROWTH := 1.05
const WAVE_REWARD_BASE := 15.0
const WAVE_REWARD_GROWTH := 1.06

var gold: int = STARTING_GOLD
var lives: int = STARTING_LIVES
var summons_done: int = 0

var _wave := 1
var _summons_this_wave := 0


func reset() -> void:
	gold = STARTING_GOLD
	lives = STARTING_LIVES
	summons_done = 0
	_wave = 1
	_summons_this_wave = 0


## 進入新的一波：費用基準往上跳一階，波內的加成歸零。
func set_wave(wave: int) -> void:
	_wave = maxi(1, wave)
	_summons_this_wave = 0


func summon_cost() -> int:
	var base: float = SUMMON_BASE_COST * pow(SUMMON_WAVE_GROWTH, _wave - 1)
	return maxi(1, roundi(base * (1.0 + SUMMON_WITHIN_WAVE_STEP * _summons_this_wave)))


func can_afford_summon() -> bool:
	return gold >= summon_cost()


## 回收價用「同階合成投入」估算，不受當前波次召喚加價影響，避免高波次
## 只因誤召喚就能刷出過高退款；階級越高仍會得到合理的部位價值。
static func salvage_refund(tier: int) -> int:
	var safe_tier := maxi(1, tier)
	return maxi(1, roundi(SUMMON_BASE_COST * pow(2.0, safe_tier - 1) * SALVAGE_REFUND_RATE))


func pay_summon() -> void:
	gold -= summon_cost()
	summons_done += 1
	_summons_this_wave += 1


func add_gold(amount: int) -> void:
	gold += amount


func lose_lives(amount: int) -> void:
	lives = maxi(0, lives - amount)


func is_defeated() -> bool:
	return lives <= 0


static func kill_reward(wave: int) -> int:
	return maxi(2, roundi(KILL_REWARD_BASE * pow(KILL_REWARD_GROWTH, wave - 1)))


static func wave_reward(wave: int) -> int:
	return maxi(15, roundi(WAVE_REWARD_BASE * pow(WAVE_REWARD_GROWTH, wave - 1)))

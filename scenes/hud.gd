extends CanvasLayer

## 畫面上的文字與按鈕。放在 CanvasLayer 底下才不會跟著遊戲場景縮放。

signal start_game
signal summon_requested
signal speed_toggled
signal ex_requested

const RESTART_DELAY := 1.0

@onready var _stats_label: Label = $StatsLabel
## 大字，只用於標題與結束畫面（畫面中央，會蓋住棋盤）
@onready var _message: Label = $Message
## 細長橫幅，用於遊戲中的波次提示。位置在棋盤上方，不會擋住守衛。
@onready var _wave_banner: Label = $WaveBanner
@onready var _best_label: Label = $BestLabel
@onready var _start_button: Button = $StartButton
@onready var _summon_button: Button = $SummonButton
@onready var _speed_button: Button = $SpeedButton
@onready var _ex_button: Button = $ExButton
@onready var _battle_icons: Array[Control] = [
	$WaveIcon, $LifeIcon, $CoinIcon, $MissionIcon, $SpeedIcon
]


func _ready() -> void:
	_start_button.pressed.connect(func(): start_game.emit())
	_summon_button.pressed.connect(func(): summon_requested.emit())
	_speed_button.pressed.connect(func(): speed_toggled.emit())
	_ex_button.pressed.connect(func(): ex_requested.emit())


func show_title(best_wave: int) -> void:
	_set_battle_icons_visible(false)
	_wave_banner.hide()
	_message.text = "口袋股市守衛\n熊市來襲"
	_message.show()
	_best_label.text = "最高波次 %d" % best_wave
	_best_label.show()
	_start_button.text = "開始"
	_start_button.show()
	_stats_label.hide()
	_summon_button.hide()
	_speed_button.hide()
	_ex_button.hide()


func hide_title() -> void:
	_set_battle_icons_visible(true)
	_message.hide()
	_best_label.hide()
	_start_button.hide()
	_stats_label.show()
	_summon_button.show()
	_speed_button.show()
	_ex_button.show()


## 失血時讓狀態列閃紅，配合金庫震動一起提醒玩家
func flash_damage() -> void:
	_stats_label.modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(_stats_label, "modulate", Color.WHITE, 0.45)


## 波次與倒數放同一行、生命與資金放第二行，是照參考作品的資訊層級：
## 「現在第幾波、還剩多久」是每一秒都要看的，資源是偶爾看的。
func update_stats(wave: int, lives: int, gold: int, seconds_left: float) -> void:
	var total := int(ceil(seconds_left))
	_stats_label.text = "波次 %d　　%02d:%02d\n生命 %d　　資金 %d" % [
		wave, total / 60, total % 60, lives, gold]


func update_speed_button(multiplier: float) -> void:
	_speed_button.text = "×%d" % int(multiplier)


func update_summon_button(cost: int, affordable: bool) -> void:
	_summon_button.text = "買入守衛 · %d 資金" % cost
	_summon_button.disabled = not affordable


func update_ex_button(seconds_left: float, has_units: bool) -> void:
	if seconds_left <= 0.0:
		_ex_button.text = "EX 技能"
		_ex_button.disabled = not has_units
	else:
		_ex_button.text = "EX %02d" % int(ceil(seconds_left))
		_ex_button.disabled = true


## 遊戲中的提示走橫幅，不用中央大字——大字會蓋住棋盤上的守衛。
func show_message(text: String) -> void:
	_wave_banner.text = text
	_wave_banner.show()


func hide_message() -> void:
	_wave_banner.hide()


func show_game_over(wave: int, best_wave: int, is_record: bool) -> void:
	_set_battle_icons_visible(false)
	_wave_banner.hide()
	if is_record:
		_message.text = "新紀錄！\n撐到第 %d 波" % wave
	else:
		_message.text = "金庫失守\n撐到第 %d 波" % wave
	_message.show()
	_best_label.text = "最高波次 %d" % best_wave
	_best_label.show()
	_stats_label.hide()
	_summon_button.hide()
	_speed_button.hide()
	_ex_button.hide()
	# 等一秒再顯示按鈕，避免玩家手還在點就誤觸重來
	await get_tree().create_timer(RESTART_DELAY).timeout
	_start_button.text = "再玩一次"
	_start_button.show()


func _set_battle_icons_visible(value: bool) -> void:
	for icon in _battle_icons:
		icon.visible = value

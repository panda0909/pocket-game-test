extends Node2D

## 浮動傷害數字：往上飄、往旁邊帶一點、淡出後自我銷毀。
##
## 數字直接顯示完整位數而不縮寫成 K／M。這類遊戲的滿足感有很大一部分
## 來自「看著位數變長」，縮寫等於把這個回饋拿掉。

const RISE := 58.0
const LIFETIME := 0.75
## 左右飄移的隨機幅度。全部直上直下的話，同時出現幾個會疊成一團看不清。
const DRIFT := 18.0

var _elapsed := 0.0
var _start := Vector2.ZERO
var _drift := 0.0

@onready var _label: Label = $Label


func setup(amount: float, color: Color) -> void:
	_start = position
	_drift = randf_range(-DRIFT, DRIFT)
	# 傷害再小也至少顯示 1，跳出 0 會讓玩家以為沒打中
	_label.text = str(maxi(1, roundi(amount)))
	_label.modulate = color


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	var t := _elapsed / LIFETIME
	# 先快後慢地上升，像被打飛出來
	position = Vector2(
		_start.x + _drift * t,
		_start.y - RISE * (1.0 - pow(1.0 - t, 2.0))
	)
	# 後段才開始淡出，前段維持清晰才讀得到數字
	modulate.a = 1.0 - pow(t, 2.2)

extends Node2D

## 爆散特效：一圈光點向外擴散並淡出，播完自我銷毀。
##
## 自繪而不用 CPUParticles2D，是為了不必額外準備粒子貼圖，外觀也完全由
## 程式決定，跟專案其他美術一致。
##
## 這裡的亂數直接用全域 randf——它只影響視覺，不影響任何遊戲規則，
## 不需要像 MergeRules 那樣做成可注入重現。

const MIN_SPEED := 0.55
const MAX_SPEED := 1.0
## 角度抖動幅度。完全平均分佈會看起來像規則的星形，反而不自然。
const ANGLE_JITTER := 0.28
const RING_WIDTH := 6.0
## 光點的深色描邊，用來在淺色背景上拉出對比
const RIM_COLOR := Color(0.18, 0.16, 0.20)
const RIM_WIDTH := 2.0

var _color := Color.WHITE
var _radius := 46.0
var _dot_size := 6.0
var _lifetime := 0.45

var _elapsed := 0.0
var _dirs: Array = []
var _speeds: Array = []


func setup(color: Color, count: int = 10, radius: float = 46.0,
		dot_size: float = 6.0, lifetime: float = 0.45) -> void:
	_color = color
	_radius = radius
	_dot_size = dot_size
	_lifetime = lifetime
	_dirs.clear()
	_speeds.clear()
	var base := randf() * TAU
	for i in count:
		var angle := base + TAU * i / count + randf_range(-ANGLE_JITTER, ANGLE_JITTER)
		_dirs.append(Vector2.RIGHT.rotated(angle))
		_speeds.append(randf_range(MIN_SPEED, MAX_SPEED))
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / _lifetime, 0.0, 1.0)
	# 先快後慢，看起來像被彈出去而不是等速飄開
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var alpha := 1.0 - t

	# 擴散環。單靠光點在淺色背景上對比不足，加一圈環才讀得出是「衝擊」。
	draw_arc(
		Vector2.ZERO,
		_radius * (0.3 + 0.9 * eased),
		0.0, TAU, 32,
		Color(_color.r, _color.g, _color.b, alpha * 0.8),
		RING_WIDTH * (1.0 - t * 0.55),
		true
	)

	for i in _dirs.size():
		var offset: Vector2 = _dirs[i] * _radius * float(_speeds[i]) * eased
		var size := _dot_size * (1.0 - t * 0.55)
		# 先描一圈深色再填色。淺色背景配淺色特效會糊掉，描邊是最省的解法。
		draw_circle(offset, size + RIM_WIDTH, Color(RIM_COLOR.r, RIM_COLOR.g, RIM_COLOR.b, alpha * 0.55))
		draw_circle(offset, size, Color(_color.r, _color.g, _color.b, alpha))

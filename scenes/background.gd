extends Node2D

## 背景：垂直漸層加柔和暗角。
##
## 用 _draw 畫而不是鋪一張 ColorRect，有兩個好處：解析度改變時不會糊掉，
## 而且 Node2D 完全不參與 GUI 事件——原本的 ColorRect 是 Control，
## 預設 mouse_filter 為 STOP，會把整片畫面的滑鼠事件吃掉導致拖曳失效，
## 得記得手動設成 IGNORE。改用 Node2D 就沒有這個陷阱。

const TOP_COLOR := Color(0.055, 0.075, 0.145)
const BOTTOM_COLOR := Color(0.16, 0.095, 0.14)
const BANDS := 64

const VIGNETTE_COLOR := Color(0.02, 0.03, 0.08)
const VIGNETTE_STEPS := 16
const VIGNETTE_STEP_INSET := 7.0
const VIGNETTE_MAX_ALPHA := 0.18


func _draw() -> void:
	var size := get_viewport_rect().size
	_draw_gradient(size)
	_draw_arena(size)
	_draw_vignette(size)


func _draw_arena(size: Vector2) -> void:
	var arena := Rect2(26.0, 220.0, size.x - 52.0, 830.0)
	draw_style_box(_arena_style(Color(0.075, 0.13, 0.18, 0.96), Color(0.22, 0.80, 0.72, 0.32), 3), arena)
	var inner := arena.grow(-12.0)
	draw_rect(inner, Color(0.12, 0.18, 0.18, 0.34), true)
	for y in range(260, 1020, 80):
		draw_line(Vector2(42, y), Vector2(size.x - 42, y), Color(1, 0.72, 0.35, 0.045), 1.0)


func _arena_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(24)
	return style


func _draw_gradient(size: Vector2) -> void:
	var band_height := size.y / BANDS
	for i in BANDS:
		var t := float(i) / float(BANDS - 1)
		# 多畫一像素，避免相鄰色帶之間出現接縫
		draw_rect(
			Rect2(0.0, i * band_height, size.x, band_height + 1.0),
			TOP_COLOR.lerp(BOTTOM_COLOR, t)
		)


## 由外向內疊多層低透明度邊框，做出柔和的收邊。
func _draw_vignette(size: Vector2) -> void:
	for i in VIGNETTE_STEPS:
		var inset := i * VIGNETTE_STEP_INSET
		var alpha := VIGNETTE_MAX_ALPHA * float(VIGNETTE_STEPS - i) / float(VIGNETTE_STEPS)
		draw_rect(
			Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0),
			Color(VIGNETTE_COLOR.r, VIGNETTE_COLOR.g, VIGNETTE_COLOR.b, alpha),
			false,
			VIGNETTE_STEP_INSET + 1.0
		)

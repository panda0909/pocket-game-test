extends Node2D

## EX 技能的盤面特效。用上漲箭頭、K 線柱與多空色帶區分技能類型，
## 不依賴額外圖片，方便每個融合角色也共享同一套技能框架。

const LIFETIME := 0.72
const MAX_RADIUS := 118.0

var _kind := UnitStats.Kind.BULL
var _color := Color(0.98, 0.78, 0.20)
var _elapsed := 0.0


func setup(kind: int, color: Color) -> void:
	_kind = kind
	_color = color
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / LIFETIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var alpha := 1.0 - t
	var radius := 18.0 + MAX_RADIUS * eased
	var accent := Color(0.20, 0.95, 0.46) if _kind != UnitStats.Kind.MARKET_TANK else Color(1.0, 0.56, 0.18)

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40,
		Color(accent.r, accent.g, accent.b, alpha * 0.75), 5.0, true)
	draw_arc(Vector2.ZERO, radius * 0.72, -PI * 0.72, PI * 0.72, 40,
		Color(_color.r, _color.g, _color.b, alpha * 0.8), 3.0, true)

	var spokes := 8 if _kind == UnitStats.Kind.BULL_MARKET_PLANE else 6
	for i in spokes:
		var angle := TAU * float(i) / float(spokes) + eased * 0.8
		var direction := Vector2.RIGHT.rotated(angle)
		var start := direction * (radius * 0.32)
		var end := direction * (radius * 0.92)
		draw_line(start, end, Color(accent.r, accent.g, accent.b, alpha * 0.65), 4.0, true)
		_draw_arrow(end, direction, Color(accent.r, accent.g, accent.b, alpha))

	if _kind == UnitStats.Kind.MARKET_TANK:
		for i in 3:
			var x := -32.0 + i * 32.0
			var height := 26.0 + 35.0 * eased * float(i + 1) / 3.0
			draw_rect(Rect2(x, -height, 16.0, height),
				Color(_color.r, _color.g, _color.b, alpha * 0.8), true)


func _draw_arrow(tip: Vector2, direction: Vector2, color: Color) -> void:
	var side := direction.orthogonal() * 7.0
	var back := tip - direction * 15.0
	draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), color)

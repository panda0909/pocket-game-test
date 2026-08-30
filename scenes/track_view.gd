extends Path2D

## 把 T 型軌道畫出來。Path2D 只在編輯器裡看得見，執行時不會自己繪製——
## 少了這段，玩家看不出左右入口與中央匯流的關係。

const TRACK_WIDTH := 48.0
const EDGE_WIDTH := 14.0
const TRACK_COLOR := Color(0.78, 0.62, 0.36)
const EDGE_COLOR := Color(0.18, 0.12, 0.20)
const CENTER_COLOR := Color(0.98, 0.78, 0.30, 0.55)
const START_COLOR := Color(0.28, 0.88, 0.78)

@export var draw_track := true
@export var route_color := TRACK_COLOR
@export var start_color := START_COLOR


func _draw() -> void:
	if not draw_track:
		return
	var points := curve.get_baked_points()
	if points.size() < 2:
		return
	draw_polyline(points, EDGE_COLOR, TRACK_WIDTH + EDGE_WIDTH)
	draw_polyline(points, route_color, TRACK_WIDTH)
	draw_polyline(points, CENTER_COLOR, 3.0)
	# 起點標示，讓玩家知道熊市從哪裡進場
	draw_circle(points[0], 20.0, start_color)
	draw_arc(points[0], 20.0, 0.0, TAU, 24, Color(0.20, 0.20, 0.24), 4.0, true)
	# 左右入口在中央交叉點匯流，這裡是最值得卡高階輸出的戰術焦點。
	var junction := Vector2(360.0, 600.0)
	draw_circle(junction, 42.0, Color(0.98, 0.45, 0.22, 0.16))
	draw_arc(junction, 42.0, 0.0, TAU, 32, Color(1.0, 0.55, 0.24, 0.72), 3.0, true)

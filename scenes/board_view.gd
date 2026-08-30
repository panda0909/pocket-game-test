extends Node2D

## 棋盤的畫面呈現與拖曳輸入。棋盤狀態的真相在 Board（純資料），
## 這裡只負責顯示，以及把玩家的拖放意圖回報給 Main。

## 玩家把某格的守衛拖放到另一格時發出，由 Main 決定實際結果。
signal unit_dropped(from_index: int, to_index: int)
## 把底下所有守衛的開火事件轉給 Main
signal unit_fired(origin: Vector2, target: Node2D, damage: float, splash: float, color: Color, kind: int)
signal unit_ex_fired(origin: Vector2, kind: int, tier: int)

const UNIT_SCENE := preload("res://scenes/unit_view.tscn")
## 16 格的防線需要清楚的卡位提示，中央匯流點則刻意不放格子，
## 讓路徑和單位的位置關係成為玩法資訊，而不是裝飾。
const CELL_INSET := 5.0
const CELL_COLOR := Color(0.03, 0.08, 0.13, 0.66)
const CELL_BORDER_COLOR := Color(0.22, 0.82, 0.74, 0.42)
const CELL_CORNER_RADIUS := 8

const MERGE_POP_SCALE := 1.5
const MERGE_POP_TIME := 0.32

## index -> UnitView
var _views: Dictionary = {}
var _drag_index := -1
var _drag_origin := Vector2.ZERO
## 波次進行中才讓守衛索敵。新加入的守衛會沿用目前狀態。
var _units_active := false
var _cell_style: StyleBoxFlat = null


## 格子用 StyleBoxFlat 畫出乾淨的方角卡位區，讓角色和可放置位置分層讀取。
func _ready() -> void:
	_cell_style = StyleBoxFlat.new()
	_cell_style.bg_color = CELL_COLOR
	_cell_style.border_color = CELL_BORDER_COLOR
	_cell_style.set_border_width_all(2)
	_cell_style.set_corner_radius_all(CELL_CORNER_RADIUS)


func _draw() -> void:
	var size := Board.CELL_SIZE - CELL_INSET * 2.0
	for i in Board.cell_count():
		var center := Board.cell_center(i)
		var rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
		draw_style_box(_cell_style, rect)


# --- 顯示 ---

func add_unit(index: int, kind: int, tier: int) -> void:
	var view := UNIT_SCENE.instantiate()
	add_child(view)
	view.setup(kind, tier)
	view.position = Board.cell_center(index)
	view.fired.connect(_on_unit_fired)
	view.ex_fired.connect(_on_unit_ex_fired)
	view.set_active(_units_active)
	_views[index] = view


func _on_unit_fired(origin: Vector2, target: Node2D, damage: float, splash: float, color: Color, kind: int) -> void:
	unit_fired.emit(origin, target, damage, splash, color, kind)


func _on_unit_ex_fired(origin: Vector2, kind: int, tier: int) -> void:
	unit_ex_fired.emit(origin, kind, tier)


func activate_ex_all() -> int:
	var activated := 0
	for index in _views:
		if _views[index].activate_ex():
			activated += 1
	return activated


## 波次進行中才讓守衛索敵。開場與結束畫面關掉。
func set_units_active(value: bool) -> void:
	_units_active = value
	for index in _views:
		_views[index].set_active(value)


func remove_unit(index: int) -> void:
	if not _views.has(index):
		return
	_views[index].queue_free()
	_views.erase(index)


func move_unit(from_index: int, to_index: int) -> void:
	if not _views.has(from_index):
		return
	var view = _views[from_index]
	_views.erase(from_index)
	_views[to_index] = view
	view.position = Board.cell_center(to_index)


func swap_units(index_a: int, index_b: int) -> void:
	var view_a = _views.get(index_a)
	var view_b = _views.get(index_b)
	if view_a == null or view_b == null:
		return
	_views[index_a] = view_b
	_views[index_b] = view_a
	view_a.position = Board.cell_center(index_b)
	view_b.position = Board.cell_center(index_a)


func set_unit_tier(index: int, tier: int) -> void:
	if _views.has(index):
		_views[index].set_tier(tier)


## 合成後讓新守衛彈跳一下。合成是這款遊戲的核心動作，
## 沒有任何回饋的話玩家會不確定到底成功了沒。
func pop_unit(index: int) -> void:
	if not _views.has(index):
		return
	var view: Node2D = _views[index]
	view.scale = Vector2(MERGE_POP_SCALE, MERGE_POP_SCALE)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "scale", Vector2.ONE, MERGE_POP_TIME)


func get_view(index: int):
	return _views.get(index)


func clear_all() -> void:
	_reset_drag_visual()
	for index in _views.keys():
		_views[index].queue_free()
	_views.clear()


# --- 拖曳 ---

## 用 _unhandled_input 而不是 _input：點到 HUD 按鈕時事件已被 UI 吃掉，
## 不會同時觸發棋盤拖曳。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion:
		# 只在左鍵確實按著時才跟隨。收到「沒按鍵的移動」代表放開的事件
		# 遺失了（例如玩家把滑鼠拖出視窗外才放開），這時要收掉拖曳，
		# 否則守衛會一直黏在游標上，玩家等於失去控制權。
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_drag(event.position)
		elif _drag_index != -1:
			_reset_drag_visual()


func _begin_drag(pos: Vector2) -> void:
	if not visible:
		return
	var index := Board.index_at_position(pos)
	if index == -1 or not _views.has(index):
		return
	_drag_index = index
	_drag_origin = _views[index].position
	_views[index].z_index = 10


func _update_drag(pos: Vector2) -> void:
	if _drag_index == -1:
		return
	_views[_drag_index].position = pos


func _end_drag(pos: Vector2) -> void:
	if _drag_index == -1:
		return
	var from_index := _drag_index
	var to_index := Board.index_at_position(pos)
	# 先把畫面歸位再發訊號。Main 收到後可能會搬動或銷毀這些節點，
	# 順序反過來的話會動到已經不存在的東西。
	_reset_drag_visual()
	if to_index == -1:
		return
	unit_dropped.emit(from_index, to_index)


func _reset_drag_visual() -> void:
	if _drag_index == -1:
		return
	if _views.has(_drag_index):
		_views[_drag_index].position = Board.cell_center(_drag_index)
		_views[_drag_index].z_index = 0
	_drag_index = -1

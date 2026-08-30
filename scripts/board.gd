class_name Board
extends RefCounted

## 守衛棋盤的唯一真相來源。純資料，不知道任何節點的存在，
## 因此所有棋盤規則都能在沒有場景樹的情況下測試。
## BoardView 只負責把這裡的狀態畫出來。

## 6×6 = 36 格。上下各三列，角色排列更密集，但中央路徑與匯流點仍保留
## 空間，玩家可以同時看清楚守衛、敵人和路線。
const COLS := 6
const ROWS := 6
const CELL_SIZE := 84.0
const ORIGIN := Vector2(96.0, 280.0)

## 入口畫面可以切換三種路線；格子維持同一套密集配置，讓玩家換圖時仍能
## 專注在走位和合成，而不是重新適應完全不同的操作位置。
enum Route {
	CROSS,
	LONG_T,
	SNAKE,
}

const ROUTE_NAMES := ["十字匯流", "長 T 字", "雙蛇行"]

## 棋盤資料仍然用線性 index。索引採左右交錯順序，前幾次召喚會同時
## 鋪開兩側，而不是全部堆在畫面左上角。六欄的間距縮小，讓畫面可以
## 放下更多角色又不犧牲角色辨識度。
const CELL_POSITIONS := [
	Vector2(96.0, 280.0), Vector2(201.0, 280.0), Vector2(306.0, 280.0),
	Vector2(414.0, 280.0), Vector2(519.0, 280.0), Vector2(624.0, 280.0),
	Vector2(96.0, 385.0), Vector2(201.0, 385.0), Vector2(306.0, 385.0),
	Vector2(414.0, 385.0), Vector2(519.0, 385.0), Vector2(624.0, 385.0),
	Vector2(96.0, 490.0), Vector2(201.0, 490.0), Vector2(306.0, 490.0),
	Vector2(414.0, 490.0), Vector2(519.0, 490.0), Vector2(624.0, 490.0),
	Vector2(96.0, 700.0), Vector2(201.0, 700.0), Vector2(306.0, 700.0),
	Vector2(414.0, 700.0), Vector2(519.0, 700.0), Vector2(624.0, 700.0),
	Vector2(96.0, 805.0), Vector2(201.0, 805.0), Vector2(306.0, 805.0),
	Vector2(414.0, 805.0), Vector2(519.0, 805.0), Vector2(624.0, 805.0),
	Vector2(96.0, 910.0), Vector2(201.0, 910.0), Vector2(306.0, 910.0),
	Vector2(414.0, 910.0), Vector2(519.0, 910.0), Vector2(624.0, 910.0),
]

## 每格內容為 null 或 {"kind": int, "tier": int}
var _cells: Array = []
static var active_route: int = Route.CROSS


func _init() -> void:
	_cells.resize(COLS * ROWS)
	_cells.fill(null)


static func cell_count() -> int:
	return COLS * ROWS


static func route_count() -> int:
	return ROUTE_NAMES.size()


static func route_name(route: int) -> String:
	return ROUTE_NAMES[posmod(route, route_count())]


static func set_active_route(route: int) -> void:
	active_route = posmod(route, route_count())


static func cell_center(index: int) -> Vector2:
	var positions: Array = _positions_for_route(active_route)
	if index < 0 or index >= positions.size():
		return Vector2(-1.0, -1.0)
	return positions[index]


## 座標落在哪一格。不在棋盤範圍內回傳 -1。
static func index_at_position(pos: Vector2) -> int:
	var half := CELL_SIZE * 0.5
	var positions: Array = _positions_for_route(active_route)
	for i in positions.size():
		var center: Vector2 = positions[i]
		if Rect2(center - Vector2(half, half), Vector2(CELL_SIZE, CELL_SIZE)).has_point(pos):
			return i
	return -1


static func _positions_for_route(route: int) -> Array:
	# 目前三張圖都採用相同的緊密 6×6 戰術盤；路線本身由主場景的三組
	# Path2D 曲線切換。保留這個抽象層，之後若某張地圖需要專屬站位可以
	# 只替換這裡，不必改動 BoardView 或輸入判定。
	return CELL_POSITIONS


func get_unit(index: int):
	if index < 0 or index >= _cells.size():
		return null
	return _cells[index]


func is_empty(index: int) -> bool:
	return get_unit(index) == null


func first_empty_index() -> int:
	for i in _cells.size():
		if _cells[i] == null:
			return i
	return -1


func has_empty() -> bool:
	return first_empty_index() != -1


func is_full() -> bool:
	return not has_empty()


## 滿盤時判斷是否還有任何合法合成，供 HUD 決定要提示合成或開啟清倉。
func has_merge_available() -> bool:
	var occupied := occupied_indices()
	for i in range(occupied.size()):
		var first = get_unit(occupied[i])
		for j in range(i + 1, occupied.size()):
			var second = get_unit(occupied[j])
			if MergeRules.fusion_kind_for(
				first["kind"], second["kind"], first["tier"], second["tier"]) != -1:
				return true
			if MergeRules.can_merge(
				first["kind"], second["kind"], first["tier"], second["tier"]):
				return true
	return false


func place(index: int, kind: int, tier: int) -> void:
	_cells[index] = {"kind": kind, "tier": tier}


func clear_cell(index: int) -> void:
	_cells[index] = null


func clear_all() -> void:
	_cells.fill(null)


func occupied_indices() -> Array:
	var result := []
	for i in _cells.size():
		if _cells[i] != null:
			result.append(i)
	return result


## 處理一次拖放並回傳發生了什麼，讓 BoardView 知道該怎麼更新畫面。
## action 為 "none"（無效）、"move"（移到空格）、"swap"（交換）、
## "merge"（合成，另含新的 kind 與 tier）。
func resolve_drop(from_index: int, to_index: int, rng: RandomNumberGenerator) -> Dictionary:
	if from_index == to_index:
		return {"action": "none"}
	var source = get_unit(from_index)
	if source == null:
		return {"action": "none"}

	var target = get_unit(to_index)
	if target == null:
		_cells[to_index] = source
		_cells[from_index] = null
		return {"action": "move", "from": from_index, "to": to_index}

	var fusion_kind := MergeRules.fusion_kind_for(
		source["kind"], target["kind"], source["tier"], target["tier"])
	if fusion_kind != -1:
		var fusion_tier: int = mini(source["tier"], UnitStats.MAX_TIER)
		_cells[to_index] = {"kind": fusion_kind, "tier": fusion_tier}
		_cells[from_index] = null
		return {
			"action": "merge", "from": from_index, "to": to_index,
			"kind": fusion_kind, "tier": fusion_tier, "fusion": true,
		}

	if MergeRules.can_merge(source["kind"], target["kind"], source["tier"], target["tier"]):
		var merged := MergeRules.merge_result(source["kind"], source["tier"], rng)
		_cells[to_index] = {"kind": merged["kind"], "tier": merged["tier"]}
		_cells[from_index] = null
		return {
			"action": "merge", "from": from_index, "to": to_index,
			"kind": merged["kind"], "tier": merged["tier"], "fusion": false,
		}

	_cells[from_index] = target
	_cells[to_index] = source
	return {"action": "swap", "from": from_index, "to": to_index}

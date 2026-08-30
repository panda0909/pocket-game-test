class_name Board
extends RefCounted

## 守衛棋盤的唯一真相來源。純資料，不知道任何節點的存在，
## 因此所有棋盤規則都能在沒有場景樹的情況下測試。
## BoardView 只負責把這裡的狀態畫出來。

## 4×4 = 16 格。中央水平路徑上下各有兩列，中央垂直路徑與匯流點刻意留空，
## 讓配置區對稱、角色有足夠辨識距離，也保留 T 字防線的戰術焦點。
const COLS := 4
const ROWS := 4
const CELL_SIZE := 104.0
const ORIGIN := Vector2(140.0, 320.0)

## 棋盤資料仍然用線性 index。索引採左右交錯順序，前幾次召喚會同時
## 鋪開兩側，而不是全部堆在畫面左上角。
const CELL_POSITIONS := [
	Vector2(140.0, 320.0), Vector2(580.0, 320.0),
	Vector2(260.0, 320.0), Vector2(460.0, 320.0),
	Vector2(140.0, 450.0), Vector2(580.0, 450.0),
	Vector2(260.0, 450.0), Vector2(460.0, 450.0),
	Vector2(140.0, 760.0), Vector2(580.0, 760.0),
	Vector2(260.0, 760.0), Vector2(460.0, 760.0),
	Vector2(140.0, 890.0), Vector2(580.0, 890.0),
	Vector2(260.0, 890.0), Vector2(460.0, 890.0),
]

## 每格內容為 null 或 {"kind": int, "tier": int}
var _cells: Array = []


func _init() -> void:
	_cells.resize(COLS * ROWS)
	_cells.fill(null)


static func cell_count() -> int:
	return COLS * ROWS


static func cell_center(index: int) -> Vector2:
	if index < 0 or index >= CELL_POSITIONS.size():
		return Vector2(-1.0, -1.0)
	return CELL_POSITIONS[index]


## 座標落在哪一格。不在棋盤範圍內回傳 -1。
static func index_at_position(pos: Vector2) -> int:
	var half := CELL_SIZE * 0.5
	for i in CELL_POSITIONS.size():
		var center: Vector2 = CELL_POSITIONS[i]
		if Rect2(center - Vector2(half, half), Vector2(CELL_SIZE, CELL_SIZE)).has_point(pos):
			return i
	return -1


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
		_cells[to_index] = {"kind": fusion_kind, "tier": UnitStats.MAX_TIER}
		_cells[from_index] = null
		return {
			"action": "merge", "from": from_index, "to": to_index,
			"kind": fusion_kind, "tier": UnitStats.MAX_TIER, "fusion": true,
		}

	if MergeRules.can_merge(source["tier"], target["tier"]):
		var merged := MergeRules.merge_result(source["tier"], rng)
		_cells[to_index] = {"kind": merged["kind"], "tier": merged["tier"]}
		_cells[from_index] = null
		return {
			"action": "merge", "from": from_index, "to": to_index,
			"kind": merged["kind"], "tier": merged["tier"], "fusion": false,
		}

	_cells[from_index] = target
	_cells[to_index] = source
	return {"action": "swap", "from": from_index, "to": to_index}

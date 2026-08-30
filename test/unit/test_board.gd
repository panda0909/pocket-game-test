extends GutTest

var board: Board

func before_each() -> void:
	board = Board.new()

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng

func test_starts_empty() -> void:
	assert_eq(board.occupied_indices().size(), 0)
	assert_true(board.has_empty())
	assert_eq(board.first_empty_index(), 0)

func test_place_and_read_back() -> void:
	board.place(5, UnitStats.Kind.GECKO, 2)
	var unit = board.get_unit(5)
	assert_eq(unit["kind"], UnitStats.Kind.GECKO)
	assert_eq(unit["tier"], 2)
	assert_false(board.is_empty(5))

func test_first_empty_skips_occupied() -> void:
	board.place(0, UnitStats.Kind.BULL, 1)
	board.place(1, UnitStats.Kind.BULL, 1)
	assert_eq(board.first_empty_index(), 2)

func test_full_board_reports_no_empty() -> void:
	for i in Board.cell_count():
		board.place(i, UnitStats.Kind.BULL, 1)
	assert_false(board.has_empty())
	assert_eq(board.first_empty_index(), -1)

func test_cell_center_matches_layout() -> void:
	assert_eq(Board.cell_center(0), Board.ORIGIN)
	assert_eq(Board.cell_center(Board.COLS - 1),
		Vector2(460.0, 320.0))
	assert_eq(Board.cell_center(Board.cell_count() - 1),
		Vector2(460.0, 890.0))

func test_board_is_dense_enough_to_build_a_wall() -> void:
	# 交叉型防線上下各兩列，中央匯流點仍然留空。
	assert_eq(Board.cell_count(), 16)
	assert_eq(Board.COLS, 4)
	assert_eq(Board.ROWS, 4)

func test_board_fits_inside_the_track() -> void:
	# 交叉型地圖上下方留出路徑與匯流空間。
	var half := Board.CELL_SIZE * 0.5
	var first := Board.cell_center(0)
	var last := Board.cell_center(Board.cell_count() - 1)
	assert_gt(first.x - half, 80.0, "左緣不可超出戰場")
	assert_lt(last.x + half, 640.0, "右緣不可超出戰場")
	assert_gt(first.y - half, 240.0, "上排不可壓到 HUD")
	assert_lt(last.y + half, 960.0, "下排不可壓到金庫")

func test_index_at_position_round_trips() -> void:
	for i in Board.cell_count():
		assert_eq(Board.index_at_position(Board.cell_center(i)), i)

func test_index_at_position_outside_board_is_minus_one() -> void:
	assert_eq(Board.index_at_position(Vector2(20, 465)), -1)
	assert_eq(Board.index_at_position(Vector2(360, 1200)), -1)
	assert_eq(Board.index_at_position(Vector2(360, 620)), -1, "中央匯流點要保留")

func test_drop_onto_empty_moves() -> void:
	board.place(0, UnitStats.Kind.DINO, 3)
	var result := board.resolve_drop(0, 4, _rng())
	assert_eq(result["action"], "move")
	assert_true(board.is_empty(0))
	assert_eq(board.get_unit(4)["tier"], 3)

func test_drop_onto_different_tier_swaps() -> void:
	board.place(0, UnitStats.Kind.BULL, 1)
	board.place(1, UnitStats.Kind.GECKO, 2)
	var result := board.resolve_drop(0, 1, _rng())
	assert_eq(result["action"], "swap")
	assert_eq(board.get_unit(0)["tier"], 2)
	assert_eq(board.get_unit(1)["tier"], 1)

func test_drop_onto_same_tier_merges() -> void:
	board.place(0, UnitStats.Kind.BULL, 2)
	board.place(1, UnitStats.Kind.GECKO, 2)
	var result := board.resolve_drop(0, 1, _rng())
	assert_eq(result["action"], "merge")
	assert_true(board.is_empty(0), "來源格應該清空")
	assert_eq(board.get_unit(1)["tier"], 3, "目標格升為三階")

func test_same_max_tier_units_swap_instead_of_merging() -> void:
	board.place(0, UnitStats.Kind.BULL, UnitStats.MAX_TIER)
	board.place(1, UnitStats.Kind.BULL, UnitStats.MAX_TIER)
	var result := board.resolve_drop(0, 1, _rng())
	assert_eq(result["action"], "swap", "同種類滿階不能再融合，應改為交換")

func test_different_max_tier_units_fuse_into_duo_shooter() -> void:
	board.place(0, UnitStats.Kind.BULL, UnitStats.MAX_TIER)
	board.place(1, UnitStats.Kind.GECKO, UnitStats.MAX_TIER)
	var result := board.resolve_drop(0, 1, _rng())
	assert_eq(result["action"], "merge")
	assert_true(result["fusion"])
	assert_eq(result["kind"], UnitStats.Kind.DUO_SHOOTER)
	assert_eq(result["tier"], UnitStats.MAX_TIER)
	assert_true(board.is_empty(0), "融合來源格應該清空")
	assert_eq(board.get_unit(1)["kind"], UnitStats.Kind.DUO_SHOOTER)

func test_final_unit_against_lower_tier_does_not_fuse() -> void:
	board.place(0, UnitStats.Kind.BULL, UnitStats.MAX_TIER)
	board.place(1, UnitStats.Kind.GECKO, UnitStats.MAX_TIER - 1)
	var result := board.resolve_drop(0, 1, _rng())
	assert_eq(result["action"], "swap", "只有兩邊都滿階才可融合")

func test_drop_onto_self_does_nothing() -> void:
	board.place(0, UnitStats.Kind.BULL, 1)
	var result := board.resolve_drop(0, 0, _rng())
	assert_eq(result["action"], "none")
	assert_eq(board.get_unit(0)["tier"], 1)

func test_drop_from_empty_cell_does_nothing() -> void:
	var result := board.resolve_drop(3, 4, _rng())
	assert_eq(result["action"], "none")

func test_clear_all_empties_board() -> void:
	board.place(0, UnitStats.Kind.BULL, 1)
	board.place(7, UnitStats.Kind.DINO, 2)
	board.clear_all()
	assert_eq(board.occupied_indices().size(), 0)

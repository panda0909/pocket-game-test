extends GutTest

func _candidate(id: int, pos: Vector2, progress: float) -> Dictionary:
	return {"id": id, "position": pos, "progress": progress}

func test_no_candidates_returns_null() -> void:
	assert_null(Targeting.select(Vector2.ZERO, 300.0, []))

func test_candidate_out_of_range_is_ignored() -> void:
	var far := [_candidate(1, Vector2(1000, 0), 0.5)]
	assert_null(Targeting.select(Vector2.ZERO, 300.0, far))

func test_picks_candidate_within_range() -> void:
	var list := [_candidate(7, Vector2(100, 0), 0.5)]
	var chosen = Targeting.select(Vector2.ZERO, 300.0, list)
	assert_eq(chosen["id"], 7)

func test_prefers_the_one_closest_to_the_vault() -> void:
	# 選最接近終點的敵人，因為它最快造成傷害。若改選距離最近的，
	# 守衛會一直打剛進場的敵人而放走快到金庫的那隻。
	var list := [
		_candidate(1, Vector2(50, 0), 0.2),
		_candidate(2, Vector2(200, 0), 0.9),
		_candidate(3, Vector2(100, 0), 0.5),
	]
	var chosen = Targeting.select(Vector2.ZERO, 300.0, list)
	assert_eq(chosen["id"], 2)

func test_out_of_range_leader_does_not_block_in_range_choice() -> void:
	var list := [
		_candidate(1, Vector2(5000, 0), 0.95),
		_candidate(2, Vector2(120, 0), 0.3),
	]
	var chosen = Targeting.select(Vector2.ZERO, 300.0, list)
	assert_eq(chosen["id"], 2, "射程外的領先者不該擋住射程內的選擇")

func test_range_boundary_is_inclusive() -> void:
	var list := [_candidate(1, Vector2(300, 0), 0.5)]
	assert_not_null(Targeting.select(Vector2.ZERO, 300.0, list))

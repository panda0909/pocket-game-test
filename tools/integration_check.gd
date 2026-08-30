extends Node

## 整合測試：把整個遊戲場景跑起來，驗證單元測試碰不到的場景樹行為
## ——輸入路由、訊號串接、拖曳合成、波次流程、結束與重來。
##
## 三個寫這種腳本必須注意的地方（都是實際踩過的）：
##   1. 幀數不等於時間。幀率會變（有敵人時與清場後差距可達數十倍），
##      要等時間就用 Time.get_ticks_msec()。
##   2. Input.parse_input_event 是非同步的：事件排進佇列，下一幀才派送。
##      不要假設「送出後立刻生效」，要等到狀態真的改變。
##   3. 結果要逐項即時印出。全部累積到最後才印的話，腳本一旦中途卡住
##      就什麼都看不到。

const UI_TIMEOUT_MS := 8000
const WAVE_TIMEOUT_MS := 45000
const GENERATED_ASSETS := [
	"res://assets/generated/stock_market_background.png",
	"res://assets/generated/stock_t_path_overlay.png",
	"res://assets/generated/stock_junction_core.png",
	"res://assets/generated/stock_summon_effect.png",
	"res://assets/generated/stock_merge_effect.png",
	"res://assets/generated/stock_combat_effects_sheet.png",
	"res://assets/generated/stock_bear_enemy_sheet.png",
	"res://assets/generated/stock_market_ui_sheet.png",
	"res://assets/generated/stock_vault_states_sheet.png",
	"res://assets/generated/stock_boss_shield_states.png",
	"res://assets/generated/stock_bat_enemy.png",
]
const NEW_CHARACTER_ASSETS := [
	"res://assets/characters/new/trend_fox.png",
	"res://assets/characters/new/trend_fox_attack.png",
	"res://assets/characters/new/quant_rabbit.png",
	"res://assets/characters/new/quant_rabbit_attack.png",
	"res://assets/characters/new/radar_owl.png",
	"res://assets/characters/new/radar_owl_attack.png",
	"res://assets/characters/new/turret_rhino.png",
	"res://assets/characters/new/turret_rhino_attack.png",
	"res://assets/characters/new/arbitrage_octopus.png",
	"res://assets/characters/new/arbitrage_octopus_attack.png",
]

var _failures := 0
var _main: Node
var _hud: CanvasLayer
var _board_view: Node2D


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["通過" if ok else "失敗", label])
	if not ok:
		_failures += 1


func _uses_atlas(node: Node, atlas_path: String) -> bool:
	var texture = node.get("texture")
	if texture is Texture2D and texture.resource_path == atlas_path:
		return true
	if not (texture is AtlasTexture):
		return false
	var atlas: Texture2D = texture.atlas
	if atlas == null:
		return false
	return atlas.resource_path == atlas_path or atlas.resource_path.begins_with(atlas_path)


func _uses_atlas_frame(node: Node, atlas_path: String, frame_index: int,
		frame_count: int) -> bool:
	var texture = node.get("texture")
	if not texture is AtlasTexture:
		return false
	var atlas: Texture2D = texture.atlas
	if atlas == null:
		return false
	var path_ok := atlas.resource_path == atlas_path or atlas.resource_path.begins_with(atlas_path)
	var frame_width := float(atlas.get_width()) / float(frame_count)
	return path_ok and is_equal_approx(texture.region.position.x, frame_width * frame_index)


func _effects_include(atlas_path: String) -> bool:
	for child in _main.get_node("Effects").get_children():
		if child is Sprite2D and _uses_atlas(child, atlas_path):
			return true
	return false


func _effects_include_script(script_path: String) -> bool:
	for child in _main.get_node("Effects").get_children():
		var script = child.get_script()
		if script != null and script.resource_path == script_path:
			return true
	return false


func _await_until(condition: Callable, timeout_ms: int) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - start > timeout_ms:
			return false
		await get_tree().process_frame
	return true


func _mouse(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	Input.parse_input_event(event)


## 真實拖曳會持續送出帶按鍵遮罩的移動事件，測試照做才不會因為
## 「單一事件沒剛好在對的時機被沖出去」而偶發失敗。
func _drag_to(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _drag_unit(from_index: int, to_index: int) -> bool:
	var to_pos := Board.cell_center(to_index)
	var began := false
	for attempt in 3:
		_mouse(Board.cell_center(from_index), true)
		# 等到拖曳真的開始再送移動事件，把時序假設完全拿掉。
		# GUI 測試偶爾會在視窗剛完成繪製時吃掉第一個按下事件，
		# 允許重新送一次，避免把輸入層的時序抖動誤判成玩法壞掉。
		began = await _await_until(
			func(): return _board_view._drag_index == from_index, UI_TIMEOUT_MS)
		if began:
			break
		_mouse(Board.cell_center(from_index), false)
		await get_tree().process_frame
	if not began:
		return false
	for i in 8:
		_drag_to(to_pos)
		await get_tree().process_frame
	_mouse(to_pos, false)
	await get_tree().process_frame
	await get_tree().process_frame
	return true


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_hud = _main.get_node("HUD")
	_board_view = _main.get_node("BoardView")
	var start_button: Button = _hud.get_node("StartButton")
	var summon_button: Button = _hud.get_node("SummonButton")
	var ex_button: Button = _hud.get_node("ExButton")
	await get_tree().process_frame

	print("環境：視窗 %s　視圖 %s" % [
		DisplayServer.window_get_size(), get_viewport().get_visible_rect().size])

	_check("開場顯示標題與開始鈕",
		start_button.visible and not summon_button.visible and not _board_view.visible)

	# 用真實滑鼠事件點擊，才驗得到輸入路由沒有被背景 Control 吃掉
	_mouse(Vector2(360, 905), true)
	await get_tree().process_frame
	_mouse(Vector2(360, 905), false)
	var started: bool = await _await_until(func(): return _main._running, UI_TIMEOUT_MS)
	_check("點擊開始鈕可開局", started and summon_button.visible and _board_view.visible)
	var all_generated_assets_loaded := true
	for path in GENERATED_ASSETS:
		all_generated_assets_loaded = all_generated_assets_loaded and ResourceLoader.exists(path)
	_check("全部生成素材可載入", all_generated_assets_loaded)
	var all_new_character_assets_loaded := true
	for path in NEW_CHARACTER_ASSETS:
		all_new_character_assets_loaded = all_new_character_assets_loaded and ResourceLoader.exists(path)
	_check("五種新職業待機／攻擊素材可載入", all_new_character_assets_loaded)
	_check("戰場背景已接入", _main.get_node("BattlefieldArt").texture.resource_path == GENERATED_ASSETS[0])
	_check("T 型地圖預覽已接入", _main.get_node("TacticalMapPreview").texture.resource_path == GENERATED_ASSETS[1])
	_check("中央匯流核心已接入", _main.get_node("JunctionCore").texture.resource_path == GENERATED_ASSETS[2])
	_check("HUD 圖示圖集已接入", _uses_atlas(_hud.get_node("WaveIcon"), GENERATED_ASSETS[7]))

	var effects: Node2D = _main.get_node("Effects")

	# 給足金幣，鋪滿棋盤讓波次能快速清掉
	_main._economy.gold = 100000
	_hud.summon_requested.emit()
	await get_tree().process_frame
	_check("召喚會建立新召喚特效", _effects_include(GENERATED_ASSETS[3]))
	for i in range(Board.cell_count() - 1):
		_hud.summon_requested.emit()
		await get_tree().process_frame
	_check("召喚可鋪滿棋盤（%d 格）" % Board.cell_count(),
		_main._board.occupied_indices().size() == Board.cell_count())
	_check("有守衛時 EX 按鈕可用", ex_button.visible and not ex_button.disabled)
	_hud.ex_requested.emit()
	await get_tree().process_frame
	_check("EX 發動後進入冷卻", _main._ex_cooldown_left > 0.0 and ex_button.disabled)
	_check("EX 會建立技能特效", _effects_include_script("res://scenes/effects/ex_burst.gd"))
	var first_view: Node = _board_view.get_view(0)
	# 暫停這一隻的索敵，讓待機圖檢查不會被連續普通攻擊打斷。
	first_view.set_active(false)
	await _await_until(func(): return not first_view._is_attacking, UI_TIMEOUT_MS)
	var first_kind: int = first_view.kind
	var first_idle_ok: bool = _uses_atlas(first_view.get_node("Sprite2D"),
		"res://assets/characters/tiers/") if not UnitStats.tier_texture_path(first_kind).is_empty() \
		else first_view.get_node("Sprite2D").texture.resource_path == UnitStats.texture_path(first_kind)
	_check("守衛使用角色階級或專用待機圖", first_idle_ok)
	first_view.set_active(true)
	var attack_started: bool = first_view.activate_ex()
	await get_tree().process_frame
	_check("守衛有獨立攻擊貼圖", attack_started
		and first_view.get_node("Sprite2D").texture.resource_path
		== UnitStats.attack_texture_path(first_kind))
	first_view.set_active(false)
	var attack_finished: bool = await _await_until(
		func(): return not first_view._is_attacking, UI_TIMEOUT_MS)
	_check("攻擊後回到待機貼圖", attack_finished
		and (first_idle_ok if UnitStats.tier_texture_path(first_kind).is_empty() \
		else _uses_atlas(first_view.get_node("Sprite2D"), "res://assets/characters/tiers/")))
	first_view.set_active(true)

	_hud.summon_requested.emit()
	await get_tree().process_frame
	_check("棋盤滿了不會再召喚",
		_main._board.occupied_indices().size() == Board.cell_count())

	# 整合測試固定成同職業，驗證一至五階的正確合成規則，不受隨機召喚結果影響。
	_main._board.place(0, UnitStats.Kind.BULL, 1)
	_main._board.place(1, UnitStats.Kind.BULL, 1)
	_board_view.remove_unit(0)
	_board_view.remove_unit(1)
	_board_view.add_unit(0, UnitStats.Kind.BULL, 1)
	_board_view.add_unit(1, UnitStats.Kind.BULL, 1)
	# 拖曳合成：兩隻一階應合成為同職業二階
	var tier_before: int = _main._board.get_unit(1)["tier"]
	var dragged: bool = await _drag_unit(0, 1)
	_check("拖曳有開始", dragged)
	_check("合成後來源格清空", _main._board.is_empty(0))
	var merged = _main._board.get_unit(1)
	_check("合成後階級由 %d 升為 2" % tier_before, merged != null and merged["tier"] == 2)
	var merged_view: Node = _board_view.get_view(1)
	_check("合成後換成高一階裝備外觀", _uses_atlas(merged_view.get_node("Sprite2D"),
		"res://assets/characters/tiers/"))
	_check("合成會建立升階特效", _effects_include(GENERATED_ASSETS[4]))
	var gold_before_cell_buy: int = _main._economy.gold
	_mouse(Board.cell_center(0), true)
	await get_tree().process_frame
	_mouse(Board.cell_center(0), false)
	await get_tree().process_frame
	_check("點擊空白格可直接購買並放置",
		_main._board.get_unit(0) != null
		and _main._economy.gold < gold_before_cell_buy)

	# 直接掛一個融合角色到場景樹，驗證融合待機圖與攻擊圖都能被載入。
	var fusion_view: Node2D = load("res://scenes/unit_view.tscn").instantiate()
	_board_view.add_child(fusion_view)
	fusion_view.setup(UnitStats.Kind.DUO_SHOOTER, UnitStats.MAX_TIER)
	fusion_view.position = Vector2(360, 600)
	fusion_view.set_active(true)
	await get_tree().process_frame
	_check("融合角色使用專用待機圖",
		fusion_view.get_node("Sprite2D").texture.resource_path
		== UnitStats.texture_path(UnitStats.Kind.DUO_SHOOTER))
	var fusion_attack_started: bool = fusion_view.activate_ex()
	await get_tree().process_frame
	_check("融合角色使用專用攻擊圖", fusion_attack_started
		and fusion_view.get_node("Sprite2D").texture.resource_path
		== UnitStats.attack_texture_path(UnitStats.Kind.DUO_SHOOTER))
	fusion_view.queue_free()
	await get_tree().process_frame

	# 特效必須自我銷毀，否則場上物件會無限累積——前兩個專案都踩過這個坑
	_main._spawn_burst(Vector2(360, 640), Color.WHITE, 8, 40.0, 6.0, 0.2)
	await get_tree().process_frame
	var burst_spawned := effects.get_child_count() > 0
	var burst_gone: bool = await _await_until(
		func(): return effects.get_child_count() == 0, UI_TIMEOUT_MS)
	_check("爆散特效播完會自我銷毀", burst_spawned and burst_gone)

	# 波次流程
	var wave_started: bool = await _await_until(
		func(): return _main._wave >= 1, UI_TIMEOUT_MS)
	_check("開場緩衝後波次開始", wave_started)

	var enemy_spawned: bool = await _await_until(
		func(): return (not get_tree().get_nodes_in_group("enemy").is_empty()
			or _main._spawn_serial > 0), UI_TIMEOUT_MS)
	_check("敵人有生成", enemy_spawned)
	var live_enemies := get_tree().get_nodes_in_group("enemy")
	if not live_enemies.is_empty():
		var first_enemy: Node = live_enemies[0]
		_check("熊市敵人使用七欄圖集", _uses_atlas(first_enemy.get_node("Sprite2D"), GENERATED_ASSETS[6]))
		for kind in range(7):
			var sample: Node = load("res://scenes/enemy.tscn").instantiate()
			_main._track_left.add_child(sample)
			sample.setup(kind, 8)
			await get_tree().process_frame
			_check("第 %d 種熊使用正確圖格" % (kind + 1),
				_uses_atlas_frame(sample.get_node("Sprite2D"), GENERATED_ASSETS[6], kind, 7))
			sample.queue_free()
			await get_tree().process_frame
		var bat: Node = load("res://scenes/enemy.tscn").instantiate()
		_main._track_left.add_child(bat)
		bat.setup(WaveTable.EnemyKind.BAT, 20)
		await get_tree().process_frame
		_check("空中蝙蝠使用獨立貼圖並升空",
			bat.get_node("Sprite2D").texture.resource_path == WaveTable.texture_path(WaveTable.EnemyKind.BAT)
			and WaveTable.is_airborne(WaveTable.EnemyKind.BAT))
		bat.queue_free()
		await get_tree().process_frame

	var boss: Node = load("res://scenes/enemy.tscn").instantiate()
	_main._track_left.add_child(boss)
	boss.setup(WaveTable.EnemyKind.BOSS_BEAR, 5)
	await get_tree().process_frame
	_check("Boss 盾牌圖集已接入", boss.get_node("ShieldSprite").visible
		and _uses_atlas(boss.get_node("ShieldSprite"), GENERATED_ASSETS[9]))
	boss.queue_free()
	await get_tree().process_frame

	_main._on_projectile_impact(Vector2(360, 620), UnitStats.Kind.BULL)
	await get_tree().process_frame
	_check("攻擊命中特效圖集已接入", _effects_include(GENERATED_ASSETS[5]))
	_main._economy.lives = 10
	_main._update_vault_visual()
	_check("金庫狀態圖集已接入", _uses_atlas(_main._vault, GENERATED_ASSETS[8]))
	_main._economy.lives = Economy.STARTING_LIVES
	_main._update_vault_visual()

	# 加速鍵：一局動輒上百波，測試也靠它把等待時間壓下來
	var base_scale := Engine.time_scale
	_hud.speed_toggled.emit()
	await get_tree().process_frame
	_check("加速鍵會提高時間倍率", Engine.time_scale > base_scale)

	var gold_at_wave_one: int = _main._economy.gold
	var wave_two: bool = await _await_until(
		func(): return _main._wave >= 2, WAVE_TIMEOUT_MS)
	_check("波次會依時間自動推進到第二波", wave_two)
	_check("推進波次有給過關獎勵", _main._economy.gold > gold_at_wave_one)
	_check("撐過第一波沒有掉生命", _main._economy.lives == Economy.STARTING_LIVES)

	# 傷害數字要跳得出來，而且不能無上限累積
	var numbers: Node2D = _main.get_node("DamageNumbers")
	var saw_numbers: bool = await _await_until(
		func(): return numbers.get_child_count() > 0, UI_TIMEOUT_MS)
	_check("守衛打中敵人會跳傷害數字", saw_numbers)
	_check("傷害數字數量在上限內",
		numbers.get_child_count() <= _main.MAX_DAMAGE_NUMBERS)

	# 直接扣光生命驗證結束流程
	_main._economy.lose_lives(_main._economy.lives)
	_main._game_over()
	await get_tree().process_frame
	_check("結束後停止流程", not _main._running)
	_check("結束後清空場上敵人", get_tree().get_nodes_in_group("enemy").is_empty())
	_check("結束後清空投射物、特效與傷害數字",
		_main.get_node("Projectiles").get_child_count() == 0
		and effects.get_child_count() == 0
		and _main.get_node("DamageNumbers").get_child_count() == 0)
	_check("結束後把時間倍率復原", is_equal_approx(Engine.time_scale, 1.0))

	var restart_shown: bool = await _await_until(
		func(): return start_button.visible, UI_TIMEOUT_MS)
	_check("結束畫面出現重來鈕", restart_shown and start_button.text == "再玩一次")

	_hud.start_game.emit()
	await get_tree().process_frame
	_check("重來後棋盤清空且金幣重置",
		_main._board.occupied_indices().is_empty()
		and _main._economy.gold == Economy.STARTING_GOLD)

	print("---")
	if _failures == 0:
		print("整合測試全部通過")
	else:
		print("整合測試有 %d 項失敗" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)

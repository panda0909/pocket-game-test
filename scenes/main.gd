extends Node2D

## 遊戲流程總控。所有狀態改變都經過這裡，其他節點只發訊號請求。

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const BURST_SCENE := preload("res://scenes/effects/burst.tscn")
const EX_EFFECT_SCENE := preload("res://scenes/effects/ex_burst.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/effects/damage_number.tscn")
const BATTLEFIELD_TEXTURE := preload("res://assets/generated/stock_market_background.png")
const T_PATH_TEXTURE := preload("res://assets/generated/stock_t_path_overlay.png")
const JUNCTION_CORE_TEXTURE := preload("res://assets/generated/stock_junction_core.png")
const SUMMON_EFFECT_TEXTURE := preload("res://assets/generated/stock_summon_effect.png")
const MERGE_EFFECT_TEXTURE := preload("res://assets/generated/stock_merge_effect.png")
const ATTACK_EFFECTS_TEXTURE := preload("res://assets/generated/stock_combat_effects_sheet.png")
const VAULT_STATES_TEXTURE := preload("res://assets/generated/stock_vault_states_sheet.png")

const SAVE_PATH := "user://best_wave.save"

## 每一波固定這麼久，時間到就推進下一波——不管上一波清完沒有。
## 壓力來自「清不掉就會疊」，這也是遊戲能快速走到三位數波次的原因。
const WAVE_DURATION := 20.0
const FIRST_WAVE_DELAY := 4.0
const EX_COOLDOWN := 14.0

## 加速倍率。這類遊戲一局動輒上百波，沒有加速會玩得很痛苦。
const SPEED_STEPS := [1.0, 2.0, 3.0]

## 擊殺的爆散偏金色，讀起來像「獲利」，呼應投資金庫主題
const KILL_BURST_COLOR := Color(0.98, 0.78, 0.20)
const VAULT_HIT_COLOR := Color(1.7, 0.65, 0.65)
const VAULT_SHAKE_STEPS := 4
const VAULT_SHAKE_OFFSET := 9.0

## 場上同時存在的傷害數字上限。敵人端已經先合併過，這裡是第二道保險——
## 後期一波近三十隻敵人同時挨打，不設限畫面會被數字淹沒。
const MAX_DAMAGE_NUMBERS := 26

var _board := Board.new()
var _economy := Economy.new()
var _rng := RandomNumberGenerator.new()

var _wave := 0
var _best_wave := 0
var _running := false
## 距離下一波還有幾秒。用累加 delta 而不是 Timer，是因為畫面要顯示倒數，
## 而且 delta 會自動吃到 Engine.time_scale，加速時倒數也跟著加速。
var _wave_time_left := 0.0
## 這一波還沒生成的敵人，依序取出
var _pending: Array = []
var _speed_index := 0
var _spawn_serial := 0
var _ex_cooldown_left := 0.0

var _vault_flash_tween: Tween = null
var _vault_shake_tween: Tween = null

@onready var _board_view: Node2D = $BoardView
@onready var _hud: CanvasLayer = $HUD
@onready var _track_left: Path2D = $Tracks/TrackLeft
@onready var _track_right: Path2D = $Tracks/TrackRight
@onready var _projectiles: Node2D = $Projectiles
@onready var _effects: Node2D = $Effects
@onready var _damage_numbers: Node2D = $DamageNumbers
@onready var _vault: Sprite2D = $Vault
@onready var _battlefield_art: Sprite2D = $BattlefieldArt
@onready var _tactical_map_preview: Sprite2D = $TacticalMapPreview
@onready var _junction_core: Sprite2D = $JunctionCore
@onready var _spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	_rng.randomize()
	# 加速是全域設定，不重設會從上一次執行殘留下來
	Engine.time_scale = 1.0
	_load_best_wave()
	_hud.start_game.connect(new_game)
	_hud.summon_requested.connect(_on_summon_requested)
	_hud.speed_toggled.connect(_on_speed_toggled)
	_hud.ex_requested.connect(_on_ex_requested)
	_board_view.unit_dropped.connect(_on_unit_dropped)
	_board_view.unit_fired.connect(_on_unit_fired)
	_board_view.unit_ex_fired.connect(_on_unit_ex_fired)
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	# 以程式常數再指定一次，確保換場景或匯出後不會退回舊的 inspector 資產。
	_battlefield_art.texture = BATTLEFIELD_TEXTURE
	_tactical_map_preview.texture = T_PATH_TEXTURE
	_junction_core.texture = JUNCTION_CORE_TEXTURE
	# 戰場只在遊戲中顯示，否則路徑與金庫會疊到標題畫面。
	_board_view.hide()
	$Tracks.hide()
	_vault.hide()
	_battlefield_art.hide()
	_junction_core.hide()
	_tactical_map_preview.show()
	_hud.show_title(_best_wave)


func new_game() -> void:
	_clear_field()
	_board.clear_all()
	_board_view.clear_all()
	_board_view.show()
	$Tracks.show()
	_vault.show()
	_battlefield_art.show()
	_junction_core.show()
	_tactical_map_preview.hide()
	_economy.reset()
	_update_vault_visual()
	_wave = 0
	_pending.clear()
	_spawn_serial = 0
	_ex_cooldown_left = 0.0
	_wave_time_left = FIRST_WAVE_DELAY
	_running = true
	_board_view.set_units_active(true)
	_hud.hide_title()
	_hud.update_speed_button(SPEED_STEPS[_speed_index])
	_refresh_hud()
	_hud.show_message("市場開盤，準備防守")


## 清空場上敵人、投射物、特效與傷害數字。結束與重來都要用。
func _clear_field() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	for container in [_projectiles, _effects, _damage_numbers]:
		for child in container.get_children():
			child.queue_free()


func _refresh_hud() -> void:
	_hud.update_stats(maxi(_wave, 1), _economy.lives, _economy.gold,
		maxf(_wave_time_left, 0.0))
	_hud.update_summon_button(_economy.summon_cost(), _economy.can_afford_summon())
	_hud.update_ex_button(_ex_cooldown_left, not _board.occupied_indices().is_empty())


# --- 波次流程 ---

func _process(delta: float) -> void:
	if not _running:
		return
	_wave_time_left -= delta
	_ex_cooldown_left = maxf(_ex_cooldown_left - delta, 0.0)
	if _wave_time_left <= 0.0:
		_advance_wave()
	_refresh_hud()


func _advance_wave() -> void:
	# 撐過一波就給獎勵。判斷依據是時間到，不是把敵人清光——
	# 沒清完的敵人會留在場上跟下一波疊在一起，那正是壓力的來源。
	if _wave >= 1:
		_economy.add_gold(Economy.wave_reward(_wave))
	_wave += 1
	# 召喚費用的基準跟著波次走，波內的加成同時歸零
	_economy.set_wave(_wave)
	_pending = WaveTable.composition(_wave)
	_wave_time_left = WAVE_DURATION
	_hud.hide_message()
	_spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	if _pending.is_empty():
		_spawn_timer.stop()
		return
	_spawn_enemy(_pending.pop_front(), _wave)


## 敵人必須是 Path2D 的子節點，PathFollow2D 才知道要沿哪條線走。
## 左右入口交替生成，視覺上形成雙入口匯流，也為未來雙人分線保留位置。
func _spawn_enemy(kind: int, wave: int) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	var track := _track_left if _spawn_serial % 2 == 0 else _track_right
	track.add_child(enemy)
	_spawn_serial += 1
	enemy.setup(kind, wave)
	enemy.died.connect(_on_enemy_died)
	enemy.reached_vault.connect(_on_enemy_reached_vault)
	enemy.damage_dealt.connect(_on_enemy_damage_dealt)


func _on_enemy_died(reward: int, at: Vector2) -> void:
	_economy.add_gold(reward)
	_spawn_burst(at, KILL_BURST_COLOR, 9, 38.0, 5.0, 0.36)


func _on_enemy_reached_vault(steal: int) -> void:
	_economy.lose_lives(steal)
	_update_vault_visual()
	_shake_vault()
	_hud.flash_damage()
	if _economy.is_defeated():
		_game_over()


func _on_enemy_damage_dealt(amount: float, at: Vector2, color: Color) -> void:
	if _damage_numbers.get_child_count() >= MAX_DAMAGE_NUMBERS:
		return
	var number := DAMAGE_NUMBER_SCENE.instantiate()
	_damage_numbers.add_child(number)
	number.global_position = at
	number.setup(amount, color)


func _game_over() -> void:
	_running = false
	_spawn_timer.stop()
	_board_view.set_units_active(false)
	# 結束畫面的大字在畫面中央，戰場留著會被蓋住一半，不如收起來。
	_board_view.hide()
	$Tracks.hide()
	_vault.hide()
	_battlefield_art.hide()
	_junction_core.hide()
	_tactical_map_preview.hide()
	_clear_field()
	Engine.time_scale = 1.0
	var is_record := _wave > _best_wave
	if is_record:
		_best_wave = _wave
		_save_best_wave()
	_hud.show_game_over(_wave, _best_wave, is_record)


# --- 玩家操作 ---

func _on_summon_requested() -> void:
	if not _running or not _economy.can_afford_summon():
		return
	var index := _board.first_empty_index()
	if index == -1:
		_hud.show_message("沒有空格了，先合成吧")
		return
	_economy.pay_summon()
	# 一階守衛的種類也是隨機的，和合成一樣用可注入的 rng
	var kind := _rng.randi_range(UnitStats.Kind.BULL, UnitStats.Kind.DINO)
	_board.place(index, kind, 1)
	_board_view.add_unit(index, kind, 1)
	_spawn_image_effect(SUMMON_EFFECT_TEXTURE, Board.cell_center(index), 0.085, 0.48)
	_refresh_hud()


func _on_speed_toggled() -> void:
	_speed_index = (_speed_index + 1) % SPEED_STEPS.size()
	Engine.time_scale = SPEED_STEPS[_speed_index]
	_hud.update_speed_button(SPEED_STEPS[_speed_index])


func _on_ex_requested() -> void:
	if not _running or _ex_cooldown_left > 0.0:
		return
	var activated: int = _board_view.activate_ex_all()
	if activated == 0:
		_hud.show_message("先買入守衛，才能發動 EX")
		return
	_ex_cooldown_left = EX_COOLDOWN
	_hud.show_message("EX 發動：全線多頭反擊！")
	_refresh_hud()


func _on_unit_dropped(from_index: int, to_index: int) -> void:
	var result := _board.resolve_drop(from_index, to_index, _rng)
	match result["action"]:
		"move":
			_board_view.move_unit(from_index, to_index)
		"swap":
			# 兩個畫面物件要一起搬，不能只呼叫兩次 move_unit，
			# 否則第一次搬完後第二次會找不到來源。
			_board_view.swap_units(from_index, to_index)
		"merge":
			_board_view.remove_unit(from_index)
			_board_view.remove_unit(to_index)
			_board_view.add_unit(to_index, result["kind"], result["tier"])
			_board_view.pop_unit(to_index)
			# 爆點用新階級的顏色，玩家一眼就知道合出了什麼等級
			_spawn_burst(
				Board.cell_center(to_index),
				TierPalette.color_for(result["tier"]),
				14, 52.0, 6.5, 0.45
			)
			_spawn_image_effect(
				MERGE_EFFECT_TEXTURE,
				Board.cell_center(to_index),
				0.095, 0.58
			)
			if result.get("fusion", false):
				_hud.show_message("融合完成：%s" % UnitStats.display_name(result["kind"]))
				_spawn_burst(
					Board.cell_center(to_index),
					Color(0.32, 0.95, 0.50), 24, 86.0, 8.0, 0.7
				)
		_:
			pass


func _on_unit_fired(origin: Vector2, target: Node2D, damage: float, splash: float, color: Color, kind: int) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	_projectiles.add_child(projectile)
	projectile.global_position = origin
	projectile.setup(target, damage, splash, color, kind)
	projectile.impact.connect(_on_projectile_impact)


func _on_unit_ex_fired(origin: Vector2, kind: int, tier: int) -> void:
	var effect := EX_EFFECT_SCENE.instantiate()
	_effects.add_child(effect)
	effect.global_position = origin
	effect.setup(kind, TierPalette.color_for(tier))

	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a, b): return a.progress_ratio > b.progress_ratio)
	var damage := UnitStats.damage(kind, tier)
	var color := TierPalette.color_for(tier)
	match kind:
		UnitStats.Kind.BULL:
			_enemies_take_ex_damage(enemies.slice(0, 1), damage * 2.8, color)
		UnitStats.Kind.GECKO:
			_enemies_take_ex_damage(enemies.slice(0, mini(5, enemies.size())), damage * 1.35, color)
		UnitStats.Kind.DINO:
			_hit_area_or_furthest(enemies, origin, 260.0, damage * 1.8, color)
		UnitStats.Kind.DUO_SHOOTER:
			_enemies_take_ex_damage(enemies.slice(0, mini(8, enemies.size())), damage * 1.7, color)
		UnitStats.Kind.MARKET_TANK:
			_hit_area_or_furthest(enemies, origin, 300.0, damage * 2.4, color)
		UnitStats.Kind.BULL_MARKET_PLANE:
			_enemies_take_ex_damage(enemies, damage * 1.45, color)


func _enemies_take_ex_damage(enemies: Array, damage: float, color: Color) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.take_damage(damage, color)


func _hit_area_or_furthest(enemies: Array, origin: Vector2, radius: float,
		damage: float, color: Color) -> void:
	var hit_count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(origin) <= radius:
			enemy.take_damage(damage, color)
			hit_count += 1
	if hit_count == 0 and not enemies.is_empty() and is_instance_valid(enemies[0]):
		enemies[0].take_damage(damage, color)


# --- 特效 ---

## 特效一律自我銷毀，這裡只負責放到場上。
func _spawn_burst(at: Vector2, color: Color, count: int, radius: float,
		dot_size: float, lifetime: float) -> void:
	var burst := BURST_SCENE.instantiate()
	_effects.add_child(burst)
	burst.global_position = at
	burst.setup(color, count, radius, dot_size, lifetime)


func _spawn_image_effect(texture: Texture2D, at: Vector2, scale_factor: float,
		lifetime: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.global_position = at
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_effects.add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	tween.parallel().tween_property(sprite, "scale",
		Vector2(scale_factor * 1.12, scale_factor * 1.12), lifetime * 0.45)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), lifetime * 0.55)
	# Tween 是視覺動畫；Timer 是回收保證，避免平行 tween 在不同渲染器下
	# 只完成部分序列，讓召喚圖長時間蓋住守衛。
	get_tree().create_timer(lifetime + 0.05).timeout.connect(sprite.queue_free)


func _on_projectile_impact(at: Vector2, kind: int) -> void:
	var frame_width := float(ATTACK_EFFECTS_TEXTURE.get_width()) / 3.0
	var atlas := AtlasTexture.new()
	atlas.atlas = ATTACK_EFFECTS_TEXTURE
	atlas.region = Rect2(frame_width * UnitStats.combat_effect_kind(kind), 0.0,
		frame_width, ATTACK_EFFECTS_TEXTURE.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.global_position = at
	sprite.scale = Vector2(0.075, 0.075)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.95)
	_effects.add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.105, 0.105), 0.12)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.22)
	get_tree().create_timer(0.40).timeout.connect(sprite.queue_free)


func _update_vault_visual() -> void:
	if not is_instance_valid(_vault):
		return
	var state := 0
	if _economy.lives <= 0:
		state = 4
	elif _economy.lives <= 5:
		state = 3
	elif _economy.lives <= 10:
		state = 2
	elif _economy.lives <= 15:
		state = 1
	var frame_width := float(VAULT_STATES_TEXTURE.get_width()) / 5.0
	var atlas := AtlasTexture.new()
	atlas.atlas = VAULT_STATES_TEXTURE
	atlas.region = Rect2(frame_width * state, 0.0, frame_width,
		VAULT_STATES_TEXTURE.get_height())
	_vault.texture = atlas


## 熊市突破金庫時震動並轉紅。失血是這款遊戲唯一的負面事件，
## 沒有回饋的話玩家只會看到數字默默變小。
func _shake_vault() -> void:
	# 多隻敵人同時抵達時，舊的 Tween 必須先停掉，
	# 否則兩組動畫會搶著寫同一個 position，畫面會亂跳。
	if _vault_flash_tween != null and _vault_flash_tween.is_valid():
		_vault_flash_tween.kill()
	if _vault_shake_tween != null and _vault_shake_tween.is_valid():
		_vault_shake_tween.kill()

	var flash := create_tween()
	_vault_flash_tween = flash
	_vault.modulate = VAULT_HIT_COLOR
	flash.tween_property(_vault, "modulate", Color.WHITE, 0.35)

	var home := _vault_home()
	var shake := create_tween()
	_vault_shake_tween = shake
	for i in VAULT_SHAKE_STEPS:
		var offset := Vector2(
			randf_range(-VAULT_SHAKE_OFFSET, VAULT_SHAKE_OFFSET),
			randf_range(-VAULT_SHAKE_OFFSET * 0.7, VAULT_SHAKE_OFFSET * 0.7)
		)
		shake.tween_property(_vault, "position", home + offset, 0.05)
	shake.tween_property(_vault, "position", home, 0.08)


## 軌道終點就是金庫的家。兩條入口路徑最後會在同一個交叉匯流點後
## 合併到中央金庫，從左或右調整路徑時不必另改金庫位置。
func _vault_home() -> Vector2:
	var points := _track_left.curve.get_baked_points()
	return points[points.size() - 1]


# --- 存檔 ---

func _save_best_wave() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		# 存檔失敗不該讓遊戲中斷，記一筆就好
		push_warning("無法寫入最高波次：%s" % error_string(FileAccess.get_open_error()))
		return
	file.store_32(_best_wave)
	file.close()


## 讀取失敗（第一次玩、檔案損毀）時退回 0，不拋錯。
func _load_best_wave() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_best_wave = 0
		return
	_best_wave = file.get_32()
	file.close()

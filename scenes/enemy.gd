extends PathFollow2D

## 一隻熊市入侵者。以 PathFollow2D 沿軌道前進，這是 Godot 處理「沿路徑移動」
## 的標準做法，位置計算完全交給引擎。

## 死亡時把座標一起送出，Main 才知道要在哪裡放爆散特效
signal died(reward: int, at: Vector2)
signal reached_vault(steal: int)
## 累積一小段時間的傷害後才發出，由 Main 生成浮動數字
signal damage_dealt(amount: float, at: Vector2, color: Color)

## 保險用的存活上限。萬一軌道設定出錯導致敵人卡住，
## 沒有這道保險它會永遠留在場上。
const MAX_LIFETIME := 120.0

## 血條與頭頂的間距。實際高度依各自貼圖計算——固定值對最小的快腿
## 會離頭太遠，對最大的大盜又會壓到身上。
const BAR_GAP := 14.0
const BAR_SIZE := Vector2(56.0, 8.0)
const BAR_BACK_COLOR := Color(0.16, 0.16, 0.20, 0.55)
const BAR_FILL_COLOR := Color(0.42, 0.82, 0.44)
const BAR_LOW_COLOR := Color(0.92, 0.35, 0.32)
const BAR_LOW_THRESHOLD := 0.35

const FLASH_COLOR := Color(2.0, 2.0, 2.0)
const FLASH_TIME := 0.14

## 傷害數字的合併視窗。36 隻守衛同時開火時，每一發都跳一個數字會變成
## 滿螢幕雪花；累積這段時間再跳一個，既讀得到數字也看得出輸出量。
const DAMAGE_WINDOW := 0.35

const ENEMY_SHEET := preload("res://assets/generated/stock_bear_enemy_sheet.png")
const BOSS_SHIELD_SHEET := preload("res://assets/generated/stock_boss_shield_states.png")
const SHIELD_FRAME_COUNT := 4

## 行走時的上下擺動，讓敵人不像整張圖在滑
const BOB_SPEED := 9.0
const BOB_HEIGHT := 3.0
const TILT := 0.06

var _hp := 0.0
var _max_hp := 1.0
var _speed := 0.0
var _steal := 1
var _reward := 0
var _finished := false
var _lifetime := 0.0
var _flash_tween: Tween = null
var _bar_offset_y := -BAR_GAP
var _pending_damage := 0.0
var _pending_color := Color.WHITE
var _damage_timer := 0.0
var _kind := WaveTable.EnemyKind.BEAR
var _shield_state := -1

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shield_sprite: Sprite2D = $ShieldSprite


func _ready() -> void:
	loop = false
	rotates = false
	add_to_group("enemy")


func setup(kind: int, wave: int) -> void:
	_kind = kind
	_max_hp = WaveTable.hp_for(kind, wave)
	_hp = _max_hp
	_speed = WaveTable.speed_for(kind)
	_steal = WaveTable.steal_for(kind)
	_reward = Economy.kill_reward(wave)
	# setup 可能在 _ready 之前被呼叫，所以直接取節點而非依賴 @onready
	var sprite: Sprite2D = get_node("Sprite2D")
	sprite.texture = _sheet_frame(ENEMY_SHEET, kind, 7)
	var shield: Sprite2D = get_node("ShieldSprite")
	shield.visible = kind == WaveTable.EnemyKind.BOSS_BEAR
	if shield.visible:
		_set_shield_state(0)
	# 貼圖是置中的，所以半高乘上縮放就是頭頂位置
	var half_height := sprite.texture.get_height() * 0.5 * sprite.scale.y
	_bar_offset_y = -(half_height + BAR_GAP)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	progress += _speed * delta
	_lifetime += delta
	_animate_walk()
	_tick_damage_number(delta)
	if progress_ratio >= 1.0:
		_finish()
		reached_vault.emit(_steal)
	elif _lifetime > MAX_LIFETIME:
		_finish()


func _animate_walk() -> void:
	var phase := _lifetime * BOB_SPEED
	_sprite.position.y = sin(phase) * BOB_HEIGHT
	_sprite.rotation = sin(phase * 0.5) * TILT


func take_damage(amount: float, color: Color = Color.WHITE) -> void:
	if _finished:
		return
	_hp -= amount
	_set_shield_state_from_hp()
	_pending_damage += amount
	_pending_color = color
	_flash()
	queue_redraw()
	if _hp <= 0.0:
		# 死亡前把累積的傷害補跳出來，否則最後那一擊的數字會消失
		_flush_damage_number()
		_finish()
		died.emit(_reward, global_position)


func _tick_damage_number(delta: float) -> void:
	if _pending_damage <= 0.0:
		return
	_damage_timer += delta
	if _damage_timer >= DAMAGE_WINDOW:
		_flush_damage_number()


func _flush_damage_number() -> void:
	if _pending_damage <= 0.0:
		return
	damage_dealt.emit(_pending_damage, global_position, _pending_color)
	_pending_damage = 0.0
	_damage_timer = 0.0


## 受擊瞬間把貼圖打亮再淡回，讓玩家看得出「打中了」。
func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = FLASH_COLOR
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, FLASH_TIME)


func _draw() -> void:
	# 滿血不畫，避免畫面被一排血條塞滿；受傷後才出現反而更醒目
	if _finished or _hp >= _max_hp:
		return
	var ratio := clampf(_hp / _max_hp, 0.0, 1.0)
	var origin := Vector2(-BAR_SIZE.x * 0.5, _bar_offset_y)
	draw_rect(Rect2(origin, BAR_SIZE), BAR_BACK_COLOR)
	var fill_color := BAR_LOW_COLOR if ratio <= BAR_LOW_THRESHOLD else BAR_FILL_COLOR
	draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), fill_color)


func _finish() -> void:
	_finished = true
	remove_from_group("enemy")
	queue_free()


func _sheet_frame(sheet: Texture2D, index: int, frame_count: int) -> AtlasTexture:
	var frame_width := float(sheet.get_width()) / float(frame_count)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(frame_width * index, 0.0, frame_width, sheet.get_height())
	return atlas


func _set_shield_state_from_hp() -> void:
	if _kind != WaveTable.EnemyKind.BOSS_BEAR or _max_hp <= 0.0:
		return
	var ratio := clampf(_hp / _max_hp, 0.0, 1.0)
	var state := 0
	if ratio <= 0.25:
		state = 3
	elif ratio <= 0.50:
		state = 2
	elif ratio <= 0.75:
		state = 1
	_set_shield_state(state)


func _set_shield_state(state: int) -> void:
	if not is_instance_valid(_shield_sprite) or _shield_state == state:
		return
	_shield_state = state
	_shield_sprite.texture = _sheet_frame(BOSS_SHIELD_SHEET, state, SHIELD_FRAME_COUNT)

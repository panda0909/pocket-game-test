extends Node2D

## 一隻守衛：外觀、索敵與開火。

## 開火時發出，由 Main 負責生成投射物——投射物集中管理才好清場。
signal fired(origin: Vector2, target: Node2D, damage: float, splash: float, color: Color, kind: int)
signal ex_fired(origin: Vector2, kind: int, tier: int)

## 角色直接站在方形盤面格上，不再加圓形底框，讓原始輪廓成為視覺焦點。
const BASE_SPRITE_SCALE := 0.14
const SCALE_PER_TIER := 0.005
const TIER_BADGE_RECT := Rect2(30.0, -50.0, 32.0, 30.0)
const TIER_BADGE_COLOR := Color(0.02, 0.04, 0.08, 0.92)
const TIER_BADGE_WIDTH := 3.0
const ATTACK_STATE_DURATION := 0.42
const ATTACK_TARGET_HEIGHT := 108.0
const ATTACK_TARGET_WIDTH := 104.0
const FUSION_TARGET_HEIGHT := 108.0
const FUSION_TARGET_WIDTH := 104.0

## 待機浮動。每隻的相位隨機錯開，否則整片棋盤會像節拍器一起上下。
const BOB_SPEED := 2.4
const BOB_HEIGHT := 2.2
## 開火時朝目標方向前撲再彈回，看得出是誰在攻擊
const LUNGE_DISTANCE := 7.0
const LUNGE_RECOVER := 9.0

var kind: int = UnitStats.Kind.BULL
var tier: int = 1

var _cooldown := 0.0
var _bob_time := 0.0
var _lunge := Vector2.ZERO
var _attack_state_left := 0.0
var _is_attacking := false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _tier_label: Label = $TierLabel


func _ready() -> void:
	# 預設不索敵。由 BoardView 在波次進行中統一開啟。
	set_physics_process(false)
	_bob_time = randf() * TAU


func setup(p_kind: int, p_tier: int) -> void:
	kind = p_kind
	_update_texture(p_tier)
	set_tier(p_tier)


func set_tier(p_tier: int) -> void:
	tier = p_tier
	_update_texture(tier)
	_update_sprite_scale()
	_tier_label.text = "EX" if UnitStats.is_fusion(kind) else str(tier)
	queue_redraw()


func _update_texture(p_tier: int) -> void:
	if _is_attacking:
		var attack_tier_path := UnitStats.attack_tier_texture_path(kind)
		if not attack_tier_path.is_empty():
			var attack_source: Texture2D = load(attack_tier_path)
			if attack_source != null:
				# 攻擊圖同樣是四格橫向排列，讓升階時攻擊姿態、武器與能量一起變化。
				var sheet_tier := clampi(p_tier, 1, 4) - 1
				var frame_width := float(attack_source.get_width()) / 4.0
				var attack_atlas := AtlasTexture.new()
				attack_atlas.atlas = attack_source
				attack_atlas.region = Rect2(
					frame_width * sheet_tier, 0.0, frame_width, attack_source.get_height())
				_sprite.texture = attack_atlas
				return
		var attack_texture: Texture2D = load(UnitStats.attack_texture_path(kind))
		if attack_texture != null:
			_sprite.texture = attack_texture
			return
	if UnitStats.is_fusion(kind):
		_sprite.texture = load(UnitStats.texture_path(kind))
		return
	var tier_path := UnitStats.tier_texture_path(kind)
	if tier_path.is_empty():
		_sprite.texture = load(UnitStats.texture_path(kind))
		return
	var source: Texture2D = load(tier_path)
	if source == null:
		_sprite.texture = load(UnitStats.texture_path(kind))
		return
	# 每張階級稿是四格橫向排列；超過第四階沿用最高階外觀，數值仍可繼續成長。
	var sheet_tier := clampi(p_tier, 1, 4) - 1
	var frame_width := float(source.get_width()) / 4.0
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(frame_width * sheet_tier, 0.0, frame_width, source.get_height())
	_sprite.texture = atlas


func _update_sprite_scale() -> void:
	if _sprite.texture == null:
		return
	if UnitStats.is_fusion(kind):
		var fusion_factor := minf(
			FUSION_TARGET_HEIGHT / float(_sprite.texture.get_height()),
			FUSION_TARGET_WIDTH / float(_sprite.texture.get_width()))
		_sprite.scale = Vector2(fusion_factor, fusion_factor)
		return
	if _is_attacking:
		var attack_factor := minf(
			ATTACK_TARGET_HEIGHT / float(_sprite.texture.get_height()),
			ATTACK_TARGET_WIDTH / float(_sprite.texture.get_width()))
		attack_factor *= UnitStats.attack_scale_multiplier(kind, tier)
		_sprite.scale = Vector2(attack_factor, attack_factor)
		return
	var factor := BASE_SPRITE_SCALE + SCALE_PER_TIER * (tier - 1)
	_sprite.scale = Vector2(factor, factor)


func _set_attack_state(value: bool) -> void:
	if _is_attacking == value:
		return
	_is_attacking = value
	_update_texture(tier)
	_update_sprite_scale()
	_sprite.modulate = UnitStats.attack_tint(kind, tier) if value else Color.WHITE
	queue_redraw()


func activate_ex() -> bool:
	if not is_physics_processing():
		return false
	_attack_state_left = ATTACK_STATE_DURATION
	_set_attack_state(true)
	ex_fired.emit(global_position, kind, tier)
	return true


## 只有在波次進行中才需要索敵，開場與結束畫面關掉以省效能。
func set_active(value: bool) -> void:
	set_physics_process(value)
	if not value:
		_cooldown = 0.0


## 浮動與前撲都寫在這一個地方。分成兩處各自改 position 會互相覆蓋。
func _process(delta: float) -> void:
	_bob_time += delta
	_lunge = _lunge.lerp(Vector2.ZERO, minf(1.0, delta * LUNGE_RECOVER))
	_sprite.position = Vector2(0.0, sin(_bob_time * BOB_SPEED) * BOB_HEIGHT) + _lunge
	if _attack_state_left > 0.0:
		_attack_state_left -= delta
		if _attack_state_left <= 0.0:
			_set_attack_state(false)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_cooldown = UnitStats.attack_interval(kind)
	_attack_state_left = ATTACK_STATE_DURATION
	_set_attack_state(true)
	_lunge = global_position.direction_to(target.global_position) * LUNGE_DISTANCE
	fired.emit(
		global_position, target,
		UnitStats.damage(kind, tier),
		UnitStats.splash_radius(kind),
		TierPalette.color_for(tier),
		kind
	)


func _find_target() -> Node2D:
	var candidates := []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		candidates.append({
			"node": enemy,
			"position": enemy.global_position,
			"progress": enemy.progress_ratio,
		})
	var chosen = Targeting.select(global_position,
		UnitStats.attack_range(kind, tier), candidates)
	if chosen == null:
		return null
	return chosen["node"]


func _draw() -> void:
	# 階級使用方形標籤，避免圓框遮住角色的頭、手與武器。
	draw_rect(TIER_BADGE_RECT, TIER_BADGE_COLOR, true)
	draw_rect(TIER_BADGE_RECT, TierPalette.color_for(tier), false, TIER_BADGE_WIDTH)

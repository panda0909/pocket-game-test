extends Node2D

## 飛向目標的投射物。命中時結算傷害，範圍攻擊另外波及附近敵人。

signal impact(at: Vector2, kind: int)

const SPEED := 780.0
## 目標若在飛行途中死亡或卡住，這道上限確保投射物不會永遠留在場上
const MAX_LIFETIME := 3.0
const RADIUS := 9.0
## 殘影長度。太長會糊成一條線，太短看不出方向。
const TRAIL_LENGTH := 7

var _target: Node2D = null
var _damage := 0.0
var _splash := 0.0
var _color := Color(0.98, 0.78, 0.20)
var _kind := UnitStats.Kind.BULL
var _lifetime := 0.0
var _trail: Array = []


func setup(target: Node2D, damage: float, splash: float, color: Color, kind: int = UnitStats.Kind.BULL) -> void:
	_target = target
	_damage = damage
	_splash = splash
	_color = color
	_kind = kind
	queue_redraw()


func _draw() -> void:
	# 殘影由舊到新畫，愈舊愈小愈淡
	for i in range(_trail.size() - 1, 0, -1):
		var t := float(i) / float(TRAIL_LENGTH)
		draw_circle(
			to_local(_trail[i]),
			RADIUS * (1.0 - t) * 0.85,
			Color(_color.r, _color.g, _color.b, (1.0 - t) * 0.45)
		)
	draw_circle(Vector2.ZERO, RADIUS, _color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, Color(0.12, 0.12, 0.14), 2.0, true)


func _physics_process(delta: float) -> void:
	_lifetime += delta
	# 目標可能在投射物飛行途中就被別的守衛打死，命中前一定要重新檢查
	if _lifetime > MAX_LIFETIME or not is_instance_valid(_target):
		queue_free()
		return
	var to_target := _target.global_position - global_position
	var step := SPEED * delta
	if to_target.length() <= step:
		_hit()
		return
	global_position += to_target.normalized() * step
	_record_trail()
	queue_redraw()


func _record_trail() -> void:
	_trail.push_front(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.resize(TRAIL_LENGTH)


func _hit() -> void:
	impact.emit(global_position, _kind)
	if is_instance_valid(_target):
		_target.take_damage(_damage, _color)
		if _splash > 0.0:
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if enemy == _target or not is_instance_valid(enemy):
					continue
				if enemy.global_position.distance_to(global_position) <= _splash:
					enemy.take_damage(_damage, _color)
	queue_free()

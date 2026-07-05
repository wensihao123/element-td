class_name Weapon
extends Node

## 武器组件(PLAN 04):纯冷却计时,无状态机——要蓄力/多段/模式切换先过
## /state-machine-master(PLAN §5)。def 派生参数由塔根 setup 注入(距离/速度已换算 px)。
## 冷却初始 0:有目标即首发,之后每 fire_interval 一发;目标持有直到失效/出射程才经
## 兄弟 Targeting 重索(D5,附着顺序可预测)。开火 = 调兄弟 ProjectileSpawner.spawn(
## target, payload),payload 携带弹丸结算所需全部参数,source = 塔根(反应归属,契约①)。
## _physics_process 委托 tick(03 手动驱动先例);headless 测试手动 tick 确定性。

var range_px: float = 0.0
var speed_px: float = 0.0
var damage: float = 0.0
var fire_interval: float = 0.0
var element: ElementDef = null
var attach_amount: float = 0.0
## 塔根节点:索敌圆心 + 伤害/反应归属;空字段 _ready 自接线父节点(塔根即父,D4)
var source: Node2D = null

var _target: Node2D = null
var _cooldown: float = 0.0


func _ready() -> void:
	if source == null:
		source = get_parent() as Node2D


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not _is_target_valid():
		_target = _reacquire()
	if _target == null or _cooldown > 0.0:
		return
	var spawner: Node = _sibling("ProjectileSpawner")
	if spawner == null:
		push_warning("Weapon:缺少兄弟节点 ProjectileSpawner,开火丢弃")
		return
	spawner.call(&"spawn", _target, _build_payload())
	_cooldown = fire_interval


func _build_payload() -> Dictionary:
	return {
		"speed_px": speed_px,
		"damage": damage,
		"element": element,
		"attach_amount": attach_amount,
		"source": source,
	}


func _is_target_valid() -> bool:
	if _target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion():
		return false
	if source == null:
		return false
	return _target.global_position.distance_to(source.global_position) <= range_px


func _reacquire() -> Node2D:
	var targeting: Node = _sibling("Targeting")
	if targeting == null:
		push_warning("Weapon:缺少兄弟节点 Targeting,无法索敌")
		return null
	return targeting.call(&"acquire", source, range_px) as Node2D


func _sibling(sibling_name: String) -> Node:
	var parent: Node = get_parent()
	return parent.get_node_or_null(sibling_name) if parent != null else null

class_name Projectile
extends Node2D

## 弹丸(PLAN 04-D6/D7):追踪目标节点;目标失效(死亡/被释放)→ queue_free,
## 不追尸不换目标;命中判定 = 本帧位移 ≥ 到目标剩余距离(纯几何,无 magic 命中半径)。
## 命中结算顺序(D6):目标已 is_queued_for_deletion 则整个命中丢弃(02 use-after-free
## 铁律的弹丸侧延伸);否则先 StatusComponent.apply_element(可能触发反应——击杀弹也能
## 触发,支柱 1 补刀爽点)再 take_damage(反应先杀死目标时直伤被 03 终态 guard 吸收,
## 不双记账),然后 queue_free。hit_direction 传飞行方向归一化(契约②,过载击退用)。
## 出生位置 = source 塔根全局坐标(挂 ProjectileSpawner——纯 Node 无变换,须显式设)。
## _physics_process 委托 tick;headless 测试手动 tick 确定性。占位视觉按元素染色(05 正式)。

var target: Node2D = null
var speed_px: float = 0.0
var damage: float = 0.0
var element: ElementDef = null
var attach_amount: float = 0.0
var source: Node = null


## 生成方在 add_child 前调用(ProjectileSpawner.spawn 透传 Weapon payload)。
func setup(new_target: Node2D, new_speed_px: float, new_damage: float,
		new_element: ElementDef, new_attach_amount: float, new_source: Node) -> void:
	target = new_target
	speed_px = new_speed_px
	damage = new_damage
	element = new_element
	attach_amount = new_attach_amount
	source = new_source


func _ready() -> void:
	var origin: Node2D = source as Node2D
	if origin != null:
		global_position = origin.global_position
	_tint_visual()


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return
	var to_target: Vector2 = target.global_position - global_position
	var remaining: float = to_target.length()
	var step: float = speed_px * delta
	if step >= remaining:
		_hit(to_target)
		return
	global_position += to_target * (step / remaining)


func _hit(to_target: Vector2) -> void:
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		var hit_direction: Vector2 = to_target.normalized()
		var status: StatusComponent = target.get_node_or_null("StatusComponent") as StatusComponent
		if status != null and element != null:
			status.apply_element(element, attach_amount, source, hit_direction)
		if target.has_method("take_damage"):
			target.call("take_damage", damage, source)
	queue_free()


## 占位视觉:小色点按元素染色;正式可视化归 05。
func _tint_visual() -> void:
	var visual: Polygon2D = get_node_or_null("Visual") as Polygon2D
	if visual != null and element != null:
		visual.color = element.color

class_name StatusComponent
extends Node

## 敌人元素状态簿记 + base status 生命周期(PLAN 02-D5/D8)。
## 每敌最多 1 种元素;gauge > 0 期间 base_status 持续生效(经宿主 ActiveEffects
## 注册、handle_sink 收句柄),归零过期逐句柄 cancel 回滚。
## cfg / reaction_system 为注入字段(D1),不依赖 autoload;宿主 = 父节点(D7)。
## 异元素命中仅转发 ReactionSystem.try_react(《项目说明》§4.3 明定管线);
## ICD 拦截与设值归 ReactionSystem(D9),本组件只存放/递减 icd_remaining。
## 行数超《项目说明》「~20 行」指导值:多了 ICD/衰减/生命周期,职责仍单一
## (gauge 簿记 + 状态生命周期,PLAN Phase 3 gate 声明)。

signal status_started(element: ElementDef)
signal status_expired(element: ElementDef)

var element: ElementDef = null
var gauge: float = 0.0
var icd_remaining: float = 0.0

var cfg: GaugeConfig = null
var reaction_system: Node = null

var _base_handles: Array[int] = []


func _physics_process(delta: float) -> void:
	tick(delta)


func apply_element(incoming: ElementDef, amount: float, source: Node,
		hit_direction: Vector2 = Vector2.ZERO) -> void:
	if incoming == null or cfg == null:
		push_warning("apply_element 需要 incoming 元素与注入的 cfg")
		return
	if element == null:
		element = incoming
		gauge = clampf(amount, 0.0, cfg.max_gauge)
		_apply_base_status(source, hit_direction)
		status_started.emit(element)
	elif element == incoming:
		gauge = clampf(gauge + amount, 0.0, cfg.max_gauge)
	elif reaction_system != null:
		reaction_system.call("try_react", self, incoming, source, hit_direction)
	else:
		push_warning("异元素命中但未注入 reaction_system,丢弃")


## 扣元素量(反应消耗走这里,D9);扣到 ≤ 0 即过期回滚。
func consume(amount: float) -> void:
	gauge -= amount
	if gauge <= 0.0:
		gauge = 0.0
		_expire()


func tick(delta: float) -> void:
	icd_remaining = maxf(0.0, icd_remaining - delta)
	if element != null and cfg != null and cfg.decay_per_sec > 0.0:
		gauge -= cfg.decay_per_sec * delta
		if gauge <= 0.0:
			gauge = 0.0
			_expire()


func _apply_base_status(source: Node, hit_direction: Vector2) -> void:
	var host: Node = get_parent()
	var ctx: Dictionary = {
		"source": source,
		"element": element,
		"hit_direction": hit_direction,
		"handle_sink": _base_handles,
	}
	for fx: ReactionEffect in element.base_status:
		fx.apply(host, ctx)


func _expire() -> void:
	if element == null:
		return
	var expired_element: ElementDef = element
	var active: ActiveEffects = get_parent().get_node_or_null("ActiveEffects") as ActiveEffects
	if active != null:
		for handle: int in _base_handles:
			active.cancel(handle)
	_base_handles.clear()
	element = null
	status_expired.emit(expired_element)

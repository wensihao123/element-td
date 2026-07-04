class_name ReactionEffect
extends Resource

## 反应效果积木基类(PLAN 02-D3 享元模式):效果 Resource 是共享实例,只当
## 「参数 + 逻辑」,自身零字段写入;一切逐宿主可变状态住宿主的 ActiveEffects
## 组件,由 on_start 返回的 state 字典承载,on_tick / on_end 只读写该字典。
## apply(target, ctx) 是唯一分发入口:瞬发效果在 apply 内执行完毕,
## 持续型效果在 apply 内把自己注册进 target 的 ActiveEffects。
##
## ctx 标准键(契约,PLAN 02):
## - "source": Node —— 归属塔(反应伤害记给触发方,铁律)
## - "reaction": ReactionDef 或 "element": ElementDef —— 触发来源
## - "hit_direction": Vector2 —— 默认 Vector2.ZERO;PropagateEffect 对每个邻居
##   浅拷贝 ctx 并把方向覆写为「主目标 → 邻居」
## - "handle_sink": Array[int](可选,仅 base status 路径)—— 收集句柄供回滚

## 敌人实体所在的 SceneTree 组(D6 空间查询;代码常量,标识符非数值)。
const ENEMY_GROUP: StringName = &"enemies"


func apply(_target: Node, _ctx: Dictionary) -> void:
	pass


## 持续型接口:被 ActiveEffects.register 回调,返回本次施加的私有 state 字典。
func on_start(_target: Node, _ctx: Dictionary) -> Dictionary:
	return {}


func on_tick(_target: Node, _state: Dictionary, _delta: float) -> void:
	pass


func on_end(_target: Node, _state: Dictionary) -> void:
	pass


## D7 组件发现约定:实体根的具名直接子节点;查无返回 null 并 push_warning(fail-soft)。
func _stack(target: Node) -> ModifierStack:
	return _component(target, "ModifierStack") as ModifierStack


func _active(target: Node) -> ActiveEffects:
	return _component(target, "ActiveEffects") as ActiveEffects


func _component(target: Node, component_name: String) -> Node:
	var node: Node = target.get_node_or_null(component_name) if target != null else null
	if node == null:
		push_warning("目标 %s 缺少 %s 组件" %
				[target.name if target != null else "<null>", component_name])
	return node


## D6 空间查询:&"enemies" 组线性扫描 + 距离过滤;含圆心自身(Propagate 自行剔除主目标)。
func _enemies_in_radius(around: Node2D, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if around == null or not around.is_inside_tree():
		push_warning("空间查询要求圆心节点在场景树内")
		return result
	for node: Node in around.get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy: Node2D = node as Node2D
		if enemy != null and enemy.global_position.distance_to(around.global_position) <= radius:
			result.append(enemy)
	return result


## handle_sink 契约:base status 路径收集句柄,gauge 归零时逐句柄 cancel 回滚。
func _collect_handle(ctx: Dictionary, handle: int) -> void:
	if ctx.has("handle_sink"):
		var sink: Array[int] = ctx["handle_sink"]
		sink.append(handle)


## D10 鸭子契约投递:take_damage(amount: float, source: Node) 由 03 的
## HealthComponent 落地;查无方法 push_warning 不崩(fail-soft)。
func _deal_damage(target: Node, amount: float, source: Node) -> void:
	if target != null and target.has_method("take_damage"):
		target.call("take_damage", amount, source)
	else:
		push_warning("目标 %s 缺少 take_damage 方法,伤害丢弃" %
				(target.name if target != null else "<null>"))

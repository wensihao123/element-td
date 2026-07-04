class_name StubEnemy
extends Node2D

## 测试支撑:最小敌人实体。入 &"enemies" 组(D6)、挂 D7 具名子组件,
## 记录 take_damage / apply_knockback 鸭子调用(D10)供断言;
## 正式 HealthComponent / 护甲结算归 03,02 的伤害断言在「调用面」。

var damage_calls: Array[Dictionary] = []
var knockback_calls: Array[Dictionary] = []


func _init() -> void:
	add_to_group(ReactionEffect.ENEMY_GROUP)
	var stack: ModifierStack = ModifierStack.new()
	stack.name = "ModifierStack"
	add_child(stack)
	var active: ActiveEffects = ActiveEffects.new()
	active.name = "ActiveEffects"
	add_child(active)
	var status_component: StatusComponent = StatusComponent.new()
	status_component.name = "StatusComponent"
	add_child(status_component)


func take_damage(amount: float, source: Node) -> void:
	damage_calls.append({"amount": amount, "source": source})


func apply_knockback(distance: float, direction: Vector2) -> void:
	knockback_calls.append({"distance": distance, "direction": direction})


func stack() -> ModifierStack:
	return get_node("ModifierStack") as ModifierStack


func active() -> ActiveEffects:
	return get_node("ActiveEffects") as ActiveEffects


func status() -> StatusComponent:
	return get_node("StatusComponent") as StatusComponent

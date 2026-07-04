class_name HealthComponent
extends Node

## 血量 + 护甲结算(PLAN 03-D3/D4):敌人根的第四个具名直接子组件。
## max_hp / base_armor 由外部注入(来源 EnemyDef,经敌人根 setup),hp 为运行时值。
## 护甲公式(D3):final = maxf(amount - armor, 0.0) * resolve(&"damage_taken", 1.0),
## 其中 armor = resolve(&"armor", base_armor);负护甲天然增伤(毒腐蚀的战术价值)。
## hp ≤ 0 后再伤直接 return,died 恰发一次;本组件不调 free/queue_free——自毁归根脚本
## (02 REVIEW:迭代中同步释放 = use-after-free)。

signal died

var max_hp: float = 0.0
var base_armor: float = 0.0
var hp: float = 0.0


func take_damage(amount: float, _source: Node) -> void:
	if hp <= 0.0:
		return
	var armor: float = base_armor
	var taken_multiplier: float = 1.0
	var stack: ModifierStack = _stack()
	if stack != null:
		armor = stack.resolve(&"armor", base_armor)
		taken_multiplier = stack.resolve(&"damage_taken", 1.0)
	hp -= maxf(amount - armor, 0.0) * taken_multiplier
	if hp <= 0.0:
		hp = 0.0
		died.emit()


## D7 兄弟组件发现:同宿主具名子节点;查无 fail-soft 用 base 值(不 warning——
## 独立单测无宿主是合法场景)。
func _stack() -> ModifierStack:
	var parent: Node = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("ModifierStack") as ModifierStack

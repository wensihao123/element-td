class_name AoeDamageEffect
extends ReactionEffect

## 以命中点为圆心的范围伤害(清杂/爆发)。
## 半径内组员**含主目标**逐个投伤(D6 组扫描;传播语义归 PropagateEffect)。

@export var damage: float = 0.0
@export var radius: float = 0.0


func apply(target: Node, ctx: Dictionary) -> void:
	var center: Node2D = target as Node2D
	if center == null:
		push_warning("AoeDamageEffect 要求目标为 Node2D")
		return
	for enemy: Node2D in _enemies_in_radius(center, radius):
		_deal_damage(enemy, damage, ctx.get("source"))

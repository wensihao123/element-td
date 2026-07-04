class_name PropagateEffect
extends ReactionEffect

## 包装 inner 效果并施加给半径内的周围敌人;**不含主目标**(D7)——
## 需要主目标同吃效果时,在 effects 数组里并列一个未包装的同类效果。
## 对每个邻居浅拷贝 ctx 并把 hit_direction 覆写为「主目标 → 邻居」(ctx 契约);
## handle_sink 属主目标 base status 路径,传播前剔除,邻居句柄不得混入主目标回滚账(02 flag ②)。

@export var inner: ReactionEffect
@export var radius: float = 0.0


func apply(target: Node, ctx: Dictionary) -> void:
	if inner == null:
		push_warning("PropagateEffect.inner 为空,传播丢弃")
		return
	var center: Node2D = target as Node2D
	if center == null:
		push_warning("PropagateEffect 要求目标为 Node2D")
		return
	for enemy: Node2D in _enemies_in_radius(center, radius):
		if enemy == center:
			continue
		var neighbor_ctx: Dictionary = ctx.duplicate(false)
		neighbor_ctx.erase("handle_sink")
		neighbor_ctx["hit_direction"] = \
				(enemy.global_position - center.global_position).normalized()
		inner.apply(enemy, neighbor_ctx)

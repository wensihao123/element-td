class_name KnockbackEffect
extends ReactionEffect

## 沿命中方向击退目标(位移控制)。
## 鸭子契约 apply_knockback(distance: float, direction: Vector2) 由 03/04 落地
## 真实位移语义(路径进度回退);02 只投递调用(D10)。

@export var distance: float = 0.0


func apply(target: Node, ctx: Dictionary) -> void:
	if target != null and target.has_method("apply_knockback"):
		target.call("apply_knockback", distance, ctx.get("hit_direction", Vector2.ZERO))
	else:
		push_warning("目标 %s 缺少 apply_knockback 方法,击退丢弃" %
				(target.name if target != null else "<null>"))

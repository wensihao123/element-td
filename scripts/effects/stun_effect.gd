class_name StunEffect
extends ReactionEffect

## 眩晕/冻结:目标停止行动 duration 秒(硬控)。
## 实现 = 保留键 &"stunned" 上 flat +1 计数(D4;+1 是布尔计数编码,非平衡数值),
## resolve(&"stunned", 0.0) > 0.0 即眩晕——重叠控制先到期的不误清后者。

@export var duration: float = 0.0


func apply(target: Node, ctx: Dictionary) -> void:
	var active: ActiveEffects = _active(target)
	if active == null:
		return
	_collect_handle(ctx, active.register(self, ctx, duration))


func on_start(target: Node, _ctx: Dictionary) -> Dictionary:
	var stack: ModifierStack = _stack(target)
	if stack == null:
		return {}
	return {"stack": stack, "handle": stack.add(&"stunned", 1.0, 0.0)}


func on_end(_target: Node, state: Dictionary) -> void:
	if state.has("handle"):
		var stack: ModifierStack = state["stack"]
		stack.remove(int(state["handle"]))

class_name StatModifierEffect
extends ReactionEffect

## 属性修饰(运行时经 ModifierStack 生效,永不改写 .tres 字段)。
## duration = -1.0 表示随元素状态存续(gauge > 0 期间生效,见 PLAN D4)。
## on_start 挂栈存句柄入 state,on_end 摘除——回滚不依赖效果自省(D3)。

@export var stat: StringName = &""
@export var add_flat: float = 0.0
@export var add_percent: float = 0.0
@export var duration: float = -1.0


func apply(target: Node, ctx: Dictionary) -> void:
	var active: ActiveEffects = _active(target)
	if active == null:
		return
	_collect_handle(ctx, active.register(self, ctx, duration))


func on_start(target: Node, _ctx: Dictionary) -> Dictionary:
	var stack: ModifierStack = _stack(target)
	if stack == null:
		return {}
	return {"stack": stack, "handle": stack.add(stat, add_flat, add_percent)}


func on_end(_target: Node, state: Dictionary) -> void:
	if state.has("handle"):
		var stack: ModifierStack = state["stack"]
		stack.remove(int(state["handle"]))

class_name DotEffect
extends ReactionEffect

## 持续伤害:每 tick_interval 秒结算一次 take_damage(dps * tick_interval, source);
## 首跳在满一个间隔后;duration = -1.0 表示随元素状态存续。
## 享元(D3):累加器住 state,不写自身字段。

@export var dps: float = 0.0
@export var duration: float = -1.0
@export var tick_interval: float = 0.0


func apply(target: Node, ctx: Dictionary) -> void:
	var active: ActiveEffects = _active(target)
	if active == null:
		return
	_collect_handle(ctx, active.register(self, ctx, duration))


func on_start(_target: Node, ctx: Dictionary) -> Dictionary:
	return {"source": ctx.get("source"), "accum": 0.0}


func on_tick(target: Node, state: Dictionary, delta: float) -> void:
	if tick_interval <= 0.0:
		return
	var accum: float = float(state["accum"]) + delta
	while accum >= tick_interval:
		accum -= tick_interval
		_deal_damage(target, dps * tick_interval, state.get("source"))
	state["accum"] = accum

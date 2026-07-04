class_name ActiveEffects
extends Node

## 持续型效果的运行时载体(PLAN 02-D3):效果 Resource 是共享享元、自身零状态,
## 每次施加的私有 state 字典住本组件条目里,天然逐宿主隔离。
## 本组件是唯一计时权威(D4):remaining 到期回调 fx.on_end 后移除;
## duration = -1.0 表示永续,直至 cancel(base status 随 gauge 存续即此路径)。
## 宿主 = 父节点(D7 具名子节点约定);headless 测试手动调 tick,确定性。

var _entries: Dictionary = {}
var _next_handle: int = 1


func _physics_process(delta: float) -> void:
	tick(delta)


## 注册一条持续型效果,回调 fx.on_start 取得本次施加的私有 state,返回句柄。
func register(fx: ReactionEffect, ctx: Dictionary, duration: float) -> int:
	var handle: int = _next_handle
	_next_handle += 1
	var state: Dictionary = fx.on_start(_host(), ctx)
	_entries[handle] = {"fx": fx, "state": state, "remaining": duration}
	return handle


## 终止并移除一条效果(回调 on_end);对已不存在的句柄幂等。
func cancel(handle: int) -> void:
	if not _entries.has(handle):
		return
	var entry: Dictionary = _entries[handle]
	_entries.erase(handle)
	var fx: ReactionEffect = entry["fx"]
	fx.on_end(_host(), entry["state"])


func tick(delta: float) -> void:
	for handle: int in _entries.keys():
		if not _entries.has(handle):
			continue
		var entry: Dictionary = _entries[handle]
		var fx: ReactionEffect = entry["fx"]
		fx.on_tick(_host(), entry["state"], delta)
		var remaining: float = entry["remaining"]
		if remaining >= 0.0:
			remaining -= delta
			entry["remaining"] = remaining
			if remaining <= 0.0:
				cancel(handle)


func _host() -> Node:
	return get_parent()

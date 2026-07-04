extends TestCase

## ActiveEffects 单测(PLAN 02 Phase 2):定时到期、-1 永续、cancel 幂等、
## 享元隔离(flag ① 回归:同一 fx 资源注册到两个宿主,state 互不串)。


## 探针效果:私有状态住 state 字典,观测值写宿主 meta 供断言;自身零字段写入。
class ProbeEffect:
	extends ReactionEffect

	func on_start(_target: Node, _ctx: Dictionary) -> Dictionary:
		return {"elapsed": 0.0}

	func on_tick(target: Node, state: Dictionary, delta: float) -> void:
		state["elapsed"] = float(state["elapsed"]) + delta
		target.set_meta("probe_elapsed", state["elapsed"])

	func on_end(target: Node, _state: Dictionary) -> void:
		var count: int = int(target.get_meta("probe_end_count", 0))
		target.set_meta("probe_end_count", count + 1)


func _new_host() -> Node2D:
	var host: Node2D = Node2D.new()
	var active: ActiveEffects = ActiveEffects.new()
	active.name = "ActiveEffects"
	host.add_child(active)
	return host


func _active_of(host: Node2D) -> ActiveEffects:
	return host.get_node("ActiveEffects") as ActiveEffects


func test_timed_expiry_calls_on_end_and_removes() -> void:
	var host: Node2D = _new_host()
	var active: ActiveEffects = _active_of(host)
	var fx: ProbeEffect = ProbeEffect.new()
	active.register(fx, {}, 1.0)
	active.tick(0.5)
	assert_eq(host.get_meta("probe_end_count", 0), 0, "未到期不应触发 on_end")
	active.tick(0.5)
	assert_eq(host.get_meta("probe_end_count", 0), 1, "到期应恰好触发一次 on_end")
	active.tick(0.5)
	assert_eq(host.get_meta("probe_elapsed"), 1.0, "到期移除后不应再 on_tick")
	assert_eq(host.get_meta("probe_end_count", 0), 1, "到期移除后不应再 on_end")
	host.free()


func test_negative_duration_persists_until_cancel() -> void:
	var host: Node2D = _new_host()
	var active: ActiveEffects = _active_of(host)
	var fx: ProbeEffect = ProbeEffect.new()
	var handle: int = active.register(fx, {}, -1.0)
	for i: int in range(4):
		active.tick(0.5)
	assert_eq(host.get_meta("probe_elapsed"), 2.0, "-1 永续应持续 on_tick")
	assert_eq(host.get_meta("probe_end_count", 0), 0, "-1 永续不应自行到期")
	active.cancel(handle)
	assert_eq(host.get_meta("probe_end_count", 0), 1, "cancel 应触发 on_end")
	active.tick(0.5)
	assert_eq(host.get_meta("probe_elapsed"), 2.0, "cancel 后不应再 on_tick")
	host.free()


func test_cancel_is_idempotent() -> void:
	var host: Node2D = _new_host()
	var active: ActiveEffects = _active_of(host)
	var fx: ProbeEffect = ProbeEffect.new()
	var handle: int = active.register(fx, {}, -1.0)
	active.cancel(handle)
	active.cancel(handle)
	assert_eq(host.get_meta("probe_end_count", 0), 1, "重复 cancel 同句柄应幂等")
	host.free()


func test_shared_fx_state_isolated_per_host() -> void:
	var fx: ProbeEffect = ProbeEffect.new()
	var host_a: Node2D = _new_host()
	var host_b: Node2D = _new_host()
	_active_of(host_a).register(fx, {}, -1.0)
	_active_of(host_b).register(fx, {}, -1.0)
	for i: int in range(3):
		_active_of(host_a).tick(0.5)
	_active_of(host_b).tick(0.5)
	assert_eq(host_a.get_meta("probe_elapsed"), 1.5, "宿主 A 的 state 应独立累计")
	assert_eq(host_b.get_meta("probe_elapsed"), 0.5, "宿主 B 的 state 不应被 A 污染")
	host_a.free()
	host_b.free()

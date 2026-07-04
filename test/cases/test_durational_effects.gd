extends TestCase

## 持续型效果单测(PLAN 02 Phase 2):DotEffect 按 tick 精确出伤、
## StatModifierEffect 到期回滚、双眩晕重叠不误清。
## 效果字段为测试脚手架合成值;期望值一律从字段推导,不另抄字面量。


## 最小宿主:具名子组件 + take_damage 调用记录(正式 StubEnemy 归下一步)。
class RecordingHost:
	extends Node2D

	var damage_calls: Array[Dictionary] = []

	func _init() -> void:
		var stack: ModifierStack = ModifierStack.new()
		stack.name = "ModifierStack"
		add_child(stack)
		var active: ActiveEffects = ActiveEffects.new()
		active.name = "ActiveEffects"
		add_child(active)

	func take_damage(amount: float, source: Node) -> void:
		damage_calls.append({"amount": amount, "source": source})

	func stack() -> ModifierStack:
		return get_node("ModifierStack") as ModifierStack

	func active() -> ActiveEffects:
		return get_node("ActiveEffects") as ActiveEffects


func test_dot_ticks_exact_damage() -> void:
	var host: RecordingHost = RecordingHost.new()
	var tower: Node = Node.new()
	var fx: DotEffect = DotEffect.new()
	fx.dps = 8.0
	fx.duration = 2.0
	fx.tick_interval = 0.5
	fx.apply(host, {"source": tower})
	assert_eq(host.damage_calls.size(), 0, "首跳应在满一个间隔后,施加瞬间不出伤")
	host.active().tick(fx.tick_interval)
	assert_eq(host.damage_calls.size(), 1, "满一个间隔应出第一跳")
	var expected_ticks: int = int(fx.duration / fx.tick_interval)
	for i: int in range(expected_ticks - 1):
		host.active().tick(fx.tick_interval)
	assert_eq(host.damage_calls.size(), expected_ticks, "duration 内应恰好出满每跳")
	for call: Dictionary in host.damage_calls:
		assert_eq(call["amount"], fx.dps * fx.tick_interval, "每跳伤害应为 dps*tick_interval")
		assert_true(call["source"] == tower, "伤害 source 应透传归属塔")
	host.active().tick(fx.tick_interval)
	assert_eq(host.damage_calls.size(), expected_ticks, "到期移除后不应再出伤")
	host.free()
	tower.free()


func test_stat_modifier_applies_then_rolls_back() -> void:
	var host: RecordingHost = RecordingHost.new()
	var fx: StatModifierEffect = StatModifierEffect.new()
	fx.stat = &"speed"
	fx.add_percent = -0.3
	fx.duration = 1.0
	fx.apply(host, {})
	var base_speed: float = 100.0
	assert_eq(host.stack().resolve(&"speed", base_speed),
			base_speed * (1.0 + fx.add_percent), "生效期间应按 add_percent 修饰")
	host.active().tick(fx.duration)
	assert_eq(host.stack().resolve(&"speed", base_speed), base_speed,
			"到期应回滚复原 base")
	host.free()


func test_double_stun_overlap_counts_correctly() -> void:
	var host: RecordingHost = RecordingHost.new()
	var freeze: StunEffect = StunEffect.new()
	freeze.duration = 1.5
	var paralyze: StunEffect = StunEffect.new()
	paralyze.duration = 1.0
	freeze.apply(host, {})
	paralyze.apply(host, {})
	assert_true(host.stack().resolve(&"stunned", 0.0) > 0.0, "双控重叠期间应处于眩晕")
	host.active().tick(paralyze.duration)
	assert_true(host.stack().resolve(&"stunned", 0.0) > 0.0,
			"先到期的电解解除不应误清冻结(还剩 0.5s)")
	host.active().tick(freeze.duration - paralyze.duration)
	assert_eq(host.stack().resolve(&"stunned", 0.0), 0.0, "全部到期后应脱离眩晕")
	host.free()

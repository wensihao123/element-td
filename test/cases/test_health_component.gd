extends TestCase

## HealthComponent 单测(PLAN 03 Phase 1):减法护甲、负甲增伤、脆化后乘、
## died 恰一次、死后免疫、无 ModifierStack 兄弟 fail-soft。
## 哨兵值非游戏数值;组件不入树也不依赖 autoload,纯本地构造。


func _make_host(max_hp: float, base_armor: float, with_stack: bool = true) -> Dictionary:
	var host: Node = Node.new()
	if with_stack:
		var stack: ModifierStack = ModifierStack.new()
		stack.name = "ModifierStack"
		host.add_child(stack)
	var health: HealthComponent = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_hp = max_hp
	health.base_armor = base_armor
	health.hp = max_hp
	host.add_child(health)
	return {"host": host, "health": health}


func _stack_of(rig: Dictionary) -> ModifierStack:
	return (rig["host"] as Node).get_node("ModifierStack") as ModifierStack


func _cleanup(rig: Dictionary) -> void:
	(rig["host"] as Node).free()


func test_subtractive_armor() -> void:
	var rig: Dictionary = _make_host(100.0, 2.0)
	var health: HealthComponent = rig["health"]
	health.take_damage(5.0, null)
	assert_true(is_equal_approx(health.hp, 97.0),
			"armor 2 / amount 5 应扣 3(实际 hp:%s)" % str(health.hp))
	_cleanup(rig)


func test_negative_armor_amplifies() -> void:
	var rig: Dictionary = _make_host(100.0, 0.0)
	var health: HealthComponent = rig["health"]
	_stack_of(rig).add(&"armor", -2.0, 0.0)
	health.take_damage(5.0, null)
	assert_true(is_equal_approx(health.hp, 93.0),
			"armor resolve -2 / amount 5 应扣 7(实际 hp:%s)" % str(health.hp))
	_cleanup(rig)


func test_damage_taken_multiplier_after_armor() -> void:
	var rig: Dictionary = _make_host(100.0, 2.0)
	var health: HealthComponent = rig["health"]
	_stack_of(rig).add(&"damage_taken", 0.4, 0.0)
	health.take_damage(5.0, null)
	assert_true(is_equal_approx(health.hp, 95.8),
			"armor 2 / amount 5 / damage_taken 1.4 应扣 4.2 = (5-2)*1.4(实际 hp:%s)" % str(health.hp))
	_cleanup(rig)


func test_died_emits_exactly_once() -> void:
	var rig: Dictionary = _make_host(5.0, 0.0)
	var health: HealthComponent = rig["health"]
	var died_count: Array[int] = [0]
	health.died.connect(func() -> void: died_count[0] += 1)
	health.take_damage(5.0, null)
	assert_eq(health.hp, 0.0, "致死伤害后 hp 应钉在 0")
	assert_eq(died_count[0], 1, "扣到 0 时 died 应恰发一次")
	_cleanup(rig)


func test_dead_ignores_further_damage() -> void:
	var rig: Dictionary = _make_host(5.0, 0.0)
	var health: HealthComponent = rig["health"]
	var died_count: Array[int] = [0]
	health.died.connect(func() -> void: died_count[0] += 1)
	health.take_damage(10.0, null)
	health.take_damage(10.0, null)
	assert_eq(health.hp, 0.0, "死后再伤血量应不变")
	assert_eq(died_count[0], 1, "死后再伤 died 不得重发")
	_cleanup(rig)


func test_fail_soft_without_modifier_stack() -> void:
	var rig: Dictionary = _make_host(100.0, 2.0, false)
	var health: HealthComponent = rig["health"]
	health.take_damage(5.0, null)
	assert_true(is_equal_approx(health.hp, 97.0),
			"无 ModifierStack 兄弟应 fail-soft 用 base_armor(实际 hp:%s)" % str(health.hp))
	_cleanup(rig)

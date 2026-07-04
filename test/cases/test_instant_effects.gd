extends TestCase

## 瞬发效果单测(PLAN 02 Phase 2):AoE 半径判定含主目标、击退鸭子调用、
## 传播剔除主目标 + 方向覆写 + inner 持续型注册进邻居。
## 组扫描需在场景树内:借测试跑道 SceneTree 的 root 挂 StubEnemy,用完即清
## (不清会污染同进程后续用例的 &"enemies" 组)。


func _tree_root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _add_enemy(pos: Vector2) -> StubEnemy:
	var enemy: StubEnemy = StubEnemy.new()
	enemy.position = pos
	_tree_root().add_child(enemy)
	return enemy


func _cleanup(nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func test_aoe_hits_radius_including_main_target() -> void:
	var main: StubEnemy = _add_enemy(Vector2.ZERO)
	var near: StubEnemy = _add_enemy(Vector2(50.0, 0.0))
	var far: StubEnemy = _add_enemy(Vector2(150.0, 0.0))
	var tower: Node = Node.new()
	var fx: AoeDamageEffect = AoeDamageEffect.new()
	fx.damage = 25.0
	fx.radius = 100.0
	fx.apply(main, {"source": tower})
	assert_eq(main.damage_calls.size(), 1, "AoE 应含主目标")
	assert_eq(near.damage_calls.size(), 1, "半径内邻居应受伤")
	assert_eq(far.damage_calls.size(), 0, "半径外不应受伤")
	if not main.damage_calls.is_empty():
		assert_eq(main.damage_calls[0]["amount"], fx.damage, "伤害量应为效果字段值")
		assert_true(main.damage_calls[0]["source"] == tower, "source 应透传归属塔")
	_cleanup([main, near, far, tower])


func test_knockback_delivers_duck_call() -> void:
	var enemy: StubEnemy = StubEnemy.new()
	var fx: KnockbackEffect = KnockbackEffect.new()
	fx.distance = 48.0
	fx.apply(enemy, {"hit_direction": Vector2.RIGHT})
	assert_eq(enemy.knockback_calls.size(), 1, "应投递一次击退")
	if not enemy.knockback_calls.is_empty():
		assert_eq(enemy.knockback_calls[0]["distance"], fx.distance, "击退距离应为字段值")
		assert_eq(enemy.knockback_calls[0]["direction"], Vector2.RIGHT, "方向应取 ctx.hit_direction")
	var bare: Node = Node.new()
	fx.apply(bare, {})
	assert_true(true, "缺 apply_knockback 方法应 fail-soft 不崩")
	enemy.free()
	bare.free()


func test_propagate_excludes_main_and_overrides_direction() -> void:
	var main: StubEnemy = _add_enemy(Vector2.ZERO)
	var right_neighbor: StubEnemy = _add_enemy(Vector2(50.0, 0.0))
	var left_neighbor: StubEnemy = _add_enemy(Vector2(-50.0, 0.0))
	var far: StubEnemy = _add_enemy(Vector2(300.0, 0.0))
	var inner: KnockbackEffect = KnockbackEffect.new()
	inner.distance = 48.0
	var prop: PropagateEffect = PropagateEffect.new()
	prop.inner = inner
	prop.radius = 100.0
	prop.apply(main, {"hit_direction": Vector2.DOWN})
	assert_eq(main.knockback_calls.size(), 0, "传播不应含主目标")
	assert_eq(far.knockback_calls.size(), 0, "半径外不应被传播")
	assert_eq(right_neighbor.knockback_calls.size(), 1, "半径内邻居应吃到 inner")
	if not right_neighbor.knockback_calls.is_empty():
		assert_eq(right_neighbor.knockback_calls[0]["direction"], Vector2.RIGHT,
				"方向应覆写为主目标→邻居")
	if not left_neighbor.knockback_calls.is_empty():
		assert_eq(left_neighbor.knockback_calls[0]["direction"], Vector2.LEFT,
				"方向应逐邻居各自覆写")
	_cleanup([main, right_neighbor, left_neighbor, far])


func test_propagate_does_not_leak_handle_sink_to_neighbors() -> void:
	var main: StubEnemy = _add_enemy(Vector2.ZERO)
	var near: StubEnemy = _add_enemy(Vector2(50.0, 0.0))
	var stun: StunEffect = StunEffect.new()
	stun.duration = 1.0
	var prop: PropagateEffect = PropagateEffect.new()
	prop.inner = stun
	prop.radius = 100.0
	var sink: Array[int] = []
	prop.apply(main, {"handle_sink": sink})
	assert_true(near.stack().resolve(&"stunned", 0.0) > 0.0,
			"邻居应照常吃到 inner 持续型效果")
	assert_true(sink.is_empty(),
			"邻居句柄不得混入主目标的 handle_sink(02 flag ② 加固)")
	_cleanup([main, near])


func test_propagate_registers_durational_inner_on_neighbor() -> void:
	var main: StubEnemy = _add_enemy(Vector2.ZERO)
	var near: StubEnemy = _add_enemy(Vector2(50.0, 0.0))
	var stun: StunEffect = StunEffect.new()
	stun.duration = 1.0
	var prop: PropagateEffect = PropagateEffect.new()
	prop.inner = stun
	prop.radius = 100.0
	prop.apply(main, {})
	assert_eq(main.stack().resolve(&"stunned", 0.0), 0.0, "主目标不应被传播眩晕")
	assert_true(near.stack().resolve(&"stunned", 0.0) > 0.0,
			"持续型 inner 应注册进邻居的 ActiveEffects 并生效")
	near.active().tick(stun.duration)
	assert_eq(near.stack().resolve(&"stunned", 0.0), 0.0, "邻居侧计时到期应释放")
	_cleanup([main, near])

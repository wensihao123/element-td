extends TestCase

## Weapon 单测(PLAN 04 Phase 2):塔根替身(Node2D)+ 具名子节点 Targeting /
## StubSpawner(顶名 ProjectileSpawner),真 enemy.tscn 当靶;手动 tick 确定性驱动。

const ENEMY_SCENE_PATH: String = "res://scenes/enemies/enemy.tscn"


func _tree_root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _spawn_enemy(pos: Vector2, progress: float) -> Node2D:
	var enemy: Node2D = (load(ENEMY_SCENE_PATH) as PackedScene).instantiate() as Node2D
	_tree_root().add_child(enemy)
	enemy.global_position = pos
	enemy.set("progress", progress)
	return enemy


func _make_rig() -> Dictionary:
	var root: Node2D = Node2D.new()
	root.position = Vector2.ZERO
	var targeting: Targeting = Targeting.new()
	targeting.name = "Targeting"
	root.add_child(targeting)
	var spawner: StubSpawner = StubSpawner.new()
	spawner.name = "ProjectileSpawner"
	root.add_child(spawner)
	var weapon: Weapon = Weapon.new()
	weapon.name = "Weapon"
	weapon.range_px = 160.0
	weapon.speed_px = 384.0
	weapon.damage = 5.0
	weapon.fire_interval = 0.8
	weapon.attach_amount = 2.0
	weapon.source = root
	root.add_child(weapon)
	_tree_root().add_child(root)
	return {"root": root, "weapon": weapon, "spawner": spawner, "enemies": []}


func _cleanup(rig: Dictionary) -> void:
	for enemy: Variant in rig["enemies"]:
		if not is_instance_valid(enemy):
			continue
		var node: Node = enemy as Node
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	var root: Node = rig["root"]
	root.get_parent().remove_child(root)
	root.free()


func test_first_shot_immediate_with_payload() -> void:
	var rig: Dictionary = _make_rig()
	var weapon: Weapon = rig["weapon"]
	var spawner: StubSpawner = rig["spawner"]
	rig["enemies"].append(_spawn_enemy(Vector2(100.0, 0.0), 10.0))
	weapon.tick(0.0)
	assert_eq(spawner.spawn_calls.size(), 1, "有目标冷却初始 0 应立即首发")
	if not spawner.spawn_calls.is_empty():
		var call: Dictionary = spawner.spawn_calls[0]
		assert_true(call["target"] == rig["enemies"][0], "spawn 目标应为射程内敌人")
		var payload: Dictionary = call["payload"]
		assert_eq(payload["damage"], 5.0, "payload 应携带 damage")
		assert_eq(payload["speed_px"], 384.0, "payload 应携带 speed_px")
		assert_eq(payload["attach_amount"], 2.0, "payload 应携带 attach_amount")
		assert_true(payload["source"] == rig["root"], "payload.source 应为塔根(反应归属)")
	_cleanup(rig)


func test_fires_on_interval_boundaries() -> void:
	var rig: Dictionary = _make_rig()
	var weapon: Weapon = rig["weapon"]
	var spawner: StubSpawner = rig["spawner"]
	rig["enemies"].append(_spawn_enemy(Vector2(100.0, 0.0), 10.0))
	weapon.tick(0.0)
	assert_eq(spawner.spawn_calls.size(), 1, "前置:首发已出")
	weapon.tick(0.4)
	assert_eq(spawner.spawn_calls.size(), 1, "冷却未满不得开火")
	weapon.tick(0.4)
	assert_eq(spawner.spawn_calls.size(), 2, "累计满 fire_interval 应发第二发")
	weapon.tick(0.8)
	assert_eq(spawner.spawn_calls.size(), 3, "再满一个 interval 应发第三发")
	_cleanup(rig)


func test_holds_target_until_invalid_then_reacquires() -> void:
	var rig: Dictionary = _make_rig()
	var weapon: Weapon = rig["weapon"]
	var spawner: StubSpawner = rig["spawner"]
	var enemy_a: Node2D = _spawn_enemy(Vector2(50.0, 0.0), 90.0)
	var enemy_b: Node2D = _spawn_enemy(Vector2(100.0, 0.0), 10.0)
	rig["enemies"].append_array([enemy_a, enemy_b])
	weapon.tick(0.0)
	assert_true(spawner.spawn_calls[0]["target"] == enemy_a, "前置:首发锁 progress 更大的 a")
	enemy_b.set("progress", 999.0)
	weapon.tick(0.8)
	assert_eq(spawner.spawn_calls.size(), 2, "前置:第二发已出")
	assert_true(spawner.spawn_calls[1]["target"] == enemy_a,
			"目标仍有效时应持有不跳变(即使 b 的 progress 已更大)")
	enemy_a.global_position = Vector2(500.0, 0.0)
	weapon.tick(0.8)
	assert_true(spawner.spawn_calls[2]["target"] == enemy_b, "目标出射程应重索到 b")
	_cleanup(rig)


func test_stops_firing_when_target_gone_then_first_shot_on_new_target() -> void:
	var rig: Dictionary = _make_rig()
	var weapon: Weapon = rig["weapon"]
	var spawner: StubSpawner = rig["spawner"]
	var enemy_a: Node2D = _spawn_enemy(Vector2(100.0, 0.0), 10.0)
	rig["enemies"].append(enemy_a)
	weapon.tick(0.0)
	assert_eq(spawner.spawn_calls.size(), 1, "前置:首发已出")
	enemy_a.get_parent().remove_child(enemy_a)
	enemy_a.free()
	weapon.tick(0.8)
	weapon.tick(0.8)
	assert_eq(spawner.spawn_calls.size(), 1, "目标离场后应停火(空场无候选)")
	var enemy_b: Node2D = _spawn_enemy(Vector2(50.0, 0.0), 5.0)
	rig["enemies"].append(enemy_b)
	weapon.tick(0.0)
	assert_eq(spawner.spawn_calls.size(), 2, "停火期冷却已走完,新目标出现应即刻开火")
	assert_true(spawner.spawn_calls[1]["target"] == enemy_b, "新一发应锁新目标")
	_cleanup(rig)


## PLAN Phase 2「ProjectileSpawner」步的验收:真 ProjectileSpawner + 替身弹丸场景,
## 验证 spawn 实例化、setup 注入、子节点入树(挂 spawner 自身,D9)。
func test_real_spawner_instantiates_and_setups_substitute_scene() -> void:
	var rig: Dictionary = _make_rig()
	var weapon: Weapon = rig["weapon"]
	var stub: StubSpawner = rig["spawner"]
	stub.name = "StubRetired"
	var real_spawner: ProjectileSpawner = ProjectileSpawner.new()
	real_spawner.name = "ProjectileSpawner"
	var substitute: PackedScene = PackedScene.new()
	var pack_root: StubProjectile = StubProjectile.new()
	substitute.pack(pack_root)
	pack_root.free()
	real_spawner.projectile_scene = substitute
	rig["root"].add_child(real_spawner)
	rig["enemies"].append(_spawn_enemy(Vector2(100.0, 0.0), 10.0))
	weapon.tick(0.0)
	assert_eq(real_spawner.get_child_count(), 1, "spawn 后弹丸应挂 spawner 子节点入树")
	if real_spawner.get_child_count() > 0:
		var projectile: StubProjectile = real_spawner.get_child(0) as StubProjectile
		assert_true(projectile != null, "子节点应为替身弹丸实例")
		assert_eq(projectile.setup_calls.size(), 1, "setup 应恰调用一次")
		if not projectile.setup_calls.is_empty():
			var call: Dictionary = projectile.setup_calls[0]
			assert_true(call["target"] == rig["enemies"][0], "setup 目标应透传")
			assert_eq(call["damage"], 5.0, "setup 应透传 payload.damage")
			assert_true(call["source"] == rig["root"], "setup.source 应为塔根")
	_cleanup(rig)

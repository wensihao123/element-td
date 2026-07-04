extends TestCase

## 敌人实体单测(PLAN 03 Phase 1):组件在位/入组、根转发护甲扣真血、
## 死亡总线信号 + queue_free(禁同步 free)、innate 附着不挂 base_status。
## cfg 用哨兵值本地构造(非游戏数值);fire.tres 为真数据(innate 断言按 id 点名)。
## 组约定要求入树:借测试跑道 SceneTree 的 root 挂载,用完即清。

const ENEMY_SCENE_PATH: String = "res://scenes/enemies/enemy.tscn"
const FIRE_PATH: String = "res://data/elements/fire.tres"


func _tree_root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _make_def(hp: float, armor: float, innate: ElementDef = null) -> EnemyDef:
	var def: EnemyDef = EnemyDef.new()
	def.id = &"test_enemy"
	def.max_hp = hp
	def.speed = 10.0
	def.armor = armor
	def.gold_reward = 1
	def.innate_element = innate
	return def


func _make_cfg() -> GaugeConfig:
	var cfg: GaugeConfig = GaugeConfig.new()
	cfg.default_attach = 2.5
	cfg.max_gauge = 3.5
	cfg.default_cost = 1.0
	cfg.reaction_icd = 0.5
	return cfg


## 显式注入 cfg/bus 后入树(02-D1 可测性模式:不赌 autoload)。
func _spawn(def: EnemyDef, cfg: GaugeConfig, bus: RecordingBus, path: Path2D = null) -> Enemy:
	var enemy: Enemy = (load(ENEMY_SCENE_PATH) as PackedScene).instantiate() as Enemy
	enemy.setup(def, path)
	(enemy.get_node("StatusComponent") as StatusComponent).cfg = cfg
	enemy.bus = bus
	_tree_root().add_child(enemy)
	return enemy


## 直线水平 curve,起点在原点,便于用 x 坐标断言采样位置。
func _make_path(length: float) -> Path2D:
	var path: Path2D = Path2D.new()
	var curve: Curve2D = Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(length, 0.0))
	path.curve = curve
	_tree_root().add_child(path)
	return path


func _cleanup(enemy: Enemy, extras: Array[Node]) -> void:
	var nodes: Array[Node] = extras.duplicate()
	if is_instance_valid(enemy):
		nodes.push_front(enemy)
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func test_components_present_and_grouped() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var enemy: Enemy = _spawn(_make_def(30.0, 0.0), _make_cfg(), bus)
	for component_name: String in [
			"StatusComponent", "ModifierStack", "ActiveEffects", "HealthComponent"]:
		assert_true(enemy.get_node_or_null(component_name) != null,
				"%s 应为具名直接子节点(02-D7)" % component_name)
	assert_true(enemy.is_in_group(ReactionEffect.ENEMY_GROUP), "敌人根应入 enemies 组(02-D6)")
	_cleanup(enemy, [bus])


func test_take_damage_forwards_through_armor() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var enemy: Enemy = _spawn(_make_def(100.0, 2.0), _make_cfg(), bus)
	enemy.take_damage(5.0, null)
	var health: HealthComponent = enemy.get_node("HealthComponent") as HealthComponent
	assert_true(is_equal_approx(health.hp, 97.0),
			"根转发 take_damage 应走护甲公式扣真血(实际 hp:%s)" % str(health.hp))
	_cleanup(enemy, [bus])


func test_lethal_damage_emits_bus_and_queue_frees() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var def: EnemyDef = _make_def(10.0, 0.0)
	var enemy: Enemy = _spawn(def, _make_cfg(), bus)
	enemy.take_damage(99.0, null)
	assert_true(is_instance_valid(enemy),
			"take_damage 返回后节点引用应仍有效——禁同步 free(02 REVIEW)")
	assert_true(enemy.is_queued_for_deletion(), "死亡应走 queue_free")
	assert_eq(bus.died.size(), 1, "死亡应恰发一次 enemy_died 总线信号")
	if not bus.died.is_empty():
		assert_true(bus.died[0]["enemy"] == enemy, "enemy_died 应携带敌人实例")
		assert_true(bus.died[0]["def"] == def, "enemy_died 应携带 EnemyDef")
	_cleanup(enemy, [bus])


func test_innate_attaches_element_without_base_status() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var cfg: GaugeConfig = _make_cfg()
	var enemy: Enemy = _spawn(_make_def(50.0, 0.0, fire), cfg, bus)
	var status: StatusComponent = enemy.get_node("StatusComponent") as StatusComponent
	assert_true(status.element != null and status.element.id == &"fire",
			"innate 怪 _ready 后应带火元素")
	assert_eq(status.gauge, cfg.default_attach, "innate 附着量应为 cfg.default_attach")
	var health: HealthComponent = enemy.get_node("HealthComponent") as HealthComponent
	(enemy.get_node("ActiveEffects") as ActiveEffects).tick(1.0)
	assert_eq(health.hp, 50.0, "innate 不挂 base_status:tick 1s 不得有灼烧伤(D5)")
	_cleanup(enemy, [bus])


func test_def_without_innate_attaches_nothing() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var enemy: Enemy = _spawn(_make_def(30.0, 0.0), _make_cfg(), bus)
	var status: StatusComponent = enemy.get_node("StatusComponent") as StatusComponent
	assert_true(status.element == null, "无 innate 的 def 不得附着元素")
	assert_eq(status.gauge, 0.0, "无 innate 时 gauge 应为 0")
	_cleanup(enemy, [bus])


func test_moves_along_path_at_def_speed() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var path: Path2D = _make_path(1000.0)
	var def: EnemyDef = _make_def(30.0, 0.0)
	var enemy: Enemy = _spawn(def, _make_cfg(), bus, path)
	assert_true(enemy.global_position.is_equal_approx(Vector2.ZERO),
			"_ready 后应吸附路径起点")
	enemy.tick(1.0)
	assert_true(is_equal_approx(enemy.progress, def.speed),
			"tick 1s 应前进 def.speed px(实际:%s)" % str(enemy.progress))
	assert_true(enemy.global_position.is_equal_approx(Vector2(def.speed, 0.0)),
			"位置应为 baked curve 采样点")
	_cleanup(enemy, [bus, path])


func test_speed_modifier_scales_movement() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var path: Path2D = _make_path(1000.0)
	var def: EnemyDef = _make_def(30.0, 0.0)
	var enemy: Enemy = _spawn(def, _make_cfg(), bus, path)
	(enemy.get_node("ModifierStack") as ModifierStack).add(&"speed", 0.0, -0.3)
	enemy.tick(1.0)
	assert_true(is_equal_approx(enemy.progress, def.speed * 0.7),
			"挂 speed pct -0.3 后前进量应 ×0.7(实际:%s)" % str(enemy.progress))
	_cleanup(enemy, [bus, path])


func test_stunned_halts_and_resumes() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var path: Path2D = _make_path(1000.0)
	var def: EnemyDef = _make_def(30.0, 0.0)
	var enemy: Enemy = _spawn(def, _make_cfg(), bus, path)
	var stack: ModifierStack = enemy.get_node("ModifierStack") as ModifierStack
	var handle: int = stack.add(&"stunned", 1.0, 0.0)
	enemy.tick(1.0)
	assert_eq(enemy.progress, 0.0, "眩晕期间 tick 不得前进(02 契约 resolve(&\"stunned\"))")
	stack.remove(handle)
	enemy.tick(1.0)
	assert_true(is_equal_approx(enemy.progress, def.speed), "摘除眩晕后应恢复移动")
	_cleanup(enemy, [bus, path])


func test_knockback_rolls_progress_back_clamped() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var path: Path2D = _make_path(1000.0)
	var def: EnemyDef = _make_def(30.0, 0.0)
	var enemy: Enemy = _spawn(def, _make_cfg(), bus, path)
	enemy.tick(6.0)
	assert_true(is_equal_approx(enemy.progress, 60.0), "前置:tick 6s 应到 progress 60")
	enemy.apply_knockback(50.0, Vector2.UP)
	assert_true(is_equal_approx(enemy.progress, 10.0),
			"击退 50 应回退 progress 50(D2,忽略 direction)")
	enemy.apply_knockback(50.0, Vector2.LEFT)
	assert_eq(enemy.progress, 0.0, "击退不得把 progress 打破 0(clamp)")
	_cleanup(enemy, [bus, path])


func test_reaching_exit_emits_bus_and_queue_frees() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var path: Path2D = _make_path(100.0)
	var def: EnemyDef = _make_def(30.0, 0.0)
	var enemy: Enemy = _spawn(def, _make_cfg(), bus, path)
	enemy.tick(20.0)
	assert_true(enemy.is_queued_for_deletion(), "抵达终点应 queue_free")
	assert_eq(bus.reached_exit.size(), 1, "抵达终点应恰发一次 enemy_reached_exit")
	if not bus.reached_exit.is_empty():
		assert_true(bus.reached_exit[0]["enemy"] == enemy, "信号应携带敌人实例")
		assert_true(bus.reached_exit[0]["def"] == def, "信号应携带 EnemyDef")
	enemy.tick(1.0)
	assert_eq(bus.reached_exit.size(), 1, "已排队删除后 tick 不得重复发终点信号")
	_cleanup(enemy, [bus, path])


## 回归(REVIEW must-fix ②):终点/死亡两终态信号互斥。到达终点(queue_free 排队、
## 本帧仍在树内在组)后同帧再吃致死伤——take_damage 首行 guard 应拒收,
## 只发 enemy_reached_exit、不发 enemy_died,否则 06 会「扣基地血 + 发金币」双记账。
func test_exit_then_lethal_damage_emits_exit_only() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var path: Path2D = _make_path(100.0)
	var def: EnemyDef = _make_def(30.0, 0.0)
	var enemy: Enemy = _spawn(def, _make_cfg(), bus, path)
	enemy.tick(20.0)
	assert_true(enemy.is_queued_for_deletion(), "前置:抵达终点应已排队删除")
	assert_eq(bus.reached_exit.size(), 1, "前置:抵达终点应恰发一次 enemy_reached_exit")
	enemy.take_damage(999.0, null)
	var health: HealthComponent = enemy.get_node("HealthComponent") as HealthComponent
	assert_eq(health.hp, def.max_hp, "终态后伤害应被整体拒收(hp 不得变动)")
	assert_eq(bus.died.size(), 0,
			"先到终点再吃致死伤:不得再发 enemy_died(终态互斥,每敌恰发其一)")
	assert_eq(bus.reached_exit.size(), 1, "enemy_reached_exit 保持恰一次")
	_cleanup(enemy, [bus, path])

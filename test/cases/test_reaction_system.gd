extends TestCase

## ReactionSystem 单测(PLAN 02 Phase 4):真实 6 反应建表 12 方向全命中、
## ICD 拦截与释放、扣量 = get_cost(cfg)、扣到 0 过期回滚、incoming 不附着、
## 反协同铁律(gauge > 0 时 base status 原封不动)、bus 空安全、autoload 注册。
## 期望值全部由 cfg / def 推导。

const RS_SCRIPT_PATH: String = "res://scripts/systems/reaction_system.gd"
const CONFIG_PATH: String = "res://data/balance/global_config.tres"
const FIRE_PATH: String = "res://data/elements/fire.tres"
const ICE_PATH: String = "res://data/elements/ice.tres"
const STEAM_BURST_PATH: String = "res://data/reactions/steam_burst.tres"
const REACTION_PATHS: Array[String] = [
	"res://data/reactions/steam_burst.tres",
	"res://data/reactions/overload.tres",
	"res://data/reactions/combustion.tres",
	"res://data/reactions/superconduct.tres",
	"res://data/reactions/brittle.tres",
	"res://data/reactions/electrolysis.tres",
]


func _new_rs(cfg: GaugeConfig, bus: Node) -> Node:
	var rs: Node = (load(RS_SCRIPT_PATH) as GDScript).new() as Node
	var reactions: Array[ReactionDef] = []
	for path: String in REACTION_PATHS:
		reactions.append(load(path) as ReactionDef)
	rs.call("setup", cfg, reactions, bus)
	return rs


## 敌人入树:反应效果(AoE/传播)的组扫描要求圆心在场景树内。
func _new_enemy(cfg: GaugeConfig, rs: Node) -> StubEnemy:
	var enemy: StubEnemy = StubEnemy.new()
	enemy.status().cfg = cfg
	enemy.status().reaction_system = rs
	(Engine.get_main_loop() as SceneTree).root.add_child(enemy)
	return enemy


func _free_enemy(enemy: StubEnemy) -> void:
	enemy.get_parent().remove_child(enemy)
	enemy.free()


func test_autoloads_registered() -> void:
	assert_true(ProjectSettings.has_setting("autoload/EventBus"),
			"project.godot 应注册 EventBus autoload")
	assert_true(ProjectSettings.has_setting("autoload/ReactionSystem"),
			"project.godot 应注册 ReactionSystem autoload")


func test_all_12_direction_keys_hit() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var bus: RecordingBus = RecordingBus.new()
	var rs: Node = _new_rs(cfg, bus)
	var tower: Node = Node.new()
	var hit_count: int = 0
	for path: String in REACTION_PATHS:
		var def: ReactionDef = load(path) as ReactionDef
		for pair: Array in [[def.element_a, def.element_b], [def.element_b, def.element_a]]:
			var enemy: StubEnemy = _new_enemy(cfg, rs)
			enemy.status().apply_element(pair[0], cfg.default_attach, tower)
			var ok: bool = rs.call("try_react", enemy.status(), pair[1], tower)
			assert_true(ok, "%s:附着 %s + 命中 %s 应查表命中" %
					[def.id, (pair[0] as ElementDef).id, (pair[1] as ElementDef).id])
			if ok:
				hit_count += 1
			_free_enemy(enemy)
	assert_eq(hit_count, 12, "6 反应 × 2 方向应全命中")
	assert_eq(bus.events.size(), 12, "每次命中应发一次 reaction_triggered")
	rs.free()
	bus.free()
	tower.free()


func test_icd_blocks_then_releases_after_tick() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var ice: ElementDef = load(ICE_PATH) as ElementDef
	var steam: ReactionDef = load(STEAM_BURST_PATH) as ReactionDef
	var rs: Node = _new_rs(cfg, null)
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy(cfg, rs)
	enemy.status().apply_element(fire, cfg.max_gauge, tower)
	assert_true(rs.call("try_react", enemy.status(), ice, tower), "首次反应应成功")
	var expected_gauge: float = cfg.max_gauge - steam.get_cost(cfg)
	assert_eq(enemy.status().gauge, expected_gauge, "扣量应为 def.get_cost(cfg)")
	assert_eq(enemy.status().icd_remaining, cfg.reaction_icd, "反应后应设 ICD")
	assert_true(not rs.call("try_react", enemy.status(), ice, tower),
			"冷却内第二次 try_react 应返 false")
	assert_eq(enemy.status().gauge, expected_gauge, "ICD 拦截不得动 gauge")
	assert_true(enemy.status().element == fire, "ICD 拦截不得动附着(D8:吞掉不附着)")
	enemy.status().tick(cfg.reaction_icd)
	assert_true(rs.call("try_react", enemy.status(), ice, tower), "ICD 释放后应可再反应")
	rs.free()
	_free_enemy(enemy)
	tower.free()


func test_consume_to_zero_expires_and_rolls_back_base() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var ice: ElementDef = load(ICE_PATH) as ElementDef
	var slow: StatModifierEffect = ice.base_status[0] as StatModifierEffect
	var steam: ReactionDef = load(STEAM_BURST_PATH) as ReactionDef
	var rs: Node = _new_rs(cfg, null)
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy(cfg, rs)
	var expired_ids: Array[StringName] = []
	enemy.status().status_expired.connect(
			func(e: ElementDef) -> void: expired_ids.append(e.id))
	enemy.status().apply_element(ice, steam.get_cost(cfg), tower)
	var base_speed: float = 100.0
	assert_eq(enemy.stack().resolve(&"speed", base_speed),
			base_speed * (1.0 + slow.add_percent), "反应前冰减速应在场")
	assert_true(rs.call("try_react", enemy.status(), fire, tower), "反应应成功")
	assert_eq(enemy.status().gauge, 0.0, "恰好扣到 0")
	assert_true(enemy.status().element == null, "扣到 0 应过期清空 element")
	assert_eq(str(expired_ids), str([ice.id] as Array[StringName]),
			"扣到 0 应发 status_expired")
	assert_eq(enemy.stack().resolve(&"speed", base_speed), base_speed,
			"过期应回滚冰减速")
	rs.free()
	_free_enemy(enemy)
	tower.free()


func test_anti_synergy_base_status_survives_while_gauge_positive() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var ice: ElementDef = load(ICE_PATH) as ElementDef
	var slow: StatModifierEffect = ice.base_status[0] as StatModifierEffect
	var steam: ReactionDef = load(STEAM_BURST_PATH) as ReactionDef
	var rs: Node = _new_rs(cfg, null)
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy(cfg, rs)
	enemy.status().apply_element(ice, cfg.max_gauge, tower)
	assert_true(rs.call("try_react", enemy.status(), fire, tower), "反应应成功")
	assert_eq(enemy.status().gauge, cfg.max_gauge - steam.get_cost(cfg),
			"扣后 gauge 仍为正")
	assert_true(enemy.status().element == ice, "incoming(火)被消耗,不得附着替换冰")
	var base_speed: float = 100.0
	assert_eq(enemy.stack().resolve(&"speed", base_speed),
			base_speed * (1.0 + slow.add_percent),
			"反协同铁律:gauge > 0 时冰减速原封不动(反应不吃减速)")
	rs.free()
	_free_enemy(enemy)
	tower.free()


func test_unknown_pair_returns_false_untouched() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var neutral: ElementDef = ElementDef.new()
	neutral.id = &"neutral_test_only"
	var rs: Node = _new_rs(cfg, null)
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy(cfg, rs)
	enemy.status().apply_element(neutral, cfg.default_attach, tower)
	var gauge_before: float = enemy.status().gauge
	assert_true(not rs.call("try_react", enemy.status(), fire, tower),
			"查无反应对应返 false")
	assert_eq(enemy.status().gauge, gauge_before, "查无不得动 gauge")
	assert_eq(enemy.status().icd_remaining, 0.0, "查无不得设 ICD")
	rs.free()
	_free_enemy(enemy)
	tower.free()


func test_null_bus_does_not_crash() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var ice: ElementDef = load(ICE_PATH) as ElementDef
	var rs: Node = _new_rs(cfg, null)
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy(cfg, rs)
	enemy.status().apply_element(fire, cfg.default_attach, tower)
	assert_true(rs.call("try_react", enemy.status(), ice, tower),
			"bus 为 null 时反应仍应完整执行不崩")
	rs.free()
	_free_enemy(enemy)
	tower.free()

extends TestCase

## 六反应端到端矩阵(PLAN 02 Phase 4):走完整管线
## StatusComponent.apply_element(异元素) → ReactionSystem.try_react → 效果 → EventBus。
## 每个反应:主目标(附 element_a 默认附着量)+ 半径内邻居 + 半径外哨兵,
## element_b 命中 → 统一断言信号/gauge/附着,再逐反应断言效果;逐反应打印 PASSED 行。
## 期望值全部由 cfg / def / 效果字段推导;伤害断言在「调用面」(护甲结算归 03)。

const RS_SCRIPT_PATH: String = "res://scripts/systems/reaction_system.gd"
const CONFIG_PATH: String = "res://data/balance/global_config.tres"
const REACTION_PATHS: Array[String] = [
	"res://data/reactions/steam_burst.tres",
	"res://data/reactions/overload.tres",
	"res://data/reactions/combustion.tres",
	"res://data/reactions/superconduct.tres",
	"res://data/reactions/brittle.tres",
	"res://data/reactions/electrolysis.tres",
]

const HIT_DIRECTION: Vector2 = Vector2.RIGHT


func _load_cfg() -> GaugeConfig:
	return load(CONFIG_PATH) as GaugeConfig


## 组装一套端到端 rig:注入好的 rs/bus + 主目标(已附 element_a)+ 邻居 + 哨兵。
func _rig(def: ReactionDef, cfg: GaugeConfig,
		neighbor_pos: Vector2, sentinel_pos: Vector2) -> Dictionary:
	var bus: RecordingBus = RecordingBus.new()
	var rs: Node = (load(RS_SCRIPT_PATH) as GDScript).new() as Node
	var reactions: Array[ReactionDef] = []
	for path: String in REACTION_PATHS:
		reactions.append(load(path) as ReactionDef)
	rs.call("setup", cfg, reactions, bus)
	var tower: Node = Node.new()
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var main: StubEnemy = StubEnemy.new()
	var neighbor: StubEnemy = StubEnemy.new()
	neighbor.position = neighbor_pos
	var sentinel: StubEnemy = StubEnemy.new()
	sentinel.position = sentinel_pos
	for enemy: StubEnemy in [main, neighbor, sentinel]:
		enemy.status().cfg = cfg
		enemy.status().reaction_system = rs
		root.add_child(enemy)
	main.status().apply_element(def.element_a, cfg.default_attach, tower)
	return {"bus": bus, "rs": rs, "tower": tower,
			"main": main, "neighbor": neighbor, "sentinel": sentinel}


## element_b 命中主目标,走 StatusComponent 完整转发管线。
func _hit(rig: Dictionary, def: ReactionDef, cfg: GaugeConfig) -> void:
	var main: StubEnemy = rig["main"]
	main.status().apply_element(def.element_b, cfg.default_attach, rig["tower"], HIT_DIRECTION)


## 统一断言:信号内容(def/target/source)、gauge 余量、incoming 未附着。
func _assert_core(rig: Dictionary, def: ReactionDef, cfg: GaugeConfig) -> void:
	var bus: RecordingBus = rig["bus"]
	var main: StubEnemy = rig["main"]
	assert_eq(bus.events.size(), 1, "%s:应恰好发一次 reaction_triggered" % def.id)
	if not bus.events.is_empty():
		var event: Dictionary = bus.events[0]
		assert_true(event["reaction"] == def, "%s:信号应携带反应 def" % def.id)
		assert_true(event["target"] == main, "%s:信号 target 应为主目标" % def.id)
		assert_true(event["source"] == rig["tower"], "%s:信号 source 应为触发方塔(归属铁律)" % def.id)
	assert_eq(main.status().gauge, cfg.default_attach - def.get_cost(cfg),
			"%s:gauge 余量应为附着量 - get_cost(cfg)" % def.id)
	assert_true(main.status().element == def.element_a,
			"%s:incoming 元素被反应消耗,不得附着替换" % def.id)


func _cleanup(rig: Dictionary) -> void:
	for key: String in ["main", "neighbor", "sentinel"]:
		var enemy: StubEnemy = rig[key]
		enemy.get_parent().remove_child(enemy)
		enemy.free()
	(rig["rs"] as Node).free()
	(rig["bus"] as Node).free()
	(rig["tower"] as Node).free()


func _count_damage(enemy: StubEnemy, amount: float) -> int:
	var count: int = 0
	for call: Dictionary in enemy.damage_calls:
		if call["amount"] == amount:
			count += 1
	return count


func _report(def_id: StringName, failures_before: int) -> void:
	if failures.size() == failures_before:
		print("PASSED  e2e 反应 %s" % def_id)


func test_steam_burst_aoe() -> void:
	var before: int = failures.size()
	var cfg: GaugeConfig = _load_cfg()
	var def: ReactionDef = load(REACTION_PATHS[0]) as ReactionDef
	var aoe: AoeDamageEffect = def.effects[0] as AoeDamageEffect
	var rig: Dictionary = _rig(def, cfg,
			Vector2(aoe.radius * 0.5, 0.0), Vector2(aoe.radius * 2.0, 0.0))
	_hit(rig, def, cfg)
	_assert_core(rig, def, cfg)
	assert_eq(_count_damage(rig["main"], aoe.damage), 1, "steam_burst:主目标应吃 AoE 伤害")
	assert_eq(_count_damage(rig["neighbor"], aoe.damage), 1, "steam_burst:圈内邻居应受伤")
	assert_eq((rig["sentinel"] as StubEnemy).damage_calls.size(), 0,
			"steam_burst:圈外哨兵不得受伤")
	_cleanup(rig)
	_report(def.id, before)


func test_overload_damage_and_knockback() -> void:
	var before: int = failures.size()
	var cfg: GaugeConfig = _load_cfg()
	var def: ReactionDef = load(REACTION_PATHS[1]) as ReactionDef
	var aoe: AoeDamageEffect = def.effects[0] as AoeDamageEffect
	var knock: KnockbackEffect = def.effects[1] as KnockbackEffect
	var rig: Dictionary = _rig(def, cfg,
			Vector2(aoe.radius * 0.5, 0.0), Vector2(aoe.radius * 2.0, 0.0))
	_hit(rig, def, cfg)
	_assert_core(rig, def, cfg)
	var main: StubEnemy = rig["main"]
	assert_eq(_count_damage(main, aoe.damage), 1, "overload:主目标应吃 AoE 伤害")
	assert_eq(_count_damage(rig["neighbor"], aoe.damage), 1, "overload:圈内邻居应受伤")
	assert_eq(main.knockback_calls.size(), 1, "overload:主目标应被击退")
	if not main.knockback_calls.is_empty():
		assert_eq(main.knockback_calls[0]["distance"], knock.distance,
				"overload:击退距离应为效果字段值")
		assert_eq(main.knockback_calls[0]["direction"], HIT_DIRECTION,
				"overload:击退方向应为命中方向")
	assert_eq((rig["neighbor"] as StubEnemy).knockback_calls.size(), 0,
			"overload:击退只作用主目标")
	_cleanup(rig)
	_report(def.id, before)


func test_combustion_dot_on_main_and_neighbor() -> void:
	var before: int = failures.size()
	var cfg: GaugeConfig = _load_cfg()
	var def: ReactionDef = load(REACTION_PATHS[2]) as ReactionDef
	var dot_main: DotEffect = def.effects[0] as DotEffect
	var prop: PropagateEffect = def.effects[1] as PropagateEffect
	var spread: DotEffect = prop.inner as DotEffect
	var rig: Dictionary = _rig(def, cfg,
			Vector2(prop.radius * 0.5, 0.0), Vector2(prop.radius * 2.0, 0.0))
	_hit(rig, def, cfg)
	_assert_core(rig, def, cfg)
	var main: StubEnemy = rig["main"]
	var neighbor: StubEnemy = rig["neighbor"]
	var sentinel: StubEnemy = rig["sentinel"]
	var main_tick_damage: float = dot_main.dps * dot_main.tick_interval
	var spread_tick_damage: float = spread.dps * spread.tick_interval
	main.active().tick(dot_main.tick_interval)
	neighbor.active().tick(spread.tick_interval)
	sentinel.active().tick(spread.tick_interval)
	assert_eq(_count_damage(main, main_tick_damage), 1,
			"combustion:主目标应按 tick 出燃爆 dot 伤")
	assert_eq(_count_damage(neighbor, spread_tick_damage), 1,
			"combustion:邻居应按 tick 出传播 dot 伤")
	assert_eq(sentinel.damage_calls.size(), 0, "combustion:圈外哨兵无 dot")
	var total_ticks: int = int(dot_main.duration / dot_main.tick_interval)
	for i: int in range(total_ticks - 1):
		main.active().tick(dot_main.tick_interval)
	assert_eq(_count_damage(main, main_tick_damage), total_ticks,
			"combustion:duration 内应恰好出满每跳")
	main.active().tick(dot_main.tick_interval)
	assert_eq(_count_damage(main, main_tick_damage), total_ticks,
			"combustion:dot 到期后不应再出伤")
	_cleanup(rig)
	_report(def.id, before)


func test_superconduct_stuns_main_and_neighbor() -> void:
	var before: int = failures.size()
	var cfg: GaugeConfig = _load_cfg()
	var def: ReactionDef = load(REACTION_PATHS[3]) as ReactionDef
	var stun_main: StunEffect = def.effects[0] as StunEffect
	var prop: PropagateEffect = def.effects[1] as PropagateEffect
	var spread: StunEffect = prop.inner as StunEffect
	var rig: Dictionary = _rig(def, cfg,
			Vector2(prop.radius * 0.5, 0.0), Vector2(prop.radius * 2.0, 0.0))
	_hit(rig, def, cfg)
	_assert_core(rig, def, cfg)
	var main: StubEnemy = rig["main"]
	var neighbor: StubEnemy = rig["neighbor"]
	assert_true(main.stack().resolve(&"stunned", 0.0) > 0.0, "superconduct:主目标应冻结")
	assert_true(neighbor.stack().resolve(&"stunned", 0.0) > 0.0, "superconduct:邻居应冻结")
	assert_eq((rig["sentinel"] as StubEnemy).stack().resolve(&"stunned", 0.0), 0.0,
			"superconduct:圈外哨兵不受冻结")
	main.active().tick(stun_main.duration)
	neighbor.active().tick(spread.duration)
	assert_eq(main.stack().resolve(&"stunned", 0.0), 0.0, "superconduct:时限后主目标应释放")
	assert_eq(neighbor.stack().resolve(&"stunned", 0.0), 0.0, "superconduct:时限后邻居应释放")
	_cleanup(rig)
	_report(def.id, before)


func test_brittle_damage_taken_modifier() -> void:
	var before: int = failures.size()
	var cfg: GaugeConfig = _load_cfg()
	var def: ReactionDef = load(REACTION_PATHS[4]) as ReactionDef
	var vuln: StatModifierEffect = def.effects[0] as StatModifierEffect
	var rig: Dictionary = _rig(def, cfg, Vector2(48.0, 0.0), Vector2(500.0, 0.0))
	_hit(rig, def, cfg)
	_assert_core(rig, def, cfg)
	var main: StubEnemy = rig["main"]
	var base_taken: float = 1.0
	assert_eq(main.stack().resolve(&"damage_taken", base_taken),
			(base_taken + vuln.add_flat) * (1.0 + vuln.add_percent),
			"brittle:damage_taken 修饰应在场")
	assert_eq((rig["neighbor"] as StubEnemy).stack().resolve(&"damage_taken", base_taken),
			base_taken, "brittle:无传播,邻居不受影响")
	main.active().tick(vuln.duration)
	assert_eq(main.stack().resolve(&"damage_taken", base_taken), base_taken,
			"brittle:到期应回滚")
	_cleanup(rig)
	_report(def.id, before)


func test_electrolysis_stun_releases_after_duration() -> void:
	var before: int = failures.size()
	var cfg: GaugeConfig = _load_cfg()
	var def: ReactionDef = load(REACTION_PATHS[5]) as ReactionDef
	var stun: StunEffect = def.effects[0] as StunEffect
	var rig: Dictionary = _rig(def, cfg, Vector2(48.0, 0.0), Vector2(500.0, 0.0))
	_hit(rig, def, cfg)
	_assert_core(rig, def, cfg)
	var main: StubEnemy = rig["main"]
	assert_true(main.stack().resolve(&"stunned", 0.0) > 0.0, "electrolysis:主目标应麻痹")
	assert_eq((rig["neighbor"] as StubEnemy).stack().resolve(&"stunned", 0.0), 0.0,
			"electrolysis:无传播,邻居不受影响")
	main.active().tick(stun.duration)
	assert_eq(main.stack().resolve(&"stunned", 0.0), 0.0,
			"electrolysis:恰一个 duration 后应释放")
	_cleanup(rig)
	_report(def.id, before)

extends TestCase

## StatusComponent 单测(PLAN 02 Phase 3):附着 clamp、同元素叠层至 max、
## 衰减归零过期、过期回滚(冰减速复原)、异元素只转发不自决。
## 期望值一律从 cfg / 元素 .tres 字段推导;衰减用合成 GaugeConfig(测试脚手架)。

const CONFIG_PATH: String = "res://data/balance/global_config.tres"
const FIRE_PATH: String = "res://data/elements/fire.tres"
const ICE_PATH: String = "res://data/elements/ice.tres"


## 间谍 ReactionSystem:只记录 try_react 转发参数,不做任何裁决。
class SpyReactionSystem:
	extends Node

	var calls: Array[Dictionary] = []

	func try_react(status: StatusComponent, incoming: ElementDef, source: Node,
			hit_direction: Vector2 = Vector2.ZERO) -> bool:
		calls.append({"status": status, "incoming": incoming, "source": source,
				"hit_direction": hit_direction})
		return false


func _new_enemy(cfg: GaugeConfig) -> StubEnemy:
	var enemy: StubEnemy = StubEnemy.new()
	enemy.status().cfg = cfg
	return enemy


func test_attach_clamps_and_emits_started() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy(cfg)
	var started_ids: Array[StringName] = []
	enemy.status().status_started.connect(
			func(e: ElementDef) -> void: started_ids.append(e.id))
	enemy.status().apply_element(fire, cfg.default_attach, tower)
	assert_true(enemy.status().element == fire, "附着后 element 应为 fire")
	assert_eq(enemy.status().gauge, clampf(cfg.default_attach, 0.0, cfg.max_gauge),
			"附着量应 clamp(0, max)")
	assert_eq(str(started_ids), str([fire.id] as Array[StringName]),
			"附着应发一次 status_started")
	var enemy_overflow: StubEnemy = _new_enemy(cfg)
	enemy_overflow.status().apply_element(fire, cfg.max_gauge + 5.0, tower)
	assert_eq(enemy_overflow.status().gauge, cfg.max_gauge, "超量附着应 clamp 至 max")
	enemy.free()
	enemy_overflow.free()
	tower.free()


func test_same_element_stacks_to_max() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy(cfg)
	enemy.status().apply_element(fire, cfg.default_attach, tower)
	enemy.status().apply_element(fire, cfg.default_attach, tower)
	assert_eq(enemy.status().gauge,
			clampf(cfg.default_attach * 2.0, 0.0, cfg.max_gauge),
			"同元素叠层应 clamp 至 max")
	assert_true(enemy.status().element == fire, "同元素叠层不应改变 element")
	enemy.free()
	tower.free()


func test_base_status_applies_via_active_effects() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var burn: DotEffect = fire.base_status[0] as DotEffect
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy(cfg)
	enemy.status().apply_element(fire, cfg.default_attach, tower)
	enemy.active().tick(burn.tick_interval)
	assert_eq(enemy.damage_calls.size(), 1, "火 base_status 灼烧应按间隔出伤")
	if not enemy.damage_calls.is_empty():
		assert_eq(enemy.damage_calls[0]["amount"], burn.dps * burn.tick_interval,
				"灼烧每跳伤害应从 .tres 字段推导")
		assert_true(enemy.damage_calls[0]["source"] == tower, "灼烧 source 应为附着塔")
	enemy.free()
	tower.free()


func test_decay_expires_and_rolls_back_slow() -> void:
	var cfg: GaugeConfig = GaugeConfig.new()
	cfg.decay_per_sec = 1.0
	var ice: ElementDef = load(ICE_PATH) as ElementDef
	var slow: StatModifierEffect = ice.base_status[0] as StatModifierEffect
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy(cfg)
	var expired_ids: Array[StringName] = []
	enemy.status().status_expired.connect(
			func(e: ElementDef) -> void: expired_ids.append(e.id))
	enemy.status().apply_element(ice, cfg.default_attach, tower)
	var base_speed: float = 100.0
	assert_eq(enemy.stack().resolve(&"speed", base_speed),
			base_speed * (1.0 + slow.add_percent), "gauge > 0 期间冰减速应生效")
	enemy.status().tick(cfg.default_attach / cfg.decay_per_sec)
	assert_eq(enemy.status().gauge, 0.0, "衰减应把 gauge 扣到 0")
	assert_true(enemy.status().element == null, "归零过期应清空 element")
	assert_eq(str(expired_ids), str([ice.id] as Array[StringName]),
			"归零过期应发一次 status_expired")
	assert_eq(enemy.stack().resolve(&"speed", base_speed), base_speed,
			"过期应回滚冰减速复原")
	enemy.free()
	tower.free()


func test_other_element_only_forwards_to_reaction_system() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var ice: ElementDef = load(ICE_PATH) as ElementDef
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy(cfg)
	var spy: SpyReactionSystem = SpyReactionSystem.new()
	enemy.status().reaction_system = spy
	enemy.status().apply_element(fire, cfg.default_attach, tower)
	var gauge_before: float = enemy.status().gauge
	enemy.status().apply_element(ice, cfg.default_attach, tower, Vector2.RIGHT)
	assert_eq(spy.calls.size(), 1, "异元素命中应恰好转发一次 try_react")
	if not spy.calls.is_empty():
		assert_true(spy.calls[0]["status"] == enemy.status(), "转发应携带本状态组件")
		assert_true(spy.calls[0]["incoming"] == ice, "转发 incoming 应为异元素")
		assert_true(spy.calls[0]["source"] == tower, "转发 source 应为命中塔")
		assert_eq(spy.calls[0]["hit_direction"], Vector2.RIGHT, "转发应透传命中方向")
	assert_eq(enemy.status().gauge, gauge_before, "转发本身不得动 gauge(裁决归 ReactionSystem)")
	assert_true(enemy.status().element == fire, "转发本身不得改 element")
	enemy.free()
	tower.free()
	spy.free()

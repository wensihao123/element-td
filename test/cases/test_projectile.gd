extends TestCase

## 弹丸单测(PLAN 04 Phase 3):真 enemy.tscn + 真 ReactionSystem + 真反应表走完整
## 命中管线;手动 tick 确定性。期望值全由 def / cfg / 效果字段推导,不硬编码语义。
## 塔数值取真 ice_basic.tres / fire_basic.tres(D8 占位数值的权威来源)。

const ENEMY_SCENE_PATH: String = "res://scenes/enemies/enemy.tscn"
const PROJECTILE_SCENE_PATH: String = "res://scenes/towers/projectile.tscn"
const RS_SCRIPT_PATH: String = "res://scripts/systems/reaction_system.gd"
const CONFIG_PATH: String = "res://data/balance/global_config.tres"
const HOUND_PATH: String = "res://data/enemies/lava_hound.tres"
const ICE_TOWER_PATH: String = "res://data/towers/ice_basic.tres"
const FIRE_PATH: String = "res://data/elements/fire.tres"
const STEAM_PATH: String = "res://data/reactions/steam_burst.tres"
const REACTION_PATHS: Array[String] = [
	"res://data/reactions/steam_burst.tres",
	"res://data/reactions/overload.tres",
	"res://data/reactions/combustion.tres",
	"res://data/reactions/superconduct.tres",
	"res://data/reactions/brittle.tres",
	"res://data/reactions/electrolysis.tres",
]


func _tree_root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _make_rs(cfg: GaugeConfig, bus: RecordingBus) -> Node:
	var rs: Node = (load(RS_SCRIPT_PATH) as GDScript).new() as Node
	var reactions: Array[ReactionDef] = []
	for path: String in REACTION_PATHS:
		reactions.append(load(path) as ReactionDef)
	rs.call("setup", cfg, reactions, bus)
	return rs


## 真敌人:显式注入 cfg/rs/bus 后入树(02-D1),再摆到指定位置。
func _spawn_enemy(def: EnemyDef, cfg: GaugeConfig, rs: Node, bus: RecordingBus,
		pos: Vector2) -> Enemy:
	var enemy: Enemy = (load(ENEMY_SCENE_PATH) as PackedScene).instantiate() as Enemy
	enemy.setup(def, null)
	var status: StatusComponent = enemy.get_node("StatusComponent") as StatusComponent
	status.cfg = cfg
	status.reaction_system = rs
	enemy.bus = bus
	_tree_root().add_child(enemy)
	enemy.global_position = pos
	return enemy


## 弹丸:setup 注入后入树,再显式摆位(source 传纯 Node 塔替身,不触发出生吸附)。
func _spawn_projectile(target: Node2D, speed_px: float, damage: float,
		element: ElementDef, attach: float, source: Node, pos: Vector2) -> Projectile:
	var projectile: Projectile = \
			(load(PROJECTILE_SCENE_PATH) as PackedScene).instantiate() as Projectile
	projectile.setup(target, speed_px, damage, element, attach, source)
	_tree_root().add_child(projectile)
	projectile.global_position = pos
	return projectile


func _cleanup(nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


## 断言组①:命中后 gauge 与 hp 同帧变化,顺序 = 先附着后投伤——满血熔岩犬(innate 火)
## 受冰弹,steam_burst 反应触发,AoE 伤害与直伤同帧全部入账。
func test_hit_attaches_before_damage_and_triggers_reaction() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var bus: RecordingBus = RecordingBus.new()
	var rs: Node = _make_rs(cfg, bus)
	var hound_def: EnemyDef = load(HOUND_PATH) as EnemyDef
	var ice_tower: TowerDef = load(ICE_TOWER_PATH) as TowerDef
	var steam: ReactionDef = load(STEAM_PATH) as ReactionDef
	var aoe: AoeDamageEffect = steam.effects[0] as AoeDamageEffect
	var tower_stub: Node = Node.new()
	var enemy: Enemy = _spawn_enemy(hound_def, cfg, rs, bus, Vector2(100.0, 0.0))
	var health: HealthComponent = enemy.get_node("HealthComponent") as HealthComponent
	var status: StatusComponent = enemy.get_node("StatusComponent") as StatusComponent
	assert_eq(status.gauge, cfg.default_attach, "前置:innate 火已附着(全局附着量)")
	var projectile: Projectile = _spawn_projectile(enemy, 1000.0, ice_tower.damage,
			ice_tower.element, ice_tower.get_attach(cfg), tower_stub, Vector2.ZERO)
	projectile.tick(1.0)
	assert_eq(bus.events.size(), 1, "冰弹命中带火目标应触发恰一次反应")
	if not bus.events.is_empty():
		assert_true(bus.events[0]["reaction"] == steam, "反应应为 steam_burst")
		assert_true(bus.events[0]["source"] == tower_stub, "反应归属应为弹丸 source(塔)")
	var expected_hp: float = hound_def.max_hp \
			- maxf(aoe.damage - hound_def.armor, 0.0) \
			- maxf(ice_tower.damage - hound_def.armor, 0.0)
	assert_eq(health.hp, expected_hp,
			"AoE 反应伤与直伤应同帧全部入账(先附着后投伤,经护甲)")
	assert_eq(status.gauge, cfg.default_attach - steam.get_cost(cfg),
			"gauge 应同帧被反应消耗(余量 = 附着 - get_cost)")
	assert_true(status.element != null and status.element.id == &"fire",
			"incoming 冰被反应消耗,附着元素应仍为火")
	assert_true(projectile.is_queued_for_deletion(), "命中后弹丸应自毁")
	_cleanup([projectile, enemy, rs, bus, tower_stub] as Array[Node])


## 断言组②:目标已 queued → gauge/hp 双双不动、无反应、弹丸自毁。
func test_queued_target_discards_whole_hit() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var bus: RecordingBus = RecordingBus.new()
	var rs: Node = _make_rs(cfg, bus)
	var hound_def: EnemyDef = load(HOUND_PATH) as EnemyDef
	var ice_tower: TowerDef = load(ICE_TOWER_PATH) as TowerDef
	var tower_stub: Node = Node.new()
	var enemy: Enemy = _spawn_enemy(hound_def, cfg, rs, bus, Vector2(10.0, 0.0))
	var health: HealthComponent = enemy.get_node("HealthComponent") as HealthComponent
	var status: StatusComponent = enemy.get_node("StatusComponent") as StatusComponent
	var gauge_before: float = status.gauge
	var hp_before: float = health.hp
	enemy.queue_free()
	var projectile: Projectile = _spawn_projectile(enemy, 1000.0, ice_tower.damage,
			ice_tower.element, ice_tower.get_attach(cfg), tower_stub, Vector2.ZERO)
	projectile.tick(1.0)
	assert_eq(status.gauge, gauge_before, "目标已 queued:gauge 不得变化")
	assert_eq(health.hp, hp_before, "目标已 queued:hp 不得变化")
	assert_eq(bus.events.size(), 0, "目标已 queued:不得触发反应")
	assert_true(projectile.is_queued_for_deletion(), "目标已 queued:弹丸应自毁")
	_cleanup([projectile, enemy, rs, bus, tower_stub] as Array[Node])


## 断言组③:飞行中目标被 free → 弹丸自毁不崩。
func test_freed_target_self_destructs_without_crash() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var bus: RecordingBus = RecordingBus.new()
	var rs: Node = _make_rs(cfg, bus)
	var hound_def: EnemyDef = load(HOUND_PATH) as EnemyDef
	var ice_tower: TowerDef = load(ICE_TOWER_PATH) as TowerDef
	var tower_stub: Node = Node.new()
	var enemy: Enemy = _spawn_enemy(hound_def, cfg, rs, bus, Vector2(500.0, 0.0))
	var projectile: Projectile = _spawn_projectile(enemy, 100.0, ice_tower.damage,
			ice_tower.element, ice_tower.get_attach(cfg), tower_stub, Vector2.ZERO)
	projectile.tick(0.1)
	assert_true(not projectile.is_queued_for_deletion(), "前置:目标尚在,弹丸飞行中")
	_tree_root().remove_child(enemy)
	enemy.free()
	projectile.tick(0.1)
	assert_true(projectile.is_queued_for_deletion(), "目标被释放:弹丸应自毁(不追尸不换目标)")
	_cleanup([projectile, rs, bus, tower_stub] as Array[Node])


## 断言组④:大步长 tick 一帧跨过目标 → 恰好命中一次(StubEnemy 记调用面)。
func test_big_step_hits_exactly_once() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var tower_stub: Node = Node.new()
	var stub: StubEnemy = StubEnemy.new()
	stub.status().cfg = cfg
	_tree_root().add_child(stub)
	stub.global_position = Vector2(50.0, 0.0)
	var projectile: Projectile = _spawn_projectile(stub, 1000.0, 5.0,
			fire, cfg.default_attach, tower_stub, Vector2.ZERO)
	projectile.tick(1.0)
	assert_eq(stub.damage_calls.size(), 1, "大步长跨过目标应恰好命中一次")
	assert_true(projectile.is_queued_for_deletion(), "命中后弹丸应自毁")
	projectile.tick(1.0)
	assert_eq(stub.damage_calls.size(), 1, "自毁后再 tick 不得重复命中")
	assert_true(stub.status().element == fire, "命中应完成元素附着(单元素无反应)")
	_cleanup([projectile, stub, tower_stub] as Array[Node])

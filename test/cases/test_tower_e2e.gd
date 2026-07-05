extends TestCase

## 塔↔敌 e2e(PLAN 04 Phase 3):真 tower.tscn(内联 projectile.tscn)对真 enemy.tscn,
## 走完整链路 索敌 → 开火 → 弹丸飞行 → 命中 → 附着/反应 → 投伤 → 死亡信号。
## 全程手动 tick 确定性(weapon.tick + 逐弹丸 tick);敌人不移动(不 tick 敌人)。
## 数值全取真 .tres(D8 塔 / 03 敌人 / 02 反应),期望值经计算推导。

const TOWER_SCENE_PATH: String = "res://scenes/towers/tower.tscn"
const ENEMY_SCENE_PATH: String = "res://scenes/enemies/enemy.tscn"
const RS_SCRIPT_PATH: String = "res://scripts/systems/reaction_system.gd"
const CONFIG_PATH: String = "res://data/balance/global_config.tres"
const GRID_CONFIG_PATH: String = "res://data/balance/grid_config.tres"
const RUNNER_PATH: String = "res://data/enemies/runner.tres"
const HOUND_PATH: String = "res://data/enemies/lava_hound.tres"
const FIRE_TOWER_PATH: String = "res://data/towers/fire_basic.tres"
const ICE_TOWER_PATH: String = "res://data/towers/ice_basic.tres"
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


func _spawn_enemy(def: EnemyDef, cfg: GaugeConfig, rs: Node, bus: RecordingBus,
		pos: Vector2, progress: float) -> Enemy:
	var enemy: Enemy = (load(ENEMY_SCENE_PATH) as PackedScene).instantiate() as Enemy
	enemy.setup(def, null)
	var status: StatusComponent = enemy.get_node("StatusComponent") as StatusComponent
	status.cfg = cfg
	status.reaction_system = rs
	enemy.bus = bus
	_tree_root().add_child(enemy)
	enemy.global_position = pos
	enemy.progress = progress
	return enemy


func _spawn_tower(def_path: String, cfg: GaugeConfig, pos: Vector2) -> Tower:
	var tower: Tower = (load(TOWER_SCENE_PATH) as PackedScene).instantiate() as Tower
	tower.grid_cfg = load(GRID_CONFIG_PATH) as GridConfig
	tower.gauge_cfg = cfg
	tower.setup(load(def_path) as TowerDef)
	_tree_root().add_child(tower)
	tower.global_position = pos
	return tower


## 大步长逐弹丸 tick:速度 × 10s 步长必然 ≥ 剩余距离,当帧结算(D7 判定确定性)。
func _resolve_projectiles(tower: Tower) -> void:
	var spawner: Node = tower.get_node("ProjectileSpawner")
	for child: Node in spawner.get_children():
		var projectile: Projectile = child as Projectile
		if projectile != null and not projectile.is_queued_for_deletion():
			projectile.tick(10.0)


func _cleanup(nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func test_fire_tower_kills_runner_died_exactly_once() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var bus: RecordingBus = RecordingBus.new()
	var rs: Node = _make_rs(cfg, bus)
	var runner_def: EnemyDef = load(RUNNER_PATH) as EnemyDef
	var fire_def: TowerDef = load(FIRE_TOWER_PATH) as TowerDef
	var enemy: Enemy = _spawn_enemy(runner_def, cfg, rs, bus, Vector2.ZERO, 5.0)
	var tower: Tower = _spawn_tower(FIRE_TOWER_PATH, cfg, Vector2(0.0, 64.0))
	var weapon: Weapon = tower.get_node("Weapon") as Weapon
	var expected_shots: int = int(ceilf(
			runner_def.max_hp / maxf(fire_def.damage - runner_def.armor, 0.001)))
	var shots: int = 0
	while bus.died.is_empty() and shots < expected_shots + 5:
		weapon.tick(fire_def.fire_interval)
		_resolve_projectiles(tower)
		shots += 1
	assert_eq(bus.died.size(), 1, "连发直至击杀:enemy_died 应恰发一次")
	if not bus.died.is_empty():
		assert_true(bus.died[0]["def"] == runner_def, "死亡信号应携带 runner def")
	assert_eq(shots, expected_shots, "击杀所需发数应可由 hp/(damage-armor) 推导(确定性)")
	weapon.tick(fire_def.fire_interval)
	_resolve_projectiles(tower)
	assert_eq(bus.died.size(), 1, "目标死后(queued)不得再命中/重发死亡信号")
	assert_eq(bus.events.size(), 0, "单元素(火弹打无附着 runner)全程不得触发反应")
	_cleanup([tower, enemy, rs, bus] as Array[Node])


func test_ice_tower_first_shot_reacts_on_innate_fire_hound_with_aoe() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var bus: RecordingBus = RecordingBus.new()
	var rs: Node = _make_rs(cfg, bus)
	var hound_def: EnemyDef = load(HOUND_PATH) as EnemyDef
	var runner_def: EnemyDef = load(RUNNER_PATH) as EnemyDef
	var ice_def: TowerDef = load(ICE_TOWER_PATH) as TowerDef
	var steam: ReactionDef = load(STEAM_PATH) as ReactionDef
	var aoe: AoeDamageEffect = steam.effects[0] as AoeDamageEffect
	var hound: Enemy = _spawn_enemy(hound_def, cfg, rs, bus, Vector2.ZERO, 10.0)
	var runner: Enemy = _spawn_enemy(runner_def, cfg, rs, bus,
			Vector2(aoe.radius * 0.5, 0.0), 1.0)
	var runner_health: HealthComponent = runner.get_node("HealthComponent") as HealthComponent
	var tower: Tower = _spawn_tower(ICE_TOWER_PATH, cfg, Vector2(0.0, 64.0))
	var weapon: Weapon = tower.get_node("Weapon") as Weapon
	weapon.tick(0.0)
	_resolve_projectiles(tower)
	assert_eq(bus.events.size(), 1, "冰塔首发命中 innate 火熔岩犬应即触发反应")
	if not bus.events.is_empty():
		assert_true(bus.events[0]["reaction"] == steam, "反应应为 steam_burst")
		assert_true(bus.events[0]["target"] == hound, "反应 target 应为熔岩犬(progress 最大)")
		assert_true(bus.events[0]["source"] == tower, "反应归属应为触发方塔(铁律)")
	var expected_runner_hp: float = maxf(
			runner_def.max_hp - maxf(aoe.damage - runner_def.armor, 0.0), 0.0)
	assert_eq(runner_health.hp, expected_runner_hp,
			"邻近 runner 应吃到 AoE 反应伤害(经护甲,hp 钳 0)")
	if expected_runner_hp == 0.0:
		assert_eq(bus.died.size(), 1, "AoE 致死应发 runner 的 enemy_died(击杀弹反应链路)")
		if not bus.died.is_empty():
			assert_true(bus.died[0]["def"] == runner_def, "死亡信号应携带 runner def")
	var hound_status: StatusComponent = hound.get_node("StatusComponent") as StatusComponent
	assert_eq(hound_status.gauge, cfg.default_attach - steam.get_cost(cfg),
			"熔岩犬 gauge 应被反应消耗")
	_cleanup([tower, hound, runner, rs, bus] as Array[Node])

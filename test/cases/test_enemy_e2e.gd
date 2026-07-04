extends TestCase

## 真敌人过真反应端到端复核(PLAN 03 Phase 1 末步;销 02 flag ③、固化 01/02 flag ④ 数据点)。
## 真 enemy.tscn + 真 data/*.tres + 真 ReactionSystem.setup 装配,沿 02 e2e 入树模式;
## 02 的伤害断言只到「调用面」,本用例穿透护甲公式断言真血精确数值。
## EnemyDef 为测试哨兵(max_hp 100 / speed 10 / armor 按档注入),cfg/元素/反应全真。

const ENEMY_SCENE_PATH: String = "res://scenes/enemies/enemy.tscn"
const RS_SCRIPT_PATH: String = "res://scripts/systems/reaction_system.gd"
const CONFIG_PATH: String = "res://data/balance/global_config.tres"
const FIRE_PATH: String = "res://data/elements/fire.tres"
const ICE_PATH: String = "res://data/elements/ice.tres"
const POISON_PATH: String = "res://data/elements/poison.tres"
const REACTION_PATHS: Array[String] = [
	"res://data/reactions/steam_burst.tres",
	"res://data/reactions/overload.tres",
	"res://data/reactions/combustion.tres",
	"res://data/reactions/superconduct.tres",
	"res://data/reactions/brittle.tres",
	"res://data/reactions/electrolysis.tres",
]

const MAX_HP: float = 100.0
const SPEED: float = 10.0


func _tree_root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _make_def(armor: float) -> EnemyDef:
	var def: EnemyDef = EnemyDef.new()
	def.id = &"e2e_enemy"
	def.max_hp = MAX_HP
	def.speed = SPEED
	def.armor = armor
	def.gold_reward = 1
	return def


## 全真装配:真 cfg + 真反应表注入的 ReactionSystem + 真 enemy.tscn 入树。
func _rig(armor: float, path: Path2D = null) -> Dictionary:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var bus: RecordingBus = RecordingBus.new()
	var rs: Node = (load(RS_SCRIPT_PATH) as GDScript).new() as Node
	var reactions: Array[ReactionDef] = []
	for reaction_path: String in REACTION_PATHS:
		reactions.append(load(reaction_path) as ReactionDef)
	rs.call("setup", cfg, reactions, bus)
	var tower: Node = Node.new()
	var enemy: Enemy = (load(ENEMY_SCENE_PATH) as PackedScene).instantiate() as Enemy
	enemy.setup(_make_def(armor), path)
	var status: StatusComponent = enemy.get_node("StatusComponent") as StatusComponent
	status.cfg = cfg
	status.reaction_system = rs
	enemy.bus = bus
	_tree_root().add_child(enemy)
	return {"cfg": cfg, "bus": bus, "rs": rs, "tower": tower,
			"enemy": enemy, "status": status,
			"health": enemy.get_node("HealthComponent") as HealthComponent}


func _cleanup(rig: Dictionary, extras: Array[Node] = []) -> void:
	var nodes: Array[Node] = [rig["enemy"], rig["rs"], rig["bus"], rig["tower"]]
	nodes.append_array(extras)
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func test_steam_burst_damage_through_armor_ladder() -> void:
	var steam_burst: ReactionDef = load(REACTION_PATHS[0]) as ReactionDef
	var aoe: AoeDamageEffect = steam_burst.effects[0] as AoeDamageEffect
	for armor: float in [0.0, 2.0]:
		var rig: Dictionary = _rig(armor)
		var cfg: GaugeConfig = rig["cfg"]
		var status: StatusComponent = rig["status"]
		status.apply_element(load(FIRE_PATH) as ElementDef, cfg.default_attach, rig["tower"])
		status.apply_element(load(ICE_PATH) as ElementDef, cfg.default_attach, rig["tower"])
		var bus: RecordingBus = rig["bus"]
		assert_eq(bus.events.size(), 1, "armor %s:火+冰应触发一次反应" % str(armor))
		var health: HealthComponent = rig["health"]
		var expected_hp: float = MAX_HP - maxf(aoe.damage - armor, 0.0)
		assert_true(is_equal_approx(health.hp, expected_hp),
				"armor %s:蒸汽爆破 AoE %s 伤经护甲公式应剩 %s(实际:%s)" %
				[str(armor), str(aoe.damage), str(expected_hp), str(health.hp)])
		_cleanup(rig)


func test_poison_corrosion_adds_two_damage_on_armor_zero() -> void:
	var poisoned: Dictionary = _rig(0.0)
	var plain: Dictionary = _rig(0.0)
	var cfg: GaugeConfig = poisoned["cfg"]
	(poisoned["status"] as StatusComponent).apply_element(
			load(POISON_PATH) as ElementDef, cfg.default_attach, poisoned["tower"])
	var hit_amount: float = 10.0
	(poisoned["enemy"] as Enemy).take_damage(hit_amount, poisoned["tower"])
	(plain["enemy"] as Enemy).take_damage(hit_amount, plain["tower"])
	var poisoned_loss: float = MAX_HP - (poisoned["health"] as HealthComponent).hp
	var plain_loss: float = MAX_HP - (plain["health"] as HealthComponent).hp
	assert_true(is_equal_approx(plain_loss, hit_amount),
			"对照组 armor 0 应恰扣命中额(实际扣:%s)" % str(plain_loss))
	assert_true(is_equal_approx(poisoned_loss, plain_loss + 2.0),
			"毒腐蚀 armor -2 → 同额伤害在 armor 0 怪上应多扣 2(负甲增伤数据点,%s vs %s)" %
			[str(poisoned_loss), str(plain_loss)])
	_cleanup(poisoned)
	_cleanup(plain)


func test_ice_attachment_slows_tick_by_thirty_percent() -> void:
	var path: Path2D = Path2D.new()
	var curve: Curve2D = Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	_tree_root().add_child(path)
	var rig: Dictionary = _rig(0.0, path)
	var cfg: GaugeConfig = rig["cfg"]
	(rig["status"] as StatusComponent).apply_element(
			load(ICE_PATH) as ElementDef, cfg.default_attach, rig["tower"])
	var enemy: Enemy = rig["enemy"]
	enemy.tick(1.0)
	assert_true(is_equal_approx(enemy.progress, SPEED * 0.7),
			"冰附着(base_status 减速 -30%%)后 tick 1s 应前进 %s(实际:%s)" %
			[str(SPEED * 0.7), str(enemy.progress)])
	_cleanup(rig, [path])
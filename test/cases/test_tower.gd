extends TestCase

## Tower 根实体测试(PLAN 04 Phase 2):真 tower.tscn 实例化 + 显式注入 cfg(不依赖
## 单例)+ setup 断言;range/speed 换算断言经计算(def × tile_size),不硬编码期望值。

const TOWER_SCENE_PATH: String = "res://scenes/towers/tower.tscn"
const GRID_CONFIG_PATH: String = "res://data/balance/grid_config.tres"
const CONFIG_PATH: String = "res://data/balance/global_config.tres"
const FIRE_PATH: String = "res://data/elements/fire.tres"


func _tree_root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _make_def() -> TowerDef:
	var def: TowerDef = TowerDef.new()
	def.id = &"test_tower"
	def.element = load(FIRE_PATH) as ElementDef
	def.damage = 5.0
	def.fire_interval = 0.8
	def.attack_range = 2.5
	def.projectile_speed = 6.0
	def.attach_override = -1.0
	return def


func test_components_discovered_and_def_params_converted() -> void:
	var grid_cfg: GridConfig = load(GRID_CONFIG_PATH) as GridConfig
	var gauge_cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	assert_true(grid_cfg != null and grid_cfg.tile_size > 0.0, "前置:grid_config.tres 可加载且 tile_size 有效")
	var tower: Tower = (load(TOWER_SCENE_PATH) as PackedScene).instantiate() as Tower
	assert_true(tower != null, "tower.tscn 根应为 Tower")
	tower.grid_cfg = grid_cfg
	tower.gauge_cfg = gauge_cfg
	var def: TowerDef = _make_def()
	tower.setup(def)
	_tree_root().add_child(tower)
	for component_name: String in ["Targeting", "Weapon", "ProjectileSpawner", "Visual"]:
		assert_true(tower.get_node_or_null(component_name) != null,
				"具名子节点 %s 应可发现" % component_name)
	var weapon: Weapon = tower.get_node_or_null("Weapon") as Weapon
	if weapon != null:
		assert_eq(weapon.range_px, def.attack_range * grid_cfg.tile_size,
				"range 应换算 tile→px(def × tile_size)")
		assert_eq(weapon.speed_px, def.projectile_speed * grid_cfg.tile_size,
				"projectile_speed 应换算 tile→px")
		assert_eq(weapon.damage, def.damage, "damage 应透传")
		assert_eq(weapon.fire_interval, def.fire_interval, "fire_interval 应透传")
		assert_true(weapon.element == def.element, "element 应透传")
		assert_eq(weapon.attach_amount, def.get_attach(gauge_cfg),
				"附着量应经 get_attach(override -1 → 全局 default_attach)")
		assert_true(weapon.source == tower, "weapon.source 应为塔根")
	var visual: Polygon2D = tower.get_node_or_null("Visual") as Polygon2D
	if visual != null and def.element != null:
		assert_true(visual.color == def.element.color, "占位视觉应按元素色染色")
	tower.get_parent().remove_child(tower)
	tower.free()

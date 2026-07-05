extends TestCase

## 数据完整性测试:载入全部 .tres,断言结构约束(02 建立;03 扩敌人/波次)。
## 期望值 2/1/3/0/0.5 为 MVP 基准(项目说明 §2.2),权威来源是 global_config.tres 本身。

const CONFIG_PATH: String = "res://data/balance/global_config.tres"
const ELEMENT_PATHS: Array[String] = [
	"res://data/elements/fire.tres",
	"res://data/elements/ice.tres",
	"res://data/elements/lightning.tres",
	"res://data/elements/poison.tres",
]
const REACTION_PATHS: Array[String] = [
	"res://data/reactions/steam_burst.tres",
	"res://data/reactions/overload.tres",
	"res://data/reactions/combustion.tres",
	"res://data/reactions/superconduct.tres",
	"res://data/reactions/brittle.tres",
	"res://data/reactions/electrolysis.tres",
]


func test_global_config_matches_mvp_baseline() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	assert_true(cfg != null, "global_config.tres 应能加载为 GaugeConfig")
	if cfg == null:
		return
	assert_eq(cfg.default_attach, 2.0, "default_attach 应为 MVP 基准 2U")
	assert_eq(cfg.default_cost, 1.0, "default_cost 应为 MVP 基准 1U")
	assert_eq(cfg.max_gauge, 3.0, "max_gauge 应为 MVP 基准 3U")
	assert_eq(cfg.decay_per_sec, 0.0, "decay_per_sec 应为 MVP 基准 0")
	assert_eq(cfg.reaction_icd, 0.5, "reaction_icd 应为 MVP 基准 0.5s")


func test_elements_unique_ids_and_base_status() -> void:
	var ids: Array[StringName] = []
	for path: String in ELEMENT_PATHS:
		var element: ElementDef = load(path) as ElementDef
		assert_true(element != null, "%s 应能加载为 ElementDef" % path)
		if element == null:
			continue
		assert_true(element.id != &"", "%s 的 id 不得为空" % path)
		assert_true(not ids.has(element.id), "元素 id 重复:%s" % element.id)
		ids.append(element.id)
		assert_true(not element.base_status.is_empty(), "%s 的 base_status 不得为空" % path)
	assert_eq(ids.size(), 4, "应恰好 4 个元素")


func test_reactions_cover_all_pairs() -> void:
	var element_ids: Array[String] = []
	for path: String in ELEMENT_PATHS:
		var element: ElementDef = load(path) as ElementDef
		if element != null:
			element_ids.append(String(element.id))
	element_ids.sort()
	var expected_keys: Array[String] = []
	for i: int in range(element_ids.size()):
		for j: int in range(i + 1, element_ids.size()):
			expected_keys.append("%s+%s" % [element_ids[i], element_ids[j]])

	var seen_keys: Array[String] = []
	for path: String in REACTION_PATHS:
		var reaction: ReactionDef = load(path) as ReactionDef
		assert_true(reaction != null, "%s 应能加载为 ReactionDef" % path)
		if reaction == null:
			continue
		assert_true(reaction.element_a != null and reaction.element_b != null,
				"%s 的元素引用不得为空" % path)
		if reaction.element_a == null or reaction.element_b == null:
			continue
		assert_true(reaction.element_a.id != reaction.element_b.id, "%s 不得自反(a != b)" % path)
		var pair: Array[String] = [String(reaction.element_a.id), String(reaction.element_b.id)]
		pair.sort()
		var key: String = "%s+%s" % [pair[0], pair[1]]
		assert_true(not seen_keys.has(key), "反应无序对重复:%s" % key)
		seen_keys.append(key)
		assert_true(not reaction.effects.is_empty(), "%s 的 effects 不得为空" % path)
		for effect: ReactionEffect in reaction.effects:
			assert_true(effect != null, "%s 存在空效果槽" % path)
			var propagate: PropagateEffect = effect as PropagateEffect
			if propagate != null:
				assert_true(propagate.inner != null, "%s 的 PropagateEffect.inner 不得为空" % path)
	seen_keys.sort()
	assert_eq(str(seen_keys), str(expected_keys), "6 个反应应恰好覆盖 4 元素的全部无序对")


const ENEMY_PATHS: Array[String] = [
	"res://data/enemies/runner.tres",
	"res://data/enemies/lava_hound.tres",
]
const DEV_WAVE_PATH: String = "res://data/waves/dev_wave.tres"


func test_enemy_defs_integrity() -> void:
	var ids: Array[StringName] = []
	for path: String in ENEMY_PATHS:
		var def: EnemyDef = load(path) as EnemyDef
		assert_true(def != null, "%s 应能加载为 EnemyDef" % path)
		if def == null:
			continue
		assert_true(def.id != &"", "%s 的 id 不得为空" % path)
		assert_true(not ids.has(def.id), "敌人 id 重复:%s" % def.id)
		ids.append(def.id)
		assert_true(def.max_hp > 0.0, "%s 的 max_hp 应 > 0" % path)
		assert_true(def.speed > 0.0, "%s 的 speed 应 > 0" % path)
		assert_true(def.gold_reward > 0, "%s 的 gold_reward 应 > 0" % path)


func test_lava_hound_innate_is_fire() -> void:
	var hound: EnemyDef = load("res://data/enemies/lava_hound.tres") as EnemyDef
	assert_true(hound != null and hound.innate_element != null,
			"lava_hound 应引用 innate 元素")
	if hound != null and hound.innate_element != null:
		assert_eq(hound.innate_element.id, &"fire", "lava_hound.innate_element 应为火")


func test_dev_wave_integrity() -> void:
	var wave: WaveDef = load(DEV_WAVE_PATH) as WaveDef
	assert_true(wave != null, "dev_wave.tres 应能加载为 WaveDef")
	if wave == null:
		return
	assert_true(not wave.entries.is_empty(), "dev_wave entries 不得为空")
	for entry: SpawnEntry in wave.entries:
		assert_true(entry != null and entry.enemy != null,
				"dev_wave 每条目的 enemy 引用不得为空")


const TOWER_PATHS: Array[String] = [
	"res://data/towers/fire_basic.tres",
	"res://data/towers/ice_basic.tres",
	"res://data/towers/lightning_basic.tres",
	"res://data/towers/poison_basic.tres",
]
const GRID_CONFIG_PATH: String = "res://data/balance/grid_config.tres"


func test_grid_config_matches_mvp_baseline() -> void:
	var cfg: GridConfig = load(GRID_CONFIG_PATH) as GridConfig
	assert_true(cfg != null, "grid_config.tres 应能加载为 GridConfig")
	if cfg == null:
		return
	assert_eq(cfg.tile_size, 64.0, "tile_size 应为 04-D1 基准 64px")


func test_tower_defs_integrity() -> void:
	var ids: Array[StringName] = []
	var element_ids: Array[StringName] = []
	for path: String in TOWER_PATHS:
		var def: TowerDef = load(path) as TowerDef
		assert_true(def != null, "%s 应能加载为 TowerDef" % path)
		if def == null:
			continue
		assert_true(def.id != &"", "%s 的 id 不得为空" % path)
		assert_true(not ids.has(def.id), "塔 id 重复:%s" % def.id)
		ids.append(def.id)
		assert_true(def.element != null, "%s 的 element 引用不得为空" % path)
		if def.element != null:
			assert_true(not element_ids.has(def.element.id),
					"塔 element 重复:%s" % def.element.id)
			element_ids.append(def.element.id)
		assert_true(def.damage > 0.0, "%s 的 damage 应 > 0" % path)
		assert_true(def.fire_interval > 0.0, "%s 的 fire_interval 应 > 0" % path)
		assert_true(def.attack_range > 0.0, "%s 的 attack_range 应 > 0(tile 单位)" % path)
		assert_true(def.projectile_speed > 0.0, "%s 的 projectile_speed 应 > 0(tile/s)" % path)
		assert_true(def.cost_gold > 0, "%s 的 cost_gold 应 > 0(04 占位,06 消费)" % path)
	assert_eq(ids.size(), 4, "应恰好 4 座基础塔")


func test_balance_autoload_registered() -> void:
	assert_true(ProjectSettings.has_setting("autoload/Balance"),
			"project.godot 应注册 Balance autoload")

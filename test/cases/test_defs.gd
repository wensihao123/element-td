extends TestCase

## defs 的 override 解析单测(PLAN Phase 2 末步)。
## 注入本地构造的 GaugeConfig(哨兵值,非游戏数值),不依赖 autoload 与 .tres。


func test_tower_attach_override() -> void:
	var cfg: GaugeConfig = GaugeConfig.new()
	cfg.default_attach = 2.5
	var tower: TowerDef = TowerDef.new()
	tower.attach_override = -1.0
	assert_eq(tower.get_attach(cfg), 2.5, "attach_override = -1.0 应回落全局默认")
	tower.attach_override = 4.0
	assert_eq(tower.get_attach(cfg), 4.0, "attach_override >= 0 应用覆盖值")
	tower.attach_override = 0.0
	assert_eq(tower.get_attach(cfg), 0.0, "attach_override = 0.0 是有效覆盖(非回落)")


func test_wave_defs_defaults_and_composition() -> void:
	var entry: SpawnEntry = SpawnEntry.new()
	assert_true(entry.enemy == null, "SpawnEntry.enemy 默认应为 null")
	assert_eq(entry.count, 0, "SpawnEntry.count 默认应为 0")
	assert_eq(entry.spawn_interval, 0.0, "SpawnEntry.spawn_interval 默认应为 0.0")
	assert_eq(entry.start_delay, 0.0, "SpawnEntry.start_delay 默认应为 0.0")
	var wave: WaveDef = WaveDef.new()
	assert_true(wave.entries.is_empty(), "WaveDef.entries 默认应为空数组")
	wave.entries.append(entry)
	assert_eq(wave.entries.size(), 1, "entries 应可装载 SpawnEntry(类型化数组)")


func test_reaction_cost_override() -> void:
	var cfg: GaugeConfig = GaugeConfig.new()
	cfg.default_cost = 1.5
	var reaction: ReactionDef = ReactionDef.new()
	reaction.gauge_cost_override = -1.0
	assert_eq(reaction.get_cost(cfg), 1.5, "gauge_cost_override = -1.0 应回落全局默认")
	reaction.gauge_cost_override = 2.0
	assert_eq(reaction.get_cost(cfg), 2.0, "gauge_cost_override >= 0 应用覆盖值")
	reaction.gauge_cost_override = 0.0
	assert_eq(reaction.get_cost(cfg), 0.0, "gauge_cost_override = 0.0 是有效覆盖(非回落)")

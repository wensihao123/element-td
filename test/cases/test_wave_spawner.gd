extends TestCase

## WaveSpawner 单测(PLAN 03 Phase 2):注入 RecordingBus + 手动 tick 确定性驱动。
## WaveDef/SpawnEntry/EnemyDef 本地构造(哨兵值);enemy_scene 用真 enemy.tscn。
## 路径设非零偏移,验证吐出的实例吸附路径起点的全局坐标。

const ENEMY_SCENE_PATH: String = "res://scenes/enemies/enemy.tscn"
const CONFIG_PATH: String = "res://data/balance/global_config.tres"
const FIRE_PATH: String = "res://data/elements/fire.tres"
const PATH_ORIGIN: Vector2 = Vector2(7.0, 13.0)


func _tree_root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _make_def(id_name: StringName, innate: ElementDef = null) -> EnemyDef:
	var def: EnemyDef = EnemyDef.new()
	def.id = id_name
	def.max_hp = 10.0
	def.speed = 10.0
	def.armor = 0.0
	def.gold_reward = 1
	def.innate_element = innate
	return def


func _make_entry(def: EnemyDef, count: int, interval: float, delay: float) -> SpawnEntry:
	var entry: SpawnEntry = SpawnEntry.new()
	entry.enemy = def
	entry.count = count
	entry.spawn_interval = interval
	entry.start_delay = delay
	return entry


func _make_wave(entries: Array[SpawnEntry]) -> WaveDef:
	var wave: WaveDef = WaveDef.new()
	wave.entries = entries
	return wave


func _make_rig() -> Dictionary:
	var bus: RecordingBus = RecordingBus.new()
	var path: Path2D = Path2D.new()
	path.position = PATH_ORIGIN
	var curve: Curve2D = Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	_tree_root().add_child(path)
	var spawner: WaveSpawner = WaveSpawner.new()
	spawner.enemy_scene = load(ENEMY_SCENE_PATH) as PackedScene
	spawner.path = path
	spawner.bus = bus
	_tree_root().add_child(spawner)
	return {"bus": bus, "path": path, "spawner": spawner}


func _cleanup(rig: Dictionary) -> void:
	for key: String in ["spawner", "path", "bus"]:
		var node: Node = rig[key]
		if not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func test_no_spawn_within_start_delay() -> void:
	var rig: Dictionary = _make_rig()
	var spawner: WaveSpawner = rig["spawner"]
	var bus: RecordingBus = rig["bus"]
	spawner.start_wave(_make_wave([_make_entry(_make_def(&"a"), 2, 1.0, 0.5)]))
	spawner.tick(0.25)
	assert_eq(bus.spawned.size(), 0, "start_delay 未满不得吐怪")
	spawner.tick(0.25)
	assert_eq(bus.spawned.size(), 1, "start_delay 满后首只应立即出生")
	_cleanup(rig)


func test_spawns_on_interval_boundaries_with_exact_count() -> void:
	var rig: Dictionary = _make_rig()
	var spawner: WaveSpawner = rig["spawner"]
	var bus: RecordingBus = rig["bus"]
	spawner.start_wave(_make_wave([_make_entry(_make_def(&"a"), 3, 1.0, 0.0)]))
	spawner.tick(0.0)
	assert_eq(bus.spawned.size(), 1, "delay 0:开波首 tick 应吐首只")
	spawner.tick(0.5)
	assert_eq(bus.spawned.size(), 1, "半个 interval 不得多吐")
	spawner.tick(0.5)
	assert_eq(bus.spawned.size(), 2, "满一个 interval 应吐第二只")
	spawner.tick(1.0)
	assert_eq(bus.spawned.size(), 3, "再满一个 interval 应吐第三只")
	spawner.tick(5.0)
	assert_eq(bus.spawned.size(), 3, "count 吐满后不得再吐")
	_cleanup(rig)


func test_entries_chain_in_order() -> void:
	var rig: Dictionary = _make_rig()
	var spawner: WaveSpawner = rig["spawner"]
	var bus: RecordingBus = rig["bus"]
	var def_a: EnemyDef = _make_def(&"a")
	var def_b: EnemyDef = _make_def(&"b")
	spawner.start_wave(_make_wave([
			_make_entry(def_a, 2, 1.0, 0.0),
			_make_entry(def_b, 1, 1.0, 2.0)]))
	spawner.tick(0.0)
	spawner.tick(1.0)
	assert_eq(bus.spawned.size(), 2, "条目 1 应先吐完两只")
	spawner.tick(1.5)
	assert_eq(bus.spawned.size(), 2, "条目 2 的 start_delay(相对条目 1 吐完)未满不得吐")
	spawner.tick(0.5)
	assert_eq(bus.spawned.size(), 3, "条目 2 delay 满应吐")
	var defs_in_order: Array[EnemyDef] = []
	for node: Node2D in bus.spawned:
		defs_in_order.append((node as Enemy).def)
	assert_true(defs_in_order == ([def_a, def_a, def_b] as Array[EnemyDef]),
			"吐怪顺序应为条目顺序:a a b")
	_cleanup(rig)


func test_wave_signals_exactly_once_in_order() -> void:
	var rig: Dictionary = _make_rig()
	var spawner: WaveSpawner = rig["spawner"]
	var bus: RecordingBus = rig["bus"]
	var wave: WaveDef = _make_wave([_make_entry(_make_def(&"a"), 2, 1.0, 0.5)])
	spawner.start_wave(wave)
	assert_eq(bus.waves_started.size(), 1, "start_wave 应即发 wave_started(首只前)")
	assert_eq(bus.spawned.size(), 0, "wave_started 时序应先于任何吐怪")
	assert_eq(bus.waves_spawn_finished.size(), 0, "未吐完不得发 wave_spawn_finished")
	spawner.tick(0.5)
	spawner.tick(0.75)
	assert_eq(bus.waves_spawn_finished.size(), 0, "中途不得发 wave_spawn_finished")
	spawner.tick(0.25)
	assert_eq(bus.spawned.size(), 2, "前置:两只都应吐出")
	assert_eq(bus.waves_spawn_finished.size(), 1, "最后一只吐出后应恰发一次 wave_spawn_finished")
	if not bus.waves_spawn_finished.is_empty():
		assert_true(bus.waves_spawn_finished[0] == wave, "wave_spawn_finished 应携带该波 def")
	assert_eq(bus.waves_started.size(), 1, "全程 wave_started 恰一次")
	spawner.tick(5.0)
	assert_eq(bus.waves_spawn_finished.size(), 1, "吐完后再 tick 不得重发")
	_cleanup(rig)


func test_spawned_instance_is_setup_at_path_start() -> void:
	var rig: Dictionary = _make_rig()
	var spawner: WaveSpawner = rig["spawner"]
	var bus: RecordingBus = rig["bus"]
	var def: EnemyDef = _make_def(&"a")
	spawner.start_wave(_make_wave([_make_entry(def, 1, 1.0, 0.0)]))
	spawner.tick(0.0)
	assert_eq(bus.spawned.size(), 1, "前置:应吐出一只")
	if bus.spawned.is_empty():
		_cleanup(rig)
		return
	var enemy: Enemy = bus.spawned[0] as Enemy
	assert_true(enemy != null, "吐出的实例应为 Enemy")
	assert_true(enemy.def == def, "实例应已 setup(def 匹配)")
	assert_true(enemy.path == rig["path"], "实例应已 setup(path 匹配)")
	assert_true(enemy.global_position.is_equal_approx(PATH_ORIGIN),
			"实例应位于路径起点的全局坐标(实际:%s)" % str(enemy.global_position))
	_cleanup(rig)


func test_innate_enemy_spawns_with_fire_attached() -> void:
	var rig: Dictionary = _make_rig()
	var spawner: WaveSpawner = rig["spawner"]
	var bus: RecordingBus = rig["bus"]
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	spawner.start_wave(_make_wave([_make_entry(_make_def(&"hound", fire), 1, 1.0, 0.0)]))
	spawner.tick(0.0)
	assert_eq(bus.spawned.size(), 1, "前置:应吐出一只")
	if bus.spawned.is_empty():
		_cleanup(rig)
		return
	var status: StatusComponent = bus.spawned[0].get_node("StatusComponent") as StatusComponent
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	assert_true(status.element != null and status.element.id == &"fire",
			"innate 怪出生即带火(经 Balance autoload 自接线 cfg)")
	assert_eq(status.gauge, cfg.default_attach, "innate 附着量应为全局 default_attach")
	_cleanup(rig)


func test_restart_during_active_wave_is_ignored() -> void:
	var rig: Dictionary = _make_rig()
	var spawner: WaveSpawner = rig["spawner"]
	var bus: RecordingBus = rig["bus"]
	var wave_a: WaveDef = _make_wave([_make_entry(_make_def(&"a"), 2, 1.0, 0.0)])
	var wave_b: WaveDef = _make_wave([_make_entry(_make_def(&"b"), 9, 1.0, 0.0)])
	spawner.start_wave(wave_a)
	spawner.tick(0.0)
	spawner.start_wave(wave_b)
	assert_eq(bus.waves_started.size(), 1, "波进行中重复 start_wave 应被忽略(不重发信号)")
	spawner.tick(10.0)
	assert_eq(bus.spawned.size(), 2, "吐怪总数应仍按原波 def(重复调用未劫持游标)")
	assert_eq(bus.waves_spawn_finished.size(), 1, "原波应正常吐完收尾")
	_cleanup(rig)

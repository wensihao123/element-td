extends Node2D

## dev 演武场(PLAN 03 Phase 3;仅开发验证用,非正式地图——正式交叉口地图归 06)。
## 编辑器 F6 运行:自动播 dev_wave,订阅 EventBus 五信号逐条 print(dev 工具允许 print)。

const DEV_WAVE_PATH: String = "res://data/waves/dev_wave.tres"
## dev 预置塔的 def(04 Phase 3:塔在 .tscn 摆位,def 由本脚本 _ready 注入)
const FIRE_TOWER_DEF_PATH: String = "res://data/towers/fire_basic.tres"

## ---- 以下均为 dev-only 摆塔工具数据(PLAN 04-D10),正式建造交互/格子数据源归 05/06 ----
const TOWER_SCENE_PATH: String = "res://scenes/towers/tower.tscn"
## 数字键 1–4 对应的塔 def(顺序即按键序)
const DEV_TOWER_DEF_PATHS: Array[String] = [
	"res://data/towers/fire_basic.tres",
	"res://data/towers/ice_basic.tres",
	"res://data/towers/lightning_basic.tres",
	"res://data/towers/poison_basic.tres",
]
## dev 视野格数(1152×648 @ 64px = 18×10)与路径带净空半径(px):
## 格心距路径曲线小于净空 = 视为路格不可建
const DEV_GRID_COLS: int = 18
const DEV_GRID_ROWS: int = 10
const DEV_PATH_CLEARANCE: float = 48.0

var _selected_index: int = 0
var _dev_cells: Array[Vector2i] = []

@onready var _spawner: WaveSpawner = $WaveSpawner
@onready var _preset_tower: Tower = $PresetFireTower
@onready var _grid: BuildGrid = $BuildGrid
@onready var _path: Path2D = $Path2D


func _ready() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus == null:
		push_warning("dev_playground:EventBus autoload 缺失,无信号日志")
	else:
		bus.connect(&"wave_started", func(wave: WaveDef) -> void:
				print("[dev] wave_started(%d 条目)" % wave.entries.size()))
		bus.connect(&"enemy_spawned", func(enemy: Node2D) -> void:
				print("[dev] enemy_spawned:%s @ %s" % [_id_of(enemy), str(enemy.global_position)])
				var status: StatusComponent = \
						enemy.get_node_or_null("StatusComponent") as StatusComponent
				if status != null and status.element != null:
					print("[dev]   innate 附着:%s(gauge %.1f)" % [status.element.id, status.gauge]))
		bus.connect(&"enemy_died", func(_enemy: Node2D, def: EnemyDef) -> void:
				print("[dev] enemy_died:%s" % def.id))
		bus.connect(&"enemy_reached_exit", func(_enemy: Node2D, def: EnemyDef) -> void:
				print("[dev] enemy_reached_exit:%s" % def.id))
		bus.connect(&"wave_spawn_finished", func(_wave: WaveDef) -> void:
				print("[dev] wave_spawn_finished(生成完毕,非清波)"))
		bus.connect(&"reaction_triggered",
				func(reaction: ReactionDef, target: Node2D, source_tower: Node) -> void:
					print("[dev] reaction_triggered:%s → %s(source %s)" %
							[reaction.id, _id_of(target), source_tower.name]))
	_preset_tower.setup(load(FIRE_TOWER_DEF_PATH) as TowerDef)
	_dev_cells = _dev_buildable_cells()
	_grid.buildable = _dev_cells
	# 预置塔也占格(一格一塔不变量对 dev 摆塔同样生效)
	_grid.claim(_grid.world_to_cell(_preset_tower.global_position), _preset_tower)
	queue_redraw()
	print("[dev] 摆塔:数字键 1-4 选塔(当前 fire),左键放置;可建格 %d 个" % _dev_cells.size())
	_spawner.start_wave(load(DEV_WAVE_PATH) as WaveDef)


## dev-only:网格叠加层(可建格淡绿填充 + 细网格线),仅辅助 F6 gate 目验摆塔;
## 正式建造 UI(射程预览/放置光标等)归 05/06。颜色为 dev 工具数据,非游戏数值。
func _draw() -> void:
	if _grid == null or _grid.cfg == null:
		return
	var tile: float = _grid.cfg.tile_size
	for cell: Vector2i in _dev_cells:
		draw_rect(Rect2(Vector2(cell) * tile, Vector2(tile, tile)),
				Color(0.2, 0.8, 0.3, 0.12), true)
	var width: float = DEV_GRID_COLS * tile
	var height: float = DEV_GRID_ROWS * tile
	for col: int in range(DEV_GRID_COLS + 1):
		draw_line(Vector2(col * tile, 0.0), Vector2(col * tile, height),
				Color(1.0, 1.0, 1.0, 0.1))
	for row: int in range(DEV_GRID_ROWS + 1):
		draw_line(Vector2(0.0, row * tile), Vector2(width, row * tile),
				Color(1.0, 1.0, 1.0, 0.1))


## dev-only:全视野格刨去路径带 = 可建格集合;正式地图的建造格标记数据源归 06。
func _dev_buildable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var curve: Curve2D = _path.curve
	for col: int in range(DEV_GRID_COLS):
		for row: int in range(DEV_GRID_ROWS):
			var cell: Vector2i = Vector2i(col, row)
			var local_center: Vector2 = _path.to_local(_grid.cell_center(cell))
			if curve.get_closest_point(local_center).distance_to(local_center) \
					>= DEV_PATH_CLEARANCE:
				cells.append(cell)
	return cells


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var index: int = key.keycode - KEY_1
		if index >= 0 and index < DEV_TOWER_DEF_PATHS.size():
			_selected_index = index
			var def: TowerDef = load(DEV_TOWER_DEF_PATHS[index]) as TowerDef
			print("[dev] 选塔:%s" % def.id)
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_try_build(get_global_mouse_position())


func _try_build(world_pos: Vector2) -> void:
	var cell: Vector2i = _grid.world_to_cell(world_pos)
	if not _grid.can_build(cell):
		if not _dev_cells.has(cell):
			print("[dev] 拒绝放塔 %s:路格/视野外不可建" % str(cell))
		else:
			print("[dev] 拒绝放塔 %s:已占用" % str(cell))
		return
	var def: TowerDef = load(DEV_TOWER_DEF_PATHS[_selected_index]) as TowerDef
	var tower: Tower = (load(TOWER_SCENE_PATH) as PackedScene).instantiate() as Tower
	tower.setup(def)
	add_child(tower)
	tower.global_position = _grid.cell_center(cell)
	_grid.claim(cell, tower)
	print("[dev] 放塔:%s @ %s(格心 %s)" % [def.id, str(cell), str(tower.global_position)])


func _id_of(enemy: Node2D) -> StringName:
	var typed: Enemy = enemy as Enemy
	if typed != null and typed.def != null:
		return typed.def.id
	return &"?"

extends Node2D

## dev 演武场(PLAN 03 Phase 3;仅开发验证用,非正式地图——正式交叉口地图归 06)。
## 编辑器 F6 运行:自动播 dev_wave,订阅 EventBus 五信号逐条 print(dev 工具允许 print)。

const DEV_WAVE_PATH: String = "res://data/waves/dev_wave.tres"

@onready var _spawner: WaveSpawner = $WaveSpawner


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
	_spawner.start_wave(load(DEV_WAVE_PATH) as WaveDef)


func _id_of(enemy: Node2D) -> StringName:
	var typed: Enemy = enemy as Enemy
	if typed != null and typed.def != null:
		return typed.def.id
	return &"?"

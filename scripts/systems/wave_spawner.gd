class_name WaveSpawner
extends Node

## 单波生成器(PLAN 03-D7/D8):非 autoload 场景节点,吃 WaveDef 按时间表吐怪。
## 线性游标 + 倒计时,无状态机——06 关卡流程若需暂停/加速/跳波,先过 /state-machine-master。
## 条目时序语义(D6):start_delay 相对上一条目吐完(首条目相对开波);条目内首只在
## start_delay 满后立即出生,后续每 spawn_interval 一只;大步长 tick 按时间表补吐(确定性)。
## wave_started 在首只前发,wave_spawn_finished = 生成完毕恰一次,**非清波**(清波归 06,D8)。
## bus 空字段时 _ready 自接线 autoload(02-D1);headless 测试注入 RecordingBus + 手动 tick。
## 波次序列 / 波间流程归 06;本节点只播放单个 WaveDef,吐完可再 start_wave 下一波。

@export var enemy_scene: PackedScene
@export var path: Path2D

var bus: Node = null

var _wave: WaveDef = null
var _entry_index: int = 0
var _spawned_in_entry: int = 0
var _timer: float = 0.0
var _active: bool = false


func _ready() -> void:
	if bus == null:
		bus = get_node_or_null("/root/EventBus")


func _physics_process(delta: float) -> void:
	tick(delta)


func start_wave(wave: WaveDef) -> void:
	if _active:
		push_warning("WaveSpawner:波进行中,重复 start_wave 已忽略")
		return
	if wave == null or wave.entries.is_empty():
		push_warning("WaveSpawner:wave 为空或无条目,忽略")
		return
	_wave = wave
	_entry_index = 0
	_spawned_in_entry = 0
	_timer = wave.entries[0].start_delay
	_active = true
	if bus != null:
		bus.emit_signal(&"wave_started", wave)


func tick(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	while _active and _timer <= 0.0:
		var entry: SpawnEntry = _wave.entries[_entry_index]
		if entry == null or entry.enemy == null or entry.count <= 0:
			push_warning("WaveSpawner:条目 %d 无效(空 enemy 或 count ≤ 0),跳过" % _entry_index)
			_advance_entry()
			continue
		_spawn_one(entry)
		_spawned_in_entry += 1
		if _spawned_in_entry < entry.count:
			_timer += entry.spawn_interval
		else:
			_advance_entry()


func _spawn_one(entry: SpawnEntry) -> void:
	if enemy_scene == null:
		push_warning("WaveSpawner:enemy_scene 未赋值,吐怪丢弃")
		return
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	if enemy == null:
		push_warning("WaveSpawner:enemy_scene 实例不是 Enemy,吐怪丢弃")
		return
	enemy.setup(entry.enemy, path)
	add_child(enemy)
	if bus != null:
		bus.emit_signal(&"enemy_spawned", enemy)


## 推进游标;越界即本波生成完毕(wave_spawn_finished 恰一次),否则吃下一条目的 start_delay。
func _advance_entry() -> void:
	_entry_index += 1
	_spawned_in_entry = 0
	if _entry_index >= _wave.entries.size():
		_active = false
		if bus != null:
			bus.emit_signal(&"wave_spawn_finished", _wave)
	else:
		_timer += _wave.entries[_entry_index].start_delay

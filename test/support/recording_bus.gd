class_name RecordingBus
extends Node

## 测试支撑:与 EventBus 同签名的记录型总线,断言各信号投递内容。
## 测试注入它而非真 autoload(PLAN 02-D1:不赌全局状态)。信号面随 EventBus 同步扩充(03)。

signal reaction_triggered(reaction: ReactionDef, target: Node2D, source_tower: Node)

signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D, def: EnemyDef)
signal enemy_reached_exit(enemy: Node2D, def: EnemyDef)

signal wave_started(wave: WaveDef)
signal wave_spawn_finished(wave: WaveDef)

var events: Array[Dictionary] = []
var spawned: Array[Node2D] = []
var died: Array[Dictionary] = []
var reached_exit: Array[Dictionary] = []
var waves_started: Array[WaveDef] = []
var waves_spawn_finished: Array[WaveDef] = []


func _init() -> void:
	reaction_triggered.connect(
			func(r: ReactionDef, t: Node2D, s: Node) -> void:
				events.append({"reaction": r, "target": t, "source": s}))
	enemy_spawned.connect(
			func(e: Node2D) -> void: spawned.append(e))
	enemy_died.connect(
			func(e: Node2D, d: EnemyDef) -> void:
				died.append({"enemy": e, "def": d}))
	enemy_reached_exit.connect(
			func(e: Node2D, d: EnemyDef) -> void:
				reached_exit.append({"enemy": e, "def": d}))
	wave_started.connect(
			func(w: WaveDef) -> void: waves_started.append(w))
	wave_spawn_finished.connect(
			func(w: WaveDef) -> void: waves_spawn_finished.append(w))

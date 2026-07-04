class_name RecordingBus
extends Node

## 测试支撑:与 EventBus 同签名的记录型总线,断言 reaction_triggered 投递内容。
## 测试注入它而非真 autoload(PLAN 02-D1:不赌全局状态)。

signal reaction_triggered(reaction: ReactionDef, target: Node2D, source_tower: Node)

var events: Array[Dictionary] = []


func _init() -> void:
	reaction_triggered.connect(
			func(r: ReactionDef, t: Node2D, s: Node) -> void:
				events.append({"reaction": r, "target": t, "source": s}))

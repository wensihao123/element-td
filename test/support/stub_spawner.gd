class_name StubSpawner
extends Node

## 测试支撑:顶替 ProjectileSpawner 记录 Weapon 的 spawn 调用面(target + payload),
## 不实例化任何弹丸;断言在「调用面」,真实实例化归 ProjectileSpawner 自己的测试。

var spawn_calls: Array[Dictionary] = []


func spawn(target: Node2D, payload: Dictionary) -> void:
	spawn_calls.append({"target": target, "payload": payload})

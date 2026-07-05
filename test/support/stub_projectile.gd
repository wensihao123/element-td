class_name StubProjectile
extends Node2D

## 测试支撑:顶替弹丸场景根,记录 setup 注入参数供断言,不做任何飞行/命中逻辑。

var setup_calls: Array[Dictionary] = []


func setup(target: Node2D, speed_px: float, damage: float, element: ElementDef,
		attach_amount: float, source: Node) -> void:
	setup_calls.append({
		"target": target,
		"speed_px": speed_px,
		"damage": damage,
		"element": element,
		"attach_amount": attach_amount,
		"source": source,
	})

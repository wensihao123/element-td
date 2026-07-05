class_name FloatingText
extends Node2D

## 反应飘字(PLAN 05-D4):setup 初始化文本/色/位置,tick 上浮渐隐,
## 寿命尽 queue_free。显式 tick 驱动不用 Tween(headless 可确定性断言);
## 表现常量住场景 @export(05-D5)。挂载方先 add_child 再 setup(world_pos
## 为全局坐标快照,不持目标引用)。

@export var lifetime: float = 1.0
@export var rise_distance: float = 24.0

var age: float = 0.0


func _process(delta: float) -> void:
	tick(delta)


func setup(text: String, color: Color, world_pos: Vector2) -> void:
	global_position = world_pos
	var label: Label = get_node_or_null("Label") as Label
	if label != null:
		label.text = text
		label.modulate = color


func tick(delta: float) -> void:
	age += delta
	if lifetime <= 0.0 or age >= lifetime:
		queue_free()
		return
	position.y -= rise_distance * delta / lifetime
	modulate.a = 1.0 - age / lifetime

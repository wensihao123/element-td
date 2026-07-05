class_name ReactionVfxLayer
extends Node2D

## 反应表现层(PLAN 05-D1/D4):订阅 EventBus.reaction_triggered,以目标位置
## **快照**为锚生成飘字 + 占位扩散环 flash;不持有 target 引用(反应常与击杀
## 同帧,目标随即 queue_free)。bus 经 setup 注入(测试);游戏态 _ready 空字段
## 时自接线 /root/EventBus(02-D1 先例)。z_index 在场景里抬高保证盖过敌人。
## 表现常量住场景 @export(05-D5;扩散环参数由本层代持——Burst 为内嵌类无场景)。

@export var floating_text_scene: PackedScene
@export var burst_lifetime: float = 0.4
@export var burst_max_radius: float = 36.0
@export var burst_width: float = 3.0

var bus: Node = null


## 占位扩散环 flash:一次性 tick 驱动,径向扩散 + 渐隐,寿命尽 queue_free(05-D4)。
class Burst:
	extends Node2D

	var age: float = 0.0
	var lifetime: float = 0.4
	var max_radius: float = 36.0
	var width: float = 3.0
	var color: Color = Color.WHITE

	func _process(delta: float) -> void:
		tick(delta)

	func tick(delta: float) -> void:
		age += delta
		if lifetime <= 0.0 or age >= lifetime:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress: float = 0.0 if lifetime <= 0.0 else clampf(age / lifetime, 0.0, 1.0)
		draw_arc(Vector2.ZERO, maxf(1.0, max_radius * progress), 0.0, TAU, 32,
				Color(color, 1.0 - progress), width)


func _ready() -> void:
	if bus == null:
		setup(get_node_or_null("/root/EventBus"))


## 依赖注入入口(02-D1 先例):换绑时先解旧再接新。
func setup(new_bus: Node) -> void:
	if bus != null and bus.is_connected(&"reaction_triggered", _on_reaction_triggered):
		bus.disconnect(&"reaction_triggered", _on_reaction_triggered)
	bus = new_bus
	if bus != null:
		bus.connect(&"reaction_triggered", _on_reaction_triggered)


func _on_reaction_triggered(reaction: ReactionDef, target: Node2D, _source: Node) -> void:
	if reaction == null or target == null:
		return
	var anchor: Vector2 = target.global_position
	_spawn_text(reaction, anchor)
	_spawn_burst(reaction, anchor)


func _spawn_text(reaction: ReactionDef, anchor: Vector2) -> void:
	if floating_text_scene == null:
		push_warning("ReactionVfxLayer 未配置 floating_text_scene,飘字缺失")
		return
	var text: FloatingText = floating_text_scene.instantiate() as FloatingText
	if text == null:
		return
	add_child(text)
	text.setup(reaction.display_name, reaction.color, anchor)


func _spawn_burst(reaction: ReactionDef, anchor: Vector2) -> void:
	var burst: Burst = Burst.new()
	burst.lifetime = burst_lifetime
	burst.max_radius = burst_max_radius
	burst.width = burst_width
	burst.color = reaction.color
	add_child(burst)
	burst.global_position = anchor

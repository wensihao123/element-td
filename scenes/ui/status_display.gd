class_name StatusDisplay
extends Node2D

## 敌人头顶元素状态视图(PLAN 05-D1/D2/D3):每帧轮询兄弟 StatusComponent
## (02-D7 具名直读),产出可断言状态字段,_draw 与子节点只消费字段——
## headless 断言字段不断言像素(05-D2)。纯表现层,不改写任何玩法状态;
## 无组件或空状态整体隐藏。表现常量住场景 @export(05-D5);
## element.icon 非空自动切贴图,正式图标填 .tres 零代码升级(05-D3)。

@export var ring_radius: float = 10.0
@export var ring_width: float = 2.0
@export var backdrop_color: Color = Color(0.5, 0.5, 0.5, 0.4)

## 轮询产物(headless 断言面):
var ring_ratio: float = 0.0
var ring_color: Color = Color.WHITE
var showing_icon: bool = false


func _process(delta: float) -> void:
	tick(delta)


func tick(_delta: float) -> void:
	var status: StatusComponent = _find_status()
	if status == null or status.element == null or status.cfg == null:
		if visible:
			visible = false
			ring_ratio = 0.0
			queue_redraw()
		return
	visible = true
	ring_color = status.element.color
	ring_ratio = 0.0 if status.cfg.max_gauge <= 0.0 \
			else clampf(status.gauge / status.cfg.max_gauge, 0.0, 1.0)
	showing_icon = status.element.icon != null
	_update_children(status.element)
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, backdrop_color, ring_width)
	if ring_ratio > 0.0:
		draw_arc(Vector2.ZERO, ring_radius, -PI / 2.0,
				-PI / 2.0 + TAU * ring_ratio, 32, ring_color, ring_width)


func _find_status() -> StatusComponent:
	var parent: Node = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("StatusComponent") as StatusComponent


func _update_children(element: ElementDef) -> void:
	var icon: Sprite2D = get_node_or_null("Icon") as Sprite2D
	var glyph: Label = get_node_or_null("Glyph") as Label
	if icon != null:
		icon.visible = showing_icon
		icon.texture = element.icon
	if glyph != null:
		glyph.visible = not showing_icon
		glyph.text = element.display_name.left(1)
		glyph.modulate = element.color

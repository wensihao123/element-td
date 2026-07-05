class_name Tower
extends Node2D

## 通用塔实体根(PLAN 04-D4):单场景数据驱动,数值全由 TowerDef 注入,加塔 = 加 .tres,
## 零场景复制。三具名直接子组件(02-D7 发现约定):Targeting / Weapon / ProjectileSpawner。
## TowerDef 距离字段为 tile 单位(D2),应用 def 时 × grid_cfg.tile_size 换算 px 分发给
## Weapon。依赖注入(02-D1):grid_cfg / gauge_cfg 空字段 _ready 自接线 Balance;
## headless 测试先显式注入再入树。占位视觉 = Visual(Polygon2D)按元素色染色(正式归 05)。

var def: TowerDef = null
var grid_cfg: GridConfig = null
var gauge_cfg: GaugeConfig = null


func _ready() -> void:
	var balance: Node = get_node_or_null("/root/Balance")
	if balance != null:
		if grid_cfg == null:
			grid_cfg = balance.get("grid") as GridConfig
		if gauge_cfg == null:
			gauge_cfg = balance.get("config") as GaugeConfig
	_apply_def()


## 生成方在 add_child 前调用:注入数据;参数分发在 cfg 齐备后执行(_ready 兜底)。
func setup(new_def: TowerDef) -> void:
	def = new_def
	_apply_def()


func _apply_def() -> void:
	if def == null or grid_cfg == null or gauge_cfg == null:
		return
	var weapon: Weapon = get_node_or_null("Weapon") as Weapon
	if weapon == null:
		push_warning("Tower %s 缺少 Weapon 子组件,def 分发丢弃" % name)
		return
	weapon.range_px = def.attack_range * grid_cfg.tile_size
	weapon.speed_px = def.projectile_speed * grid_cfg.tile_size
	weapon.damage = def.damage
	weapon.fire_interval = def.fire_interval
	weapon.element = def.element
	weapon.attach_amount = def.get_attach(gauge_cfg)
	weapon.source = self
	_tint_visual()


## 占位视觉:按元素色染色供肉眼分辨塔种;正式可视化归 05。
func _tint_visual() -> void:
	var visual: Polygon2D = get_node_or_null("Visual") as Polygon2D
	if visual != null and def != null and def.element != null:
		visual.color = def.element.color

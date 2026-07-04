class_name Enemy
extends Node2D

## 通用敌人实体根(PLAN 03-D1/D2/D4/D5/D9):单场景数据驱动,数值全由 EnemyDef 注入,
## 加敌人 = 加 .tres,零场景复制。四具名直接子组件(02-D7 发现约定):
## StatusComponent / ModifierStack / ActiveEffects / HealthComponent。
## 鸭子契约(02-D10)住根:02 效果只向组里的敌人根投递 take_damage / apply_knockback。
## 依赖注入(02-D1 模式):bus / status.cfg / status.reaction_system 由 _ready 仅在
## 空字段时自接线 autoload;headless 测试先显式注入再入树,不依赖单例。
## 死亡铁律(02 REVIEW):一律 queue_free,禁止同步 free(迭代中投伤 = use-after-free)。

var def: EnemyDef = null
var path: Path2D = null
## 沿 baked curve 的路径进度,px 计(D1);击退 = 进度回退(D2),移动采样归 tick。
var progress: float = 0.0

var bus: Node = null


func _init() -> void:
	add_to_group(ReactionEffect.ENEMY_GROUP)


func _ready() -> void:
	var status: StatusComponent = _status()
	if status != null:
		if status.cfg == null:
			var balance: Node = get_node_or_null("/root/Balance")
			if balance != null:
				status.cfg = balance.get("config") as GaugeConfig
		if status.reaction_system == null:
			status.reaction_system = get_node_or_null("/root/ReactionSystem")
	if bus == null:
		bus = get_node_or_null("/root/EventBus")
	var health: HealthComponent = _health()
	if health != null and not health.died.is_connected(_on_died):
		health.died.connect(_on_died)
	if status != null and status.cfg != null and def != null and def.innate_element != null:
		status.apply_innate(def.innate_element, status.cfg.default_attach)
	_tint_visual()
	_snap_to_path()


func _physics_process(delta: float) -> void:
	tick(delta)


## 生成器在 add_child 前调用:注入数据并初始化运行时状态(innate 附着归 _ready)。
func setup(new_def: EnemyDef, new_path: Path2D) -> void:
	def = new_def
	path = new_path
	progress = 0.0
	var health: HealthComponent = _health()
	if health != null and def != null:
		health.max_hp = def.max_hp
		health.base_armor = def.armor
		health.hp = def.max_hp


## 终态互斥 guard:已排队删除(到达终点/已死亡)后拒收伤害,保证 enemy_reached_exit
## 与 enemy_died 每敌恰发其一,同帧 AoE/DoT 补刀不会让 06 双记账(REVIEW must-fix ②)。
func take_damage(amount: float, source: Node) -> void:
	if is_queued_for_deletion():
		return
	var health: HealthComponent = _health()
	if health == null:
		push_warning("敌人 %s 缺少 HealthComponent,伤害丢弃" % name)
		return
	health.take_damage(amount, source)


## D2:固定路径 TD 击退 = 沿路径进度回退,忽略 direction(留给未来自由移动敌人)。
func apply_knockback(distance: float, _direction: Vector2) -> void:
	progress = maxf(progress - distance, 0.0)


## 移动一帧(D1):眩晕停走(02 契约 resolve(&"stunned")),速度经 ModifierStack 结算,
## 沿 baked curve 采样设位;headless 测试手动驱动,确定性。已排队删除(死亡/已达
## 终点)不再动,防重复发终点信号。
func tick(delta: float) -> void:
	if path == null or path.curve == null or def == null or is_queued_for_deletion():
		return
	var stack: ModifierStack = _stack()
	if stack != null and stack.resolve(&"stunned", 0.0) > 0.0:
		return
	var speed: float = stack.resolve(&"speed", def.speed) if stack != null else def.speed
	progress += speed * delta
	var baked_length: float = path.curve.get_baked_length()
	if progress < baked_length:
		_snap_to_path()
		return
	progress = baked_length
	_snap_to_path()
	if bus != null:
		bus.emit_signal(&"enemy_reached_exit", self, def)
	queue_free()


func _on_died() -> void:
	if bus != null:
		bus.emit_signal(&"enemy_died", self, def)
	queue_free()


## 占位视觉(D9):16px 单色多边形,innate 怪以元素色染色供肉眼分辨;正式可视化归 05。
func _tint_visual() -> void:
	var visual: Polygon2D = get_node_or_null("Visual") as Polygon2D
	if visual != null and def != null and def.innate_element != null:
		visual.color = def.innate_element.color


func _snap_to_path() -> void:
	if path != null and path.curve != null and is_inside_tree():
		global_position = path.to_global(path.curve.sample_baked(progress))


func _status() -> StatusComponent:
	return get_node_or_null("StatusComponent") as StatusComponent


func _stack() -> ModifierStack:
	return get_node_or_null("ModifierStack") as ModifierStack


func _health() -> HealthComponent:
	return get_node_or_null("HealthComponent") as HealthComponent

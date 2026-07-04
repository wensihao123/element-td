extends Node

## Autoload「ReactionSystem」:反应裁决与执行(PLAN 02-D2/D8/D9)。
## 无 class_name(D1);依赖全部经 setup() 注入,headless 测试显式构造整套对象;
## autoload 游戏态由 _ready() 自接线(Balance.config + DirAccess 扫描反应目录 +
## get_node_or_null 取 EventBus,全程容错)。加反应 = 加 .tres,零代码改动(硬 NO)。

const REACTIONS_DIR: String = "res://data/reactions"

var _cfg: GaugeConfig = null
var _bus: Node = null
var _table: Dictionary = {}


func _ready() -> void:
	if _cfg != null:
		return
	var reactions: Array[ReactionDef] = []
	var dir: DirAccess = DirAccess.open(REACTIONS_DIR)
	if dir == null:
		push_warning("无法打开反应目录:%s" % REACTIONS_DIR)
	else:
		for file_name: String in dir.get_files():
			if file_name.ends_with(".tres"):
				var def: ReactionDef = load(REACTIONS_DIR + "/" + file_name) as ReactionDef
				if def != null:
					reactions.append(def)
	var cfg: GaugeConfig = null
	var balance: Node = get_node_or_null("/root/Balance")
	if balance != null:
		cfg = balance.get("config") as GaugeConfig
	else:
		push_warning("Balance autoload 缺失,ReactionSystem 未取得 GaugeConfig")
	setup(cfg, reactions, get_node_or_null("/root/EventBus"))


## 依赖注入入口:建反应表(两元素 id 排序拼接 key,保证无序对唯一,D2)。
func setup(cfg: GaugeConfig, reactions: Array[ReactionDef], bus: Node) -> void:
	_cfg = cfg
	_bus = bus
	_table.clear()
	for def: ReactionDef in reactions:
		if def == null or def.element_a == null or def.element_b == null:
			continue
		_table[_key(def.element_a.id, def.element_b.id)] = def


## 反应裁决(D8/D9 定序):ICD 拦截 → 查表 → 设 ICD → 扣量(可能触发过期回滚)
## → 逐效果 apply(此时 gauge 已是终值)→ 发信号(一切定格)→ 返 true。
## incoming 元素被反应消耗,不附着;ICD 中或查无:不反应、不附着、不动 gauge。
func try_react(status: StatusComponent, incoming: ElementDef, source: Node,
		hit_direction: Vector2 = Vector2.ZERO) -> bool:
	if status == null or incoming == null or status.element == null or _cfg == null:
		return false
	if status.icd_remaining > 0.0:
		return false
	var def: ReactionDef = _table.get(_key(status.element.id, incoming.id)) as ReactionDef
	if def == null:
		return false
	status.icd_remaining = _cfg.reaction_icd
	var target: Node = status.get_parent()
	status.consume(def.get_cost(_cfg))
	var ctx: Dictionary = {
		"source": source,
		"reaction": def,
		"hit_direction": hit_direction,
	}
	for fx: ReactionEffect in def.effects:
		if fx != null:
			fx.apply(target, ctx)
	if _bus != null:
		_bus.emit_signal(&"reaction_triggered", def, target, source)
	return true


func _key(a: StringName, b: StringName) -> String:
	var pair: Array[String] = [String(a), String(b)]
	pair.sort()
	return "%s+%s" % [pair[0], pair[1]]

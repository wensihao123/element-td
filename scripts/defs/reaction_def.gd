class_name ReactionDef
extends Resource

## 反应定义(纯数据)。element_a/element_b 为无序对——
## ReactionSystem(02)建表时按两 id 排序拼接派生 key,保证"冰+火"="火+冰"。

@export var id: StringName = &""
## 反应飘字直接用 display_name(可读性支柱);color MVP 留默认,05-status-ui 再定
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export var element_a: ElementDef
@export var element_b: ElementDef
## -1.0 = 使用全局默认 default_cost
@export var gauge_cost_override: float = -1.0
@export var effects: Array[ReactionEffect] = []


func get_cost(cfg: GaugeConfig) -> float:
	return gauge_cost_override if gauge_cost_override >= 0.0 else cfg.default_cost

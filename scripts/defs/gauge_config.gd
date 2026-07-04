class_name GaugeConfig
extends Resource

## Gauge 全局默认值(项目说明 §4.3 代码快照)。
## 权威数值住 res://data/balance/global_config.tres,以 .tres 为准。

@export var default_attach: float = 2.0
@export var max_gauge: float = 3.0
@export var decay_per_sec: float = 0.0
@export var default_cost: float = 1.0
@export var reaction_icd: float = 0.5

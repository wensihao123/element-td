class_name DotEffect
extends ReactionEffect

## 持续伤害:每 tick_interval 秒结算一次;duration = -1.0 表示随元素状态存续。

@export var dps: float = 0.0
@export var duration: float = -1.0
@export var tick_interval: float = 0.0

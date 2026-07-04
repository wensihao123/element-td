class_name SpawnEntry
extends Resource

## 波次生成条目(PLAN 03-D6):同种敌人的一段连续生成。
## start_delay 相对上一条目生成完毕(条目顺序衔接,D7 线性游标);数值住 data/waves/。

@export var enemy: EnemyDef
@export var count: int = 0
@export var spawn_interval: float = 0.0
@export var start_delay: float = 0.0

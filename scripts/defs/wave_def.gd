class_name WaveDef
extends Resource

## 单波定义(PLAN 03-D6):按序播放的生成条目表。
## 波次序列 / 波间经济归 06;spawner 只播放单个 WaveDef。

@export var entries: Array[SpawnEntry] = []

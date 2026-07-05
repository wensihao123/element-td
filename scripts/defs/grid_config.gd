class_name GridConfig
extends Resource

## 网格空间标尺(04-D1)。tile 为距离数值的统一单位,运行时 × tile_size 换算 px。
## 权威数值住 res://data/balance/grid_config.tres,以 .tres 为准。

@export var tile_size: float = 64.0

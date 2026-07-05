class_name TowerDef
extends Resource

## 塔定义骨架(MVP 无分支);字段集可在 03/04 规划时以新增 @export 向后兼容地扩展。

@export var id: StringName = &""
@export var display_name: String = ""
@export var element: ElementDef
@export var damage: float = 0.0
@export var fire_interval: float = 0.0
## 单位:格(tile);运行时由塔根 _apply_def 一次性 × Balance.grid.tile_size 换算 px。
## 注意与 EnemyDef.speed(px/s)、02 反应 AoE 半径(px)双轨并存,统一复核挂 06。
@export var attack_range: float = 0.0
## 单位:格/秒(tile/s);换算规则同 attack_range。
@export var projectile_speed: float = 0.0
@export var cost_gold: int = 0
## -1.0 = 使用全局默认 default_attach
@export var attach_override: float = -1.0


func get_attach(cfg: GaugeConfig) -> float:
	return attach_override if attach_override >= 0.0 else cfg.default_attach

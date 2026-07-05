extends Node

## Autoload「Balance」:运行时读取全局数值配置的唯一入口。
## defs 类不引用本单例(get_attach/get_cost 显式传 cfg,PLAN D2);headless 测试直接构造/加载资源。

var config: GaugeConfig = preload("res://data/balance/global_config.tres") as GaugeConfig
var grid: GridConfig = preload("res://data/balance/grid_config.tres") as GridConfig

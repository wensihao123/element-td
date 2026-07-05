class_name BuildGrid
extends Node

## 网格摆塔底座(PLAN 04-D3):非 autoload 场景节点,只管「几何换算 + 占用簿记」,
## 不管塔实例化(归调用方:dev 输入工具 / 06 建造流程)。
## buildable 格集合注入式;06 把 TileMap 建造格标记转成集合注入,零改本节点。
## 无 release(无售塔;06 做售塔时几行扩展,占用表结构已支持)。
## cfg 空字段 _ready 自接线 Balance.grid(02-D1);headless 测试显式注入。

var cfg: GridConfig = null
var buildable: Array[Vector2i] = []

## 一格一塔占用表:cell -> 塔根节点
var _occupied: Dictionary = {}


func _ready() -> void:
	if cfg == null:
		var balance: Node = get_node_or_null("/root/Balance")
		if balance != null:
			cfg = balance.grid


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / cfg.tile_size).floor())


func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cfg.tile_size


func can_build(cell: Vector2i) -> bool:
	return buildable.has(cell) and not _occupied.has(cell)


func claim(cell: Vector2i, tower: Node) -> void:
	_occupied[cell] = tower

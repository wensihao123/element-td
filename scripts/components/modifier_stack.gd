class_name ModifierStack
extends Node

## 运行时属性修饰栈(硬 NO:运行时增益一律走这里,永不改写 .tres)。
## resolve = (base + Σflat) * (1 + Σpct);未知 stat 原样返回 base。
## 本组件不管时限——计时统一归 ActiveEffects(单一计时权威,PLAN 02-D4)。
## 保留键约定:&"speed" / &"armor" / &"damage_taken" / &"stunned"(眩晕 = flat +1 计数,
## resolve(&"stunned", 0.0) > 0.0 即处于眩晕,重叠控制天然计数正确)。

var _entries: Dictionary = {}
var _next_handle: int = 1


func add(stat: StringName, flat: float, pct: float) -> int:
	var handle: int = _next_handle
	_next_handle += 1
	_entries[handle] = {"stat": stat, "flat": flat, "pct": pct}
	return handle


func remove(handle: int) -> void:
	_entries.erase(handle)


func resolve(stat: StringName, base: float) -> float:
	var flat_sum: float = 0.0
	var pct_sum: float = 0.0
	for entry: Dictionary in _entries.values():
		if entry["stat"] == stat:
			flat_sum += entry["flat"]
			pct_sum += entry["pct"]
	return (base + flat_sum) * (1.0 + pct_sum)

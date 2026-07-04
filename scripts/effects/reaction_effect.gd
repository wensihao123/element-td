class_name ReactionEffect
extends Resource

## 反应效果积木基类(本 feature 只落参数壳)。
## apply() 运行时逻辑归 02-reaction-core;子类默认值一律中性哨兵,真实数值只在 .tres 授权(PLAN D5)。


func apply(_target: Node, _ctx: Dictionary) -> void:
	pass

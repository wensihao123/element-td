class_name StatModifierEffect
extends ReactionEffect

## 属性修饰(运行时经 ModifierStack 生效,永不改写 .tres 字段)。
## duration = -1.0 表示随元素状态存续(gauge > 0 期间生效,见 PLAN D4)。

@export var stat: StringName = &""
@export var add_flat: float = 0.0
@export var add_percent: float = 0.0
@export var duration: float = -1.0

class_name EnemyDef
extends Resource

## 敌人定义骨架;innate_element 非空 = 自带元素附着(如熔岩犬自带火),附着量表 03 落地。

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: float = 0.0
@export var speed: float = 0.0
@export var armor: float = 0.0
@export var gold_reward: int = 0
@export var innate_element: ElementDef

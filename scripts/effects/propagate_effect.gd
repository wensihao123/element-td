class_name PropagateEffect
extends ReactionEffect

## 包装 inner 效果并施加给半径内的周围敌人;不含主目标(PLAN D7)——
## 需要主目标同吃效果时,在 effects 数组里并列一个未包装的同类效果。

@export var inner: ReactionEffect
@export var radius: float = 0.0

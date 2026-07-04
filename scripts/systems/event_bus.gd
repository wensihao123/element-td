extends Node

## Autoload「EventBus」:跨系统订阅型通信的唯一通道(铁律:系统间禁止直接引用)。
## 无 class_name(PLAN 02-D1:避免与 autoload 名冲突,沿 balance.gd 先例)。
## 本 feature 仅声明 reaction_triggered;死亡/金币/波次等信号归各自 feature 增补。

signal reaction_triggered(reaction: ReactionDef, target: Node2D, source_tower: Node)

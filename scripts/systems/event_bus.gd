extends Node

## Autoload「EventBus」:跨系统订阅型通信的唯一通道(铁律:系统间禁止直接引用)。
## 无 class_name(PLAN 02-D1:避免与 autoload 名冲突,沿 balance.gd 先例)。
## 信号按 feature 增补:02 反应、03 敌人/波次(过去式命名,03-D8)。

signal reaction_triggered(reaction: ReactionDef, target: Node2D, source_tower: Node)

signal enemy_spawned(enemy: Node2D)
signal enemy_died(enemy: Node2D, def: EnemyDef)
## 语义 = 抵达终点漏怪(基地扣血/胜负判定归 06 订阅方)。
signal enemy_reached_exit(enemy: Node2D, def: EnemyDef)

signal wave_started(wave: WaveDef)
## 语义 = 本波生成完毕(最后一只已吐出),**不是**清波——清波判定归 06 组计数(D8)。
signal wave_spawn_finished(wave: WaveDef)

class_name Targeting
extends Node

## 索敌组件(PLAN 04-D5):射程内 progress 最大者(「首怪」优先)——附着顺序可预测,
## 玩家能推理「冰塔先命中队首」从而摆位设计反应时机(支柱 2)。
## 组扫描复用 ReactionEffect.ENEMY_GROUP + 距离过滤(02-D6);progress 经鸭子读取
## (node.get,缺省 0)。已排队删除(死亡/到达终点)的敌人不参与候选(02 终态铁律延伸)。


func acquire(origin: Node2D, range_px: float) -> Node2D:
	if origin == null or not origin.is_inside_tree():
		return null
	var best: Node2D = null
	var best_progress: float = -1.0
	for node: Node in origin.get_tree().get_nodes_in_group(ReactionEffect.ENEMY_GROUP):
		var enemy: Node2D = node as Node2D
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_to(origin.global_position) > range_px:
			continue
		var raw: Variant = enemy.get("progress")
		var progress: float = raw if raw is float else 0.0
		if progress > best_progress:
			best_progress = progress
			best = enemy
	return best

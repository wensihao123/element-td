extends TestCase

## Targeting 单测(PLAN 04 Phase 2):用真 enemy.tscn(_init 即入 enemies 组),
## 直接设 progress 与 global_position,不跑移动逻辑。

const ENEMY_SCENE_PATH: String = "res://scenes/enemies/enemy.tscn"


func _tree_root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _spawn_enemy(pos: Vector2, progress: float) -> Node2D:
	var enemy: Node2D = (load(ENEMY_SCENE_PATH) as PackedScene).instantiate() as Node2D
	_tree_root().add_child(enemy)
	enemy.global_position = pos
	enemy.set("progress", progress)
	return enemy


func _make_rig() -> Dictionary:
	var origin: Node2D = Node2D.new()
	origin.position = Vector2.ZERO
	_tree_root().add_child(origin)
	var targeting: Targeting = Targeting.new()
	origin.add_child(targeting)
	return {"origin": origin, "targeting": targeting, "enemies": []}


func _cleanup(rig: Dictionary) -> void:
	for enemy: Node in rig["enemies"]:
		if is_instance_valid(enemy):
			if enemy.get_parent() != null:
				enemy.get_parent().remove_child(enemy)
			enemy.free()
	var origin: Node = rig["origin"]
	origin.get_parent().remove_child(origin)
	origin.free()


func test_empty_field_returns_null() -> void:
	var rig: Dictionary = _make_rig()
	var targeting: Targeting = rig["targeting"]
	assert_true(targeting.acquire(rig["origin"], 160.0) == null, "空场应返回 null")
	_cleanup(rig)


func test_out_of_range_not_selected() -> void:
	var rig: Dictionary = _make_rig()
	var targeting: Targeting = rig["targeting"]
	rig["enemies"].append(_spawn_enemy(Vector2(200.0, 0.0), 50.0))
	assert_true(targeting.acquire(rig["origin"], 160.0) == null, "射程外的敌人不得入选")
	rig["enemies"].append(_spawn_enemy(Vector2(160.0, 0.0), 10.0))
	assert_true(targeting.acquire(rig["origin"], 160.0) == rig["enemies"][1],
			"恰在射程边界(=range)应入选")
	_cleanup(rig)


func test_picks_max_progress_among_candidates() -> void:
	var rig: Dictionary = _make_rig()
	var targeting: Targeting = rig["targeting"]
	rig["enemies"].append(_spawn_enemy(Vector2(50.0, 0.0), 30.0))
	rig["enemies"].append(_spawn_enemy(Vector2(100.0, 0.0), 90.0))
	rig["enemies"].append(_spawn_enemy(Vector2(0.0, 80.0), 60.0))
	rig["enemies"].append(_spawn_enemy(Vector2(500.0, 0.0), 999.0))
	assert_true(targeting.acquire(rig["origin"], 160.0) == rig["enemies"][1],
			"应选射程内 progress 最大者(射程外的 999 不算)")
	_cleanup(rig)


func test_queued_for_deletion_enemy_skipped() -> void:
	var rig: Dictionary = _make_rig()
	var targeting: Targeting = rig["targeting"]
	rig["enemies"].append(_spawn_enemy(Vector2(50.0, 0.0), 90.0))
	rig["enemies"].append(_spawn_enemy(Vector2(100.0, 0.0), 10.0))
	rig["enemies"][0].queue_free()
	assert_true(targeting.acquire(rig["origin"], 160.0) == rig["enemies"][1],
			"已排队删除的敌人不参与候选")
	_cleanup(rig)

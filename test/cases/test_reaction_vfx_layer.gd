extends TestCase

## ReactionVfxLayer 单测(PLAN 05 Phase 2):收信号生成飘字 + 扩散环、多次
## 并存、tick 超寿命自毁、目标同帧释放不崩(位置快照)。发射端复用
## RecordingBus(信号面与 EventBus 同步,直接 emit 即为发射 stub);bus 经
## setup 注入后再入树,_ready 自接线分支不触发(02-D1 先例)。
## 「自毁」断言 is_queued_for_deletion(queue_free 帧末才真删,同帧内以此为准)。

const LAYER_SCENE_PATH: String = "res://scenes/ui/reaction_vfx_layer.tscn"
const STEAM_BURST_PATH: String = "res://data/reactions/steam_burst.tres"


func _tree_root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _new_layer(bus: Node) -> ReactionVfxLayer:
	var layer: ReactionVfxLayer = \
			(load(LAYER_SCENE_PATH) as PackedScene).instantiate() as ReactionVfxLayer
	layer.setup(bus)
	_tree_root().add_child(layer)
	return layer


func _new_target(pos: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	_tree_root().add_child(target)
	target.global_position = pos
	return target


func _texts(layer: ReactionVfxLayer) -> Array[FloatingText]:
	var found: Array[FloatingText] = []
	for child: Node in layer.get_children():
		if child is FloatingText:
			found.append(child as FloatingText)
	return found


func _bursts(layer: ReactionVfxLayer) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for child: Node in layer.get_children():
		if child is ReactionVfxLayer.Burst:
			found.append(child as Node2D)
	return found


func test_signal_spawns_text_and_burst() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var layer: ReactionVfxLayer = _new_layer(bus)
	var reaction: ReactionDef = load(STEAM_BURST_PATH) as ReactionDef
	var anchor: Vector2 = Vector2(320.0, 240.0)
	var target: Node2D = _new_target(anchor)
	var tower: Node = Node.new()
	bus.reaction_triggered.emit(reaction, target, tower)
	var texts: Array[FloatingText] = _texts(layer)
	var bursts: Array[Node2D] = _bursts(layer)
	assert_eq(texts.size(), 1, "一次信号应生成恰好 1 个飘字")
	assert_eq(bursts.size(), 1, "一次信号应生成恰好 1 个扩散环")
	if not texts.is_empty():
		var label: Label = texts[0].get_node("Label") as Label
		assert_eq(label.text, reaction.display_name, "飘字文本应为反应显示名")
		assert_eq(label.modulate, reaction.color, "飘字应染反应色")
		assert_eq(texts[0].global_position, anchor, "飘字应锚定目标位置快照")
	if not bursts.is_empty():
		assert_eq(bursts[0].global_position, anchor, "扩散环应锚定目标位置快照")
	layer.free()
	target.free()
	tower.free()
	bus.free()


func test_multiple_signals_coexist() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var layer: ReactionVfxLayer = _new_layer(bus)
	var reaction: ReactionDef = load(STEAM_BURST_PATH) as ReactionDef
	var tower: Node = Node.new()
	var targets: Array[Node2D] = []
	for index: int in range(3):
		var target: Node2D = _new_target(Vector2(100.0 * index, 50.0))
		targets.append(target)
		bus.reaction_triggered.emit(reaction, target, tower)
	assert_eq(_texts(layer).size(), 3, "连发 3 次应有 3 个飘字并存")
	assert_eq(_bursts(layer).size(), 3, "连发 3 次应有 3 个扩散环并存")
	layer.free()
	for target: Node2D in targets:
		target.free()
	tower.free()
	bus.free()


func test_tick_past_lifetime_self_destructs() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var layer: ReactionVfxLayer = _new_layer(bus)
	var reaction: ReactionDef = load(STEAM_BURST_PATH) as ReactionDef
	var target: Node2D = _new_target(Vector2(64.0, 64.0))
	var tower: Node = Node.new()
	bus.reaction_triggered.emit(reaction, target, tower)
	var text: FloatingText = _texts(layer)[0]
	var start_y: float = text.position.y
	text.tick(text.lifetime * 0.5)
	assert_true(text.modulate.a < 1.0, "半寿命时飘字应已渐隐")
	assert_true(text.position.y < start_y, "半寿命时飘字应已上浮")
	for child: Node in layer.get_children():
		var remaining: float = maxf(text.lifetime, layer.burst_lifetime)
		child.call(&"tick", remaining + 0.01)
	for child: Node in layer.get_children():
		assert_true(child.is_queued_for_deletion(),
				"tick 超寿命后 %s 应自毁(queue_free)" % child.name)
	layer.free()
	target.free()
	tower.free()
	bus.free()


func test_target_freed_same_frame_does_not_crash() -> void:
	var bus: RecordingBus = RecordingBus.new()
	var layer: ReactionVfxLayer = _new_layer(bus)
	var reaction: ReactionDef = load(STEAM_BURST_PATH) as ReactionDef
	var anchor: Vector2 = Vector2(200.0, 120.0)
	var target: Node2D = _new_target(anchor)
	var tower: Node = Node.new()
	bus.reaction_triggered.emit(reaction, target, tower)
	target.free()
	for child: Node in layer.get_children():
		child.call(&"tick", 0.1)
	var texts: Array[FloatingText] = _texts(layer)
	assert_eq(texts.size(), 1, "目标释放后飘字应仍存活(不持引用)")
	if not texts.is_empty():
		assert_eq(texts[0].global_position.x, anchor.x, "目标释放后飘字仍锚定快照位置(x)")
	layer.free()
	tower.free()
	bus.free()

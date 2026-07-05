extends TestCase

## StatusDisplay 单测(PLAN 05 Phase 1):无兄弟隐藏、空状态隐藏、附着后
## 字段正确、充能/消耗比例升降、归零隐藏、首字 fallback 与贴图分支。
## 断言的是状态字段非像素(05-D2 设计使然);cfg 显式加载/构造注入,
## 不依赖 autoload(02-D1 先例)。

const DISPLAY_SCENE_PATH: String = "res://scenes/ui/status_display.tscn"
const CONFIG_PATH: String = "res://data/balance/global_config.tres"
const FIRE_PATH: String = "res://data/elements/fire.tres"


func _new_display() -> StatusDisplay:
	var scene: PackedScene = load(DISPLAY_SCENE_PATH) as PackedScene
	return scene.instantiate() as StatusDisplay


func _new_enemy_with_display(cfg: GaugeConfig) -> StubEnemy:
	var enemy: StubEnemy = StubEnemy.new()
	enemy.status().cfg = cfg
	var display: StatusDisplay = _new_display()
	display.name = "StatusDisplay"
	enemy.add_child(display)
	return enemy


func _display_of(enemy: StubEnemy) -> StatusDisplay:
	return enemy.get_node("StatusDisplay") as StatusDisplay


func test_hidden_without_status_sibling() -> void:
	var orphan: StatusDisplay = _new_display()
	orphan.tick(0.016)
	assert_true(not orphan.visible, "无父节点 tick 不应报错且应隐藏")
	var host: Node2D = Node2D.new()
	var display: StatusDisplay = _new_display()
	host.add_child(display)
	display.tick(0.016)
	assert_true(not display.visible, "无 StatusComponent 兄弟应隐藏")
	orphan.free()
	host.free()


func test_hidden_when_status_empty() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var enemy: StubEnemy = _new_enemy_with_display(cfg)
	_display_of(enemy).tick(0.016)
	assert_true(not _display_of(enemy).visible, "空状态(element == null)应隐藏")
	enemy.free()


func test_attach_shows_ring_with_element_color_and_ratio() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy_with_display(cfg)
	enemy.status().apply_element(fire, cfg.default_attach, tower)
	var display: StatusDisplay = _display_of(enemy)
	display.tick(0.016)
	assert_true(display.visible, "附着后应可见")
	assert_eq(display.ring_color, fire.color, "环色应为元素色")
	assert_eq(display.ring_ratio,
			clampf(cfg.default_attach, 0.0, cfg.max_gauge) / cfg.max_gauge,
			"弧长比例应为 gauge / max_gauge")
	enemy.free()
	tower.free()


func test_ratio_rises_on_stack_falls_on_consume_hides_at_zero() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy_with_display(cfg)
	var display: StatusDisplay = _display_of(enemy)
	enemy.status().apply_element(fire, cfg.default_attach, tower)
	display.tick(0.016)
	var ratio_first: float = display.ring_ratio
	enemy.status().apply_element(fire, cfg.default_attach, tower)
	display.tick(0.016)
	var ratio_stacked: float = display.ring_ratio
	assert_true(ratio_stacked > ratio_first, "同元素补充后比例应上升")
	assert_eq(ratio_stacked,
			clampf(cfg.default_attach * 2.0, 0.0, cfg.max_gauge) / cfg.max_gauge,
			"叠层后比例应为 clamp 后 gauge / max_gauge")
	enemy.status().consume(cfg.default_cost)
	display.tick(0.016)
	assert_true(display.ring_ratio < ratio_stacked, "消耗后比例应下降")
	enemy.status().consume(cfg.max_gauge)
	display.tick(0.016)
	assert_true(not display.visible, "gauge 归零过期后应整体隐藏")
	assert_eq(display.ring_ratio, 0.0, "归零后比例字段应清零")
	enemy.free()
	tower.free()


func test_glyph_fallback_when_icon_empty() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var fire: ElementDef = load(FIRE_PATH) as ElementDef
	var tower: Node = Node.new()
	var enemy: StubEnemy = _new_enemy_with_display(cfg)
	enemy.status().apply_element(fire, cfg.default_attach, tower)
	var display: StatusDisplay = _display_of(enemy)
	display.tick(0.016)
	assert_true(not display.showing_icon, "icon 为空应走首字 fallback")
	var glyph: Label = display.get_node("Glyph") as Label
	var icon: Sprite2D = display.get_node("Icon") as Sprite2D
	assert_true(glyph.visible, "fallback 模式 Glyph 应可见")
	assert_true(not icon.visible, "fallback 模式 Icon 应隐藏")
	assert_eq(glyph.text, fire.display_name.left(1), "Glyph 文本应为显示名首字")
	assert_eq(glyph.modulate, fire.color, "Glyph 应染元素色")
	enemy.free()
	tower.free()


func test_icon_branch_when_icon_assigned() -> void:
	var cfg: GaugeConfig = load(CONFIG_PATH) as GaugeConfig
	var tower: Node = Node.new()
	var texture: PlaceholderTexture2D = PlaceholderTexture2D.new()
	var element: ElementDef = ElementDef.new()
	element.id = &"test_iconed"
	element.display_name = "测"
	element.color = Color(0.2, 0.4, 0.8)
	element.icon = texture
	var enemy: StubEnemy = _new_enemy_with_display(cfg)
	enemy.status().apply_element(element, cfg.default_attach, tower)
	var display: StatusDisplay = _display_of(enemy)
	display.tick(0.016)
	assert_true(display.showing_icon, "icon 非空应走贴图分支")
	var glyph: Label = display.get_node("Glyph") as Label
	var icon: Sprite2D = display.get_node("Icon") as Sprite2D
	assert_true(icon.visible, "贴图模式 Icon 应可见")
	assert_true(not glyph.visible, "贴图模式 Glyph 应隐藏")
	assert_true(icon.texture == texture, "Icon 贴图应为 element.icon")
	enemy.free()
	tower.free()

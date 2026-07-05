extends TestCase

## BuildGrid 单测(PLAN 04 Phase 1):cfg 显式注入(不依赖单例),纯几何 + 簿记无需入树。


func _make_grid(cells: Array[Vector2i] = []) -> BuildGrid:
	var grid: BuildGrid = BuildGrid.new()
	var cfg: GridConfig = GridConfig.new()
	cfg.tile_size = 64.0
	grid.cfg = cfg
	grid.buildable = cells
	return grid


func test_cell_center_and_roundtrip_including_negative() -> void:
	var grid: BuildGrid = _make_grid()
	assert_true(grid.cell_center(Vector2i(0, 0)).is_equal_approx(Vector2(32.0, 32.0)),
			"(0,0) 格心应为 (32,32)")
	assert_true(grid.cell_center(Vector2i(-1, -1)).is_equal_approx(Vector2(-32.0, -32.0)),
			"(-1,-1) 格心应为 (-32,-32)")
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(3, 7), Vector2i(-1, -1), Vector2i(-5, 2)]:
		assert_eq(grid.world_to_cell(grid.cell_center(cell)), cell,
				"格心换算往返应一致(格 %s)" % str(cell))
	grid.free()


func test_world_to_cell_floors_within_cell() -> void:
	var grid: BuildGrid = _make_grid()
	assert_eq(grid.world_to_cell(Vector2(0.0, 0.0)), Vector2i(0, 0), "原点应落 (0,0) 格")
	assert_eq(grid.world_to_cell(Vector2(63.9, 63.9)), Vector2i(0, 0), "格内右下边缘仍属 (0,0)")
	assert_eq(grid.world_to_cell(Vector2(64.0, 0.0)), Vector2i(1, 0), "跨界点应进下一格")
	assert_eq(grid.world_to_cell(Vector2(-0.1, -0.1)), Vector2i(-1, -1), "负坐标应 floor 向负格")
	grid.free()


func test_non_buildable_cell_rejected() -> void:
	var grid: BuildGrid = _make_grid([Vector2i(2, 3)] as Array[Vector2i])
	assert_true(grid.can_build(Vector2i(2, 3)), "buildable 集合内的空格应可建")
	assert_true(not grid.can_build(Vector2i(2, 4)), "集合外的格应拒绝")
	var empty_grid: BuildGrid = _make_grid()
	assert_true(not empty_grid.can_build(Vector2i(0, 0)), "空集合任何格都应拒绝")
	grid.free()
	empty_grid.free()


func test_claim_flips_can_build_only_for_that_cell() -> void:
	var grid: BuildGrid = _make_grid([Vector2i(1, 1), Vector2i(1, 2)] as Array[Vector2i])
	var tower_stub: Node = Node.new()
	grid.claim(Vector2i(1, 1), tower_stub)
	assert_true(not grid.can_build(Vector2i(1, 1)), "claim 后该格 can_build 应翻 false")
	assert_true(grid.can_build(Vector2i(1, 2)), "其他 buildable 格不受影响")
	tower_stub.free()
	grid.free()

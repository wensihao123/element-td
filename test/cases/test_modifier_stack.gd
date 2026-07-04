extends TestCase

## ModifierStack 单测(PLAN 02 Phase 2):叠加算式、按句柄移除、未知 stat、
## &"stunned" 计数场景。数值为测试脚手架(合成值),不是游戏数值。


func _new_stack() -> ModifierStack:
	return ModifierStack.new()


func test_resolve_formula_flat_then_percent() -> void:
	var stack: ModifierStack = _new_stack()
	stack.add(&"speed", 2.0, 0.0)
	stack.add(&"speed", 3.0, 0.1)
	stack.add(&"speed", 0.0, -0.2)
	# (10 + 2 + 3) * (1 + 0.1 - 0.2) = 15 * 0.9
	assert_eq(stack.resolve(&"speed", 10.0), 13.5, "resolve 应为 (base+Σflat)*(1+Σpct)")
	stack.free()


func test_remove_by_handle() -> void:
	var stack: ModifierStack = _new_stack()
	var handle_a: int = stack.add(&"armor", -2.0, 0.0)
	var handle_b: int = stack.add(&"armor", -1.0, 0.0)
	assert_true(handle_a != handle_b, "句柄应唯一")
	stack.remove(handle_a)
	assert_eq(stack.resolve(&"armor", 5.0), 4.0, "移除 handle_a 后只剩 -1 flat")
	stack.remove(handle_a)
	assert_eq(stack.resolve(&"armor", 5.0), 4.0, "重复移除同句柄应幂等")
	stack.remove(handle_b)
	assert_eq(stack.resolve(&"armor", 5.0), 5.0, "全部移除后应复原 base")
	stack.free()


func test_unknown_stat_returns_base() -> void:
	var stack: ModifierStack = _new_stack()
	stack.add(&"speed", -1.0, -0.5)
	assert_eq(stack.resolve(&"no_such_stat", 7.0), 7.0, "未知 stat 应原样返回 base")
	stack.free()


func test_stunned_counting_overlap() -> void:
	var stack: ModifierStack = _new_stack()
	var freeze: int = stack.add(&"stunned", 1.0, 0.0)
	var paralyze: int = stack.add(&"stunned", 1.0, 0.0)
	assert_true(stack.resolve(&"stunned", 0.0) > 0.0, "双控叠加期间应处于眩晕")
	stack.remove(freeze)
	assert_true(stack.resolve(&"stunned", 0.0) > 0.0, "先到期的控制解除不应误清后者")
	stack.remove(paralyze)
	assert_eq(stack.resolve(&"stunned", 0.0), 0.0, "全部解除后应脱离眩晕")
	stack.free()

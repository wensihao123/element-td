extends TestCase

## 冒烟用例:验证测试跑道本身能发现、执行并汇总用例。


func test_smoke() -> void:
	assert_eq(1 + 1, 2, "1 + 1 应等于 2")
	assert_true(true, "assert_true 应放行 true")

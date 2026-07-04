class_name TestCase
extends RefCounted

## headless 测试用例基类:断言失败只收集不中断,由 run_tests.gd 统一汇总。
## 用法:用例脚本放 res://test/cases/,extends TestCase,方法名以 test_ 开头。

var failures: Array[String] = []
## 断言计数防线:每个 assert_* 调用 +1;run_tests.gd 据此识别「零断言」用例
## (方法体内运行时崩溃会中断执行但不落 failure,计数差为 0 即暴露)。
var assert_count: int = 0


func assert_true(cond: bool, msg: String) -> void:
	assert_count += 1
	if not cond:
		failures.append(msg)


func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	assert_count += 1
	if actual != expected:
		failures.append("%s(实际:%s,期望:%s)" % [msg, str(actual), str(expected)])

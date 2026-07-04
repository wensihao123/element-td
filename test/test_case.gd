class_name TestCase
extends RefCounted

## headless 测试用例基类:断言失败只收集不中断,由 run_tests.gd 统一汇总。
## 用法:用例脚本放 res://test/cases/,extends TestCase,方法名以 test_ 开头。

var failures: Array[String] = []


func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		failures.append("%s(实际:%s,期望:%s)" % [msg, str(actual), str(expected)])

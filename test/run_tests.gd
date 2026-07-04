extends SceneTree

## headless 测试跑道:扫描 res://test/cases/*.gd,反射执行 test_ 前缀方法,
## 逐用例打印 PASSED/FAILED,末尾汇总并显式 quit(0/1)。

const CASES_DIR: String = "res://test/cases"


func _initialize() -> void:
	var total_cases: int = 0
	var failed_cases: int = 0
	var dir: DirAccess = DirAccess.open(CASES_DIR)
	if dir == null:
		push_error("无法打开测试目录:%s" % CASES_DIR)
		quit(1)
		return
	var script_paths: Array[String] = []
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			script_paths.append(CASES_DIR + "/" + file_name)
	script_paths.sort()
	for path: String in script_paths:
		total_cases += 1
		var script: GDScript = load(path) as GDScript
		if script == null:
			failed_cases += 1
			print("FAILED  %s(脚本加载失败)" % path)
			continue
		var case: TestCase = script.new() as TestCase
		if case == null:
			failed_cases += 1
			print("FAILED  %s(不是 TestCase 子类)" % path)
			continue
		var method_count: int = 0
		for method: Dictionary in case.get_method_list():
			var method_name: String = method["name"]
			if method_name.begins_with("test_"):
				case.call(method_name)
				method_count += 1
		if case.failures.is_empty():
			print("PASSED  %s(%d 个测试方法)" % [path.get_file(), method_count])
		else:
			failed_cases += 1
			print("FAILED  %s:" % path.get_file())
			for failure: String in case.failures:
				print("    - " + failure)
	print("==== 测试汇总:%d 个用例,%d 失败 ====" % [total_cases, failed_cases])
	quit(1 if failed_cases > 0 else 0)

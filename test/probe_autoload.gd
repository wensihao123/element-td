extends SceneTree

## autoload 探针(PLAN 02 Phase 1,清 01 遗留 flag ③):
## 实测 `-s` 模式下 autoload 单例是否挂在 SceneTree root 下。
## 结论回填 harness/project-context.md §6;保留本探针供引擎升级后复测。
## 跑法:timeout 120 godot --headless --display-driver headless --audio-driver Dummy \
##       --quit-after 2000 --path . -s res://test/probe_autoload.gd


func _initialize() -> void:
	var balance: Node = root.get_node_or_null("Balance")
	if balance != null:
		print("PROBE autoload Balance:存在(-s 模式下 autoload 已加载)")
	else:
		print("PROBE autoload Balance:不存在(-s 模式下 autoload 未加载)")
	quit(0)

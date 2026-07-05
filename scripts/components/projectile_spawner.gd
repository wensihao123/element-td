class_name ProjectileSpawner
extends Node

## 弹丸生成组件(PLAN 04-D9):spawn = 实例化 projectile_scene、setup 注入、挂自身
## 子节点(沿 WaveSpawner 吐怪挂自身先例)。payload 键位契约 = Weapon._build_payload
## 产出:speed_px / damage / element / attach_amount / source。

@export var projectile_scene: PackedScene


func spawn(target: Node2D, payload: Dictionary) -> void:
	if projectile_scene == null:
		push_warning("ProjectileSpawner:projectile_scene 未赋值,开火丢弃")
		return
	var projectile: Node = projectile_scene.instantiate()
	if projectile == null or not projectile.has_method("setup"):
		push_warning("ProjectileSpawner:弹丸场景根缺少 setup,开火丢弃")
		if projectile != null:
			projectile.free()
		return
	projectile.call(&"setup", target, payload["speed_px"], payload["damage"],
			payload["element"], payload["attach_amount"], payload["source"])
	add_child(projectile)

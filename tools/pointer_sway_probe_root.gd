extends Node

## 鼠标视差探针（作为主场景带窗口跑 → 正常加载 autoload）：
##   godot --path . res://tools/pointer_sway_probe.tscn
## 流程：进战斗屏 → 鼠标 warp 左缘停 1s → 打印各层 position/scale + 截图 →
##       warp 右缘停 1s → 同上。数字对比验证分层错动方向/幅度，截图供目视。
## 输出：D:/Game/BoBoZan/pointer_sway_{left,right}.png（仓库外）

const OUT_L := "D:/Game/BoBoZan/pointer_sway_left.png"
const OUT_R := "D:/Game/BoBoZan/pointer_sway_right.png"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2).timeout   # 等进入选择态
	# 直接注入偏移状态而非 warp 鼠标：物理鼠标的移动事件会覆盖 warp（跑探针时人手碰鼠标
	# 即采样失效）。pointer_smooth=0 → lerp 权重为 0 → _pnx 冻结在注入值。
	var stage: Node = get_node("BattleScreen/Stage")
	stage.pointer_smooth = 0.0
	await _sample(stage, -1.0, "LEFT", OUT_L)
	await _sample(stage, 1.0, "RIGHT", OUT_R)
	get_tree().quit()


func _sample(stage: Node, pnx: float, tag: String, out_path: String) -> void:
	stage._pnx = pnx
	await get_tree().create_timer(0.2).timeout   # 走几帧 _process 让位移落到各层
	await RenderingServer.frame_post_draw
	print("=== ", tag, " _pnx=", pnx, " ===")
	for child in stage.get_children():
		if (child is Control or child is Node2D) and child.has_meta("parallax_factor"):
			print("  %-14s f=%.2f pos=%s scale=%s" % [
				child.name, float(child.get_meta("parallax_factor")),
				child.get(&"position"), child.get(&"scale")])
	var world := get_node_or_null("BattleScreen/WorldGroup") as Control
	if world:
		print("  %-14s (角色组) pos=%s scale=%s" % ["WorldGroup", world.position, world.scale])
	get_viewport().get_texture().get_image().save_png(out_path)
	print("saved: ", out_path)

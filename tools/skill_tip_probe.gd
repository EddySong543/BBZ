extends Node

## 技能情报双钮探针（作为主场景跑 → 正常加载 autoload）：
##   godot --path . res://tools/skill_tip_probe.tscn
## 三截：①默认态整屏（双钮+pip） ②己方钮悬停浮层 ③敌方钮翻页到第 2 人后的悬停浮层。
## 悬停走状态注入（直接调 _on_enter/_cycle·⛔warp_mouse——探针铁律）。
## 输出：D:/Game/BoBoZan/skill_info_*.png（仓库外·勿入库）

const OUT_DEFAULT := "D:/Game/BoBoZan/skill_info_default.png"
const OUT_TIP_OWN := "D:/Game/BoBoZan/skill_info_tip_own.png"
const OUT_TIP_ENEMY := "D:/Game/BoBoZan/skill_info_tip_enemy.png"
const OUT_TIP_P2_ITEM := "D:/Game/BoBoZan/skill_info_tip_p2_item.png"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2).timeout
	await _snap(OUT_DEFAULT)
	var sib: Control = s.get("_skill_info")
	sib.call("_on_enter", 0)
	await get_tree().process_frame
	await _snap(OUT_TIP_OWN)
	sib.call("_on_exit", 0)
	sib.call("_cycle", 1, 1)
	sib.call("_on_enter", 1)
	await get_tree().process_frame
	await _snap(OUT_TIP_ENEMY)
	sib.call("_on_exit", 1)
	# 敌方道具槽悬停（2026-07-17 新增）：直接发行内悬停信号（状态注入）
	var p2_row: Control = s.get("p2_item_row")
	p2_row.slot_hovered.emit(0)
	await get_tree().process_frame
	await _snap(OUT_TIP_P2_ITEM)
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

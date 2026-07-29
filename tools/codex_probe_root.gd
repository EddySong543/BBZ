extends Node

## 战斗内图鉴浮层探针（2026-07-13·图鉴钮替换技能卡自检）：
##   godot --path . res://tools/codex_probe.tscn
## 三连拍（仓库外）：①图鉴钮落位 ②浮层·英雄图鉴页 ③浮层·道具图鉴页。

const OUT_BTN := "D:/Game/BoBoZan/_probe_output/codex_shot_1_btn.png"
const OUT_HERO := "D:/Game/BoBoZan/_probe_output/codex_shot_2_hero.png"
const OUT_ITEM := "D:/Game/BoBoZan/_probe_output/codex_shot_3_item.png"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2).timeout   # 等进入选择态
	await _snap(OUT_BTN)

	var btn: Button = s.get_node_or_null("Buttons/BtnCodex") as Button
	if btn == null:
		print("FAIL: Buttons/BtnCodex 不存在")
		get_tree().quit(1)
		return
	btn.pressed.emit()                            # 开浮层（默认英雄页·懒实例化）
	await get_tree().create_timer(1.6).timeout    # 等图鉴构建+入场动效
	await _snap(OUT_HERO)

	var ov: Control = s.get_node_or_null("CodexOverlay") as Control
	if ov == null:
		print("FAIL: CodexOverlay 未创建")
		get_tree().quit(1)
		return
	ov.call("_show_tab", 1)                       # 切道具页
	await get_tree().create_timer(1.6).timeout
	await _snap(OUT_ITEM)

	print("PASS: 三图已存 ", OUT_BTN)
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

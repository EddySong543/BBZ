extends Node

## 战斗内设置浮层截图自检（2026-07-09·战斗接入设置+显示模式功能验证）：
##   godot --path . res://tools/settings_shot_runner.tscn
## 两张：①战斗屏含右上角"设置"钮 ②打开设置浮层（显示模式/分辨率行可见）。
## 输出仓库外 D:/Game/BoBoZan/（勿堆仓库·[[dont-dump-screenshots]]）。

const OUT_BTN := "D:/Game/BoBoZan/battle_settings_btn_shot.png"
const OUT_PANEL := "D:/Game/BoBoZan/battle_settings_panel_shot.png"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_BTN)

	s._open_settings()
	await get_tree().create_timer(0.5).timeout   # 等淡入完成
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_PANEL)
	print("saved: ", OUT_BTN, " / ", OUT_PANEL)
	get_tree().quit()

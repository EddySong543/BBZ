extends Node

## 英雄图鉴 hero_gallery_screen 自检（完整引擎模式·真场景）：
##   godot --path . res://tools/gallery_shot_runner.tscn
## 流程：入场（默认选中 h01）→ 截图 → 选 idx7 → 截图。不点「返回」（会波幕切场，Eddy F6 验证）。
## 输出：当前 session scratchpad（⛔别堆 BoBoZan 目录）。

const OUT_DIR := "C:/Users/Edzzz/AppData/Local/Temp/claude/D--Game-BoBoZan-Claude-Code-Game-Studios-cn-localization/ef8edc84-b5fb-49a6-967e-6aa8a4693e9f/scratchpad/"

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame
	var g := (load("res://src/ui/hero_gallery_screen.tscn") as PackedScene).instantiate()
	add_child(g)
	await get_tree().create_timer(1.6).timeout      # 入场扫过完毕（h01 默认选中）
	await _shot(OUT_DIR + "gallery_cur_default.png")

	g._select(7)                                     # 第二排（验证选中环+右页刷新）
	await get_tree().create_timer(0.5).timeout
	await _shot(OUT_DIR + "gallery_cur_sel.png")
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

extends Node

## 英雄图鉴 hero_gallery_screen 自检（完整引擎模式·真场景）：
##   godot --path . res://tools/gallery_shot_runner.tscn
## 流程：入场（默认选中 h01）→ 截图 → 选 idx7 → 截图。不点「返回」（会波幕切场，Eddy F6 验证）。
## 输出：统一探针目录（默认 user://probe-output，可由命令行覆盖）。

const ProbeOutput := preload("res://tools/probe_output.gd")

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame
	var g := (load("res://src/ui/hero_gallery_screen.tscn") as PackedScene).instantiate()
	add_child(g)
	await get_tree().create_timer(1.6).timeout      # 入场扫过完毕（h01 默认选中）
	await _shot("gallery_cur_default.png")

	g._select(7)                                     # 第二排（验证选中环+右页刷新）
	await get_tree().create_timer(0.5).timeout
	await _shot("gallery_cur_sel.png")

	g._turn_page(1)                                  # 第二页（验证 12/页与翻页入口状态）
	await get_tree().create_timer(0.5).timeout
	await _shot("gallery_cur_page2.png")

	g._select(13)                                    # h14 主动强化（验证朱砂主动印）
	await get_tree().create_timer(0.5).timeout
	await _shot("gallery_cur_active.png")
	get_tree().quit()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProbeOutput.path(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

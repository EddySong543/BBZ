extends Node

## 英雄图鉴 hero_gallery_screen v2 自检（完整引擎模式·真场景）：
##   godot --path . res://tools/gallery_shot_runner.tscn
## 流程：入场（默认选中 h01）→ 截图 → 选 h16 → 截图 → 选末位 h46（星座·验证无 idle 退头像
## 或白板 idle）→ 截图。不点「返回」（会波幕切场，转场链 Eddy F6 验证）。

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame
	var g := (load("res://src/ui/hero_gallery_screen.tscn") as PackedScene).instantiate()
	add_child(g)
	await get_tree().create_timer(1.6).timeout      # 入场扫过完毕（h01 默认选中）
	await _shot("D:/Game/BoBoZan/gallery_cur_default.png")

	g._select(7)                                     # 末排某只（12 生肖内有效索引）
	await get_tree().create_timer(0.5).timeout
	await _shot("D:/Game/BoBoZan/gallery_cur_sel.png")
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

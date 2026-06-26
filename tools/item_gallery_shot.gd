extends Node

## 道具图鉴 item_gallery_screen 自检（完整引擎模式·真场景）：
##   <godot> --path . res://tools/item_gallery_shot.gd（带窗口·非 headless）
## 入场（默认选中 0·一阶）→ 截图。不点返回（波幕转场链 Eddy F6 验证）。

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame
	var g := (load("res://src/ui/item_gallery_screen.tscn") as PackedScene).instantiate()
	add_child(g)
	await get_tree().create_timer(1.6).timeout
	await _shot("D:/Game/BoBoZan/item_gallery.png")          # 普通(tier1)
	g._select_tier(2)
	await get_tree().create_timer(0.6).timeout
	await _shot("D:/Game/BoBoZan/item_gallery_t2.png")       # 稀有(tier2)
	g._select_tier(3)
	await get_tree().create_timer(0.6).timeout
	await _shot("D:/Game/BoBoZan/item_gallery_t3.png")       # 传说(tier3)
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

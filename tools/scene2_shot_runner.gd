extends Node

## scene2 预览快照（带窗口跑）：
##   godot --path . res://tools/scene2_shot_runner.tscn
## 两帧间隔 0.6s → 河面波光/闪点/花瓣动态取证（对比两帧=确认在动且无爬缝）。
## 输出：D:/Game/BoBoZan/scene2_shot_a/b.png（仓库外·勿入库）

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	var s: Node = (load("res://src/ui/scenes/scene2.tscn") as PackedScene).instantiate()
	add_child(s)
	await get_tree().create_timer(1.6).timeout
	await _shot("D:/Game/BoBoZan/scene2_shot_a.png")
	await get_tree().create_timer(0.6).timeout
	await _shot("D:/Game/BoBoZan/scene2_shot_b.png")
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

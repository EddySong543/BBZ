extends Node

## HUD 承托件探针（带窗口跑）：
##   godot --path . res://tools/hud_dressing_probe.tscn
## 三帧：0.6s=「回合开始」卷轴宣告拍 / 1.3s=备份（防启动时序漂移）/ 3.2s=倒计时裸字+顶部牌匾常驻。
## 输出：D:/Game/BoBoZan/hud_intro/hud_intro2/hud_countdown.png（仓库外·勿入库）

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	var s: Node = (load("res://src/ui/battle_screen1.tscn") as PackedScene).instantiate()
	add_child(s)
	await get_tree().create_timer(0.6).timeout
	await _snap("D:/Game/BoBoZan/hud_intro.png")
	await get_tree().create_timer(0.7).timeout
	await _snap("D:/Game/BoBoZan/hud_intro2.png")
	await get_tree().create_timer(1.9).timeout
	await _snap("D:/Game/BoBoZan/hud_countdown.png")
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

extends Node

## 战斗界面整屏截图器（作为主场景跑 → 正常加载 autoload·配色落地自检）：
##   godot --path . res://tools/battle_shot.tscn
## 输出：D:/Game/BoBoZan/_probe_output/battle_screen_shot.png（仓库外）

const OUT := "D:/Game/BoBoZan/_probe_output/battle_screen_shot.png"


func _ready() -> void:
	# ⚠窗口尺寸必须钉死：不钉的话本机偶发开成 1444×1061，截图右侧整块缺失
	# （踩过：P2 侧裁图全黑）。scene2_shot_runner 同款处理。
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	var s: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2).timeout   # 等进入选择态（按钮 + 道具栏可见）
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	get_tree().quit()

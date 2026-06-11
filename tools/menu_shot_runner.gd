extends Node

## 真实 main_menu 场景截图 runner（实装自检用·完整引擎模式跑→autoload 可用）：
##   godot --path . res://tools/menu_shot_runner.tscn
## 输出：常态 + ModeMatch 悬停态（金框+放大）两张。

const OUT_IDLE := "D:/Game/BoBoZan/menu_real_idle.png"
const OUT_HOVER := "D:/Game/BoBoZan/menu_real_hover.png"


func _ready() -> void:
	var menu := (load("res://src/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().create_timer(1.8).timeout   # 等发牌入场动画走完
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_IDLE)
	print("saved: ", OUT_IDLE)

	# 模拟悬停：直接置 ModeMatch 热态（金框+放大）
	var card := menu.get_node("UI/ModeMatch")
	card._set_hot(true)
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_HOVER)
	print("saved: ", OUT_HOVER)
	get_tree().quit()

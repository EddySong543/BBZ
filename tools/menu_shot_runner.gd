extends Node

## 真实 main_menu 场景截图 runner（实装自检用·完整引擎模式跑→autoload 可用）：
##   godot --path . res://tools/menu_shot_runner.tscn
## 输出：常态 + ModeMatch 悬停态（金框+放大）两张。

const OUT_IDLE := "D:/Game/BoBoZan/_probe_output/menu_real_idle.png"
const OUT_HOVER := "D:/Game/BoBoZan/_probe_output/menu_real_hover.png"
const OUT_SEARCH := "D:/Game/BoBoZan/_probe_output/menu_real_searching.png"
const OUT_CANCEL := "D:/Game/BoBoZan/_probe_output/menu_real_cancelled.png"


func _ready() -> void:
	var menu := (load("res://src/ui/main_menu.tscn") as PackedScene).instantiate()
	menu.mock_match_seconds = 999.0   # 截图期间不触发"匹配成功"（成功→转场链 Eddy F6 验证）
	add_child(menu)
	await get_tree().create_timer(1.8).timeout   # 等发牌入场动画走完
	await _shot(OUT_IDLE)

	# 模拟悬停：直接置 ModeMatch 热态（金框+放大）
	var card := menu.get_node("UI/ModeMatch")
	card._set_hot(true)
	await get_tree().create_timer(0.35).timeout
	await _shot(OUT_HOVER)
	card._set_hot(false)

	# 开始匹配：盖牌+呼吸+正计时（截 0:01 帧）
	card.emit_signal("pressed")
	await get_tree().create_timer(1.6).timeout
	await _shot(OUT_SEARCH)

	# 取消匹配：翻回正面复原
	card.emit_signal("pressed")
	await get_tree().create_timer(0.8).timeout
	await _shot(OUT_CANCEL)
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

extends Node

## 主菜单顶左身份带悬停态自检（Epic 项⑥反馈修·2026-07-16）：
##   godot --path . res://tools/identity_hover_shot.tscn
## 合成 mouse_entered 信号触发悬停反馈（⛔warp_mouse 不可靠·[[godot-ui-render-quirks]]）：
## 金晕外环显形 + ButtonJuice 轻放大。两张：常态 / 悬停态。
## 输出：统一探针目录（默认 user://probe-output，可由命令行覆盖）。

const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	var menu := (load("res://src/ui/main_menu.tscn") as PackedScene).instantiate()
	menu.mock_match_seconds = 999.0
	add_child(menu)
	await get_tree().create_timer(1.8).timeout   # 等发牌入场动画走完
	await _shot("identity_idle.png")

	var btn := menu.get_node("UI/IdentityButton") as Button
	btn.mouse_entered.emit()                     # 合成悬停：金晕环 + juice 放大
	await get_tree().create_timer(0.3).timeout
	await _shot("identity_hover.png")
	get_tree().quit()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProbeOutput.path(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

extends Node

## 个人资料界面 profile_screen 自检（完整引擎模式·真场景）：
##   godot --path . res://tools/profile_shot_runner.tscn
## 流程：入场 → 截图 → 打开头像选择浮层 → 截图 → 选 h07 关浮层 → 截图（左页换装验证）。
## 探针卫生：PlayerProfile.save_enabled=false 全程关落盘（不污染本机真实资料存档）。
## 输出：统一探针目录（默认 user://probe-output，可由命令行覆盖）。

const ProfileStore := preload("res://src/core/player_profile.gd")
const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	ProfileStore.save_enabled = false
	ProfileStore.reset()
	# 摆拍垫战绩（探针=测试夹具·右页非全零好目检排版）
	for i in 12:
		ProfileStore.record_result("match", "win")
	for i in 5:
		ProfileStore.record_result("match", "lose")
	ProfileStore.record_result("match", "draw")
	for i in 3:
		ProfileStore.record_result("net", "win")
	ProfileStore.record_result("net", "lose")
	ProfileStore.set_player_name("波波老大")
	await get_tree().process_frame
	var p := (load("res://src/ui/profile_screen.tscn") as PackedScene).instantiate()
	add_child(p)
	await get_tree().create_timer(1.2).timeout      # 入场动画完毕
	await _shot("profile_cur_main.png")

	p._open_avatar_picker()
	await get_tree().create_timer(0.4).timeout
	await _shot("profile_cur_picker.png")

	p._pick_avatar("h07")                            # 换头像 → 浮层关 + 左页换装
	await get_tree().create_timer(0.4).timeout
	await _shot("profile_cur_picked.png")
	get_tree().quit()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProbeOutput.path(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

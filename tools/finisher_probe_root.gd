extends Node

## 终结演出探针（带窗口跑）：进战斗屏后直接调用 _play_finisher（P1 斩杀 P2·伤 2HP），
## 两个时间点截屏——命中前后（虚化幕满强度·双雄拉出·慢放中）与恢复后（画面应回原样）。
##   godot --path . res://tools/finisher_probe.tscn
## 输出：D:/Game/BoBoZan/finisher_mid.png / finisher_end.png（仓库外）
## ⚠ 采样计时全用 ignore_time_scale（演出中全场慢放·普通 timer 会被拉长）。

const OUT_MID := "D:/Game/BoBoZan/finisher_mid.png"
const OUT_END := "D:/Game/BoBoZan/finisher_end.png"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2, true, false, true).timeout   # 等进入选择态
	s._play_finisher([0, 4], true, false)
	await get_tree().create_timer(1.0, true, false, true).timeout   # 命中后·幕/拉出/慢放全在场
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_MID)
	print("saved: ", OUT_MID)
	await get_tree().create_timer(1.6, true, false, true).timeout   # 演出结束·应完全恢复
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_END)
	print("saved: ", OUT_END, "  time_scale=", Engine.time_scale)
	get_tree().quit()

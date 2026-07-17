extends Node

## 死亡换人过渡探针（2026-07-17·带窗口跑）：P2 播 defeat 躺地 → 直接跑
## _death_switch_transition(1)（不动 battle 状态·同英雄重入场——验证
## 「遗体消散 → 透明期换装 → 落点入场+尘」三拍视觉·秒切退役）。
##   godot --path . res://tools/death_switch_probe.tscn
## 输出：D:/Game/BoBoZan/dswitch_lying/dissolve/enter/done.png（仓库外·勿入库）

const OUT := "D:/Game/BoBoZan/"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2).timeout
	s.call("_play_defeat", 1)
	await get_tree().create_timer(0.9).timeout      # defeat 播完躺地
	await _snap("dswitch_lying.png")
	s.call("_death_switch_transition", 1)           # async 启动·不 await——中途抓帧
	await get_tree().create_timer(0.30).timeout     # 消散中段（0.38s 淡出）
	await _snap("dswitch_dissolve.png")
	await get_tree().create_timer(0.28).timeout     # ≈0.58s=入场落下中
	await _snap("dswitch_enter.png")
	await get_tree().create_timer(0.5).timeout
	await _snap("dswitch_done.png")
	get_tree().quit()


func _snap(fname: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + fname)
	print("saved: ", OUT + fname)

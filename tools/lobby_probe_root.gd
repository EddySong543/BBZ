extends Node

## 联机大厅探针（M2b·2026-07-12）：拉起大厅屏 → 断言 24 英雄选人格+默认预选 3 人 → 截图。
## 带窗口跑：godot --path . res://tools/lobby_probe.tscn → D:/Game/BoBoZan/net_lobby.png

const OUT_DIR := "D:/Game/BoBoZan/"


func _ready() -> void:
	var fails: Array[String] = []
	var s: Node = load("res://src/ui/net_lobby_screen.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(0.8, true, false, true).timeout
	if (s._hero_btns as Dictionary).size() != 24:
		fails.append("英雄格数=%d（期望 24）" % (s._hero_btns as Dictionary).size())
	if (s._picked as Array).size() != 3:
		fails.append("默认预选=%d（期望 3）" % (s._picked as Array).size())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "net_lobby.png")
	print("LOBBY_PROBE: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit()

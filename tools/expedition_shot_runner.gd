extends Node

## 远征模式界面截图 runner（实装自检用·完整引擎模式跑→autoload 可用）：
##   godot --path . res://tools/expedition_shot_runner.tscn
## 输出：开局态 + 走动数步后（迷雾扩张/可能触发弹窗）两张。

const OUT_IDLE := "D:/Game/BoBoZan/exped_idle.png"
const OUT_WALK := "D:/Game/BoBoZan/exped_walk.png"
const OUT_DEATH := "D:/Game/BoBoZan/exped_death.png"

const WALK_KEYS: Array = [KEY_D, KEY_D, KEY_S, KEY_D, KEY_D, KEY_S, KEY_D, KEY_W, KEY_D, KEY_D]


func _ready() -> void:
	var screen := (load("res://src/expedition/expedition_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(0.6).timeout
	await _shot(OUT_IDLE)
	for k: int in WALK_KEYS:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().create_timer(0.08).timeout
	await get_tree().create_timer(0.4).timeout
	await _shot(OUT_WALK)
	# —— 复现死亡链路（Eddy 踩坑回归）：残血 → 遭遇弹窗 → 代码点"进战" → 死亡结算弹窗 ——
	screen.map.team[0]["hp"] = 0.5
	var mc: Vector2i = screen.map.monsters.keys()[0]
	screen.pending_flee_from = screen.map.player
	screen._prompt_monster(mc)
	await get_tree().create_timer(0.3).timeout
	(screen.dialog_box.get_child(1) as Button).emit_signal("pressed")   # 进战 → 必死
	await get_tree().create_timer(0.4).timeout
	var kids: int = screen.dialog_box.get_child_count()
	print("死亡结算弹窗子节点数=", kids, "（应为 3：文案+2 按钮·>3=旧按钮残留 bug 复发）")
	print("弹窗可见=", screen.dialog.visible, "  局已结束=", screen.map.over)
	await _shot(OUT_DEATH)
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

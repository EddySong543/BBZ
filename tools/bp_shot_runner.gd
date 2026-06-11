extends Node

## 双席牌局 bp_screen 全流程驱动自检（完整引擎模式·真场景）：
##   godot --path . res://tools/bp_shot_runner.tscn
## 流程：开桌入场 → 点 3 卡入手 → 确认盖牌 → 禁用揭晓仪式 → PICK 点 3 卡 → 确认出战
##       → 阵容亮相。逐态截图（不点「开始战斗」——会切场，转场链 Eddy F6 验证）。

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame
	var bp := (load("res://src/ui/bp_screen.tscn") as PackedScene).instantiate()
	add_child(bp)
	await get_tree().create_timer(2.6).timeout      # 开桌入场（含 C1 翻牌扫过）
	await _shot("D:/Game/BoBoZan/bp_real_ban_empty.png")

	bp._on_card_clicked(5)
	await get_tree().create_timer(0.5).timeout
	bp._on_card_clicked(21)
	bp._on_card_clicked(40)
	await get_tree().create_timer(0.8).timeout
	await _shot("D:/Game/BoBoZan/bp_real_ban_hand.png")

	bp._on_confirm()
	await get_tree().create_timer(2.4).timeout      # 仪式中段（翻开+撞车窗口）
	await _shot("D:/Game/BoBoZan/bp_real_ban_ceremony.png")
	await get_tree().create_timer(3.0).timeout      # 仪式收场 → 进 PICK
	await _shot("D:/Game/BoBoZan/bp_real_pick.png")

	# PICK：选 3 个未被禁的
	var picked := 0
	var i := 0
	while picked < 3 and i < 46:
		if not (i in bp.banned):
			bp._on_card_clicked(i)
			picked += 1
		i += 1
	await get_tree().create_timer(0.8).timeout
	bp._on_confirm()
	await get_tree().create_timer(3.6).timeout      # 出战仪式 → 对峙亮相
	await _shot("D:/Game/BoBoZan/bp_real_reveal.png")
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

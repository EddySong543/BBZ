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
	await get_tree().create_timer(2.6).timeout      # 开桌入场完毕（含 C1 翻牌扫过）
	await _shot("D:/Game/BoBoZan/_probe_output/bp_cur_pool.png")

	# 选 2 张已知有效的（12 生肖内）看手牌区
	bp._on_card_clicked(2)
	await get_tree().create_timer(0.4).timeout
	bp._on_card_clicked(7)
	await get_tree().create_timer(0.6).timeout
	await _shot("D:/Game/BoBoZan/_probe_output/bp_cur_hand.png")

	# 第 3 张 → 确认钮就绪态（金呼吸脉冲·2026-07-16 换导航皮后补验）
	bp._on_card_clicked(10)
	await get_tree().create_timer(0.6).timeout
	await _shot("D:/Game/BoBoZan/_probe_output/bp_cur_ready.png")

	# 确认 → 出战亮相仪式（3v3 对扣翻开对峙 + 开始战斗钮）
	bp._on_confirm()
	await get_tree().create_timer(3.2).timeout
	await _shot("D:/Game/BoBoZan/_probe_output/bp_cur_reveal.png")
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

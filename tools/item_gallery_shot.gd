extends Node

## 道具图鉴 item_gallery_screen 自检（完整引擎模式·真场景）：
##   <godot> --path . res://tools/item_gallery_shot.gd（带窗口·非 headless）
## 入场（默认选中 0·一阶）→ 截图。不点返回（波幕转场链 Eddy F6 验证）。

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame
	var g := (load("res://src/ui/item_gallery_screen.tscn") as PackedScene).instantiate()
	add_child(g)
	await get_tree().create_timer(1.6).timeout
	assert(g.get_node_or_null("PoolArea/TierNavigation") == null,
			"左页不得保留可点击稀有度标签")
	assert(g.get_node_or_null("DetailArea/RarityBadge") != null,
			"右页道具图案下方必须显示只读稀有度标签")
	assert(g.get_node_or_null("DetailArea/RarityBadge/BadgeArt") == null,
			"稀有度展示不得继续使用花哨纸签贴图")
	assert(g.get_node_or_null("DetailArea/RarityBadge/TypeMark") != null,
			"稀有度展示必须复用英雄图鉴主被动长方形印签")
	var selected_card := g._cards[g._sel_idx] as Button
	assert(selected_card.get_node_or_null("SelRing") == null,
			"选中道具不得保留旧金色呼吸外环")
	assert((selected_card.get_node("SelectionPointer") as Control).visible,
			"选中道具必须显示英雄图鉴同款三角箭头")
	assert(g.get_node_or_null("DetailArea/DetailRule") == null,
			"右页不得保留水平分割线")
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	g._unhandled_input(right)
	await get_tree().process_frame
	assert(g._sel_idx == 1 and g._d_name.text == tr(g._items[1].item_name),
			"方向键换件后右页内容必须同步刷新")
	g._select(0)
	await _shot("D:/Game/BoBoZan/_probe_output/item_gallery.png")          # 普通第一页
	g.next_page_btn.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	assert(g._current_page == 1 and g._sel_idx == 12, "下一页交互必须进入第 13 件道具")
	await _shot("D:/Game/BoBoZan/_probe_output/item_gallery_page2.png")    # 普通第二页
	g.next_page_btn.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	assert(g._tier == 2 and g._current_page == 0 and g._sel_idx == 0,
			"普通最后一页继续点击下一页必须进入稀有第一页")
	assert((g.get_node("DetailArea/RarityBadge/BadgeLabel") as Label).text == "稀有",
			"进入稀有页后右页标签必须同步显示稀有")
	await _shot("D:/Game/BoBoZan/_probe_output/item_gallery_t2.png")       # 稀有(tier2)
	for _page_step: int in g._catalog_page_count():
		if g._tier >= 3:
			break
		g.next_page_btn.pressed.emit()
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	assert(g._tier == 3, "连续点击下一页必须能够进入传说档")
	assert((g.get_node("DetailArea/RarityBadge/BadgeLabel") as Label).text == "传说",
			"连续翻到传说页后右页标签必须同步显示传说")
	await _shot("D:/Game/BoBoZan/_probe_output/item_gallery_t3.png")       # 传说(tier3)
	for _page_step: int in g._catalog_page_count():
		if g.next_page_btn.disabled:
			break
		g.next_page_btn.pressed.emit()
		await get_tree().process_frame
	assert(g._tier == 3 and g.next_page_btn.disabled,
			"传说最后一页必须停在图鉴末尾并禁用下一页")
	var close_state := {"calls": 0}
	g.embedded_close = func() -> void:
		close_state.calls += 1
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	g._unhandled_input(cancel)
	await get_tree().process_frame
	assert(close_state.calls == 1, "ESC 必须调用内嵌关闭回调且只调用一次")
	g.back_btn.pressed.emit()
	await get_tree().process_frame
	assert(close_state.calls == 2, "返回按钮必须继续调用同一内嵌关闭回调")
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)

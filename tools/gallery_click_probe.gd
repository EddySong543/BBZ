extends Node

## 英雄图鉴交互回归探针（完整引擎模式·真场景）：
##   tools/run_godot.ps1 -Mode Probe -Target res://tools/gallery_click_probe.tscn
## 锁行为：①所有头像框不吞点击；②点击第 3 格选中跟随；
##         ③方向键继续换人；④翻页保留格位；⑤内嵌模式的返回按钮继续走关闭回调。
## 点击=Input.parse_input_event 状态注入（⛔warp_mouse 不可靠·老教训）。

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame
	var g := (load("res://src/ui/hero_gallery_screen.tscn") as PackedScene).instantiate()
	add_child(g)
	await get_tree().create_timer(1.2).timeout   # 等入场翻牌动画收尾

	var filter_ok := true
	for f in g.card_frames:
		if (f as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			filter_ok = false
	var target := 2
	var target_card := g.card_cards[target] as Button
	var pos := target_card.global_position + target_card.size * 0.5
	_click(pos)
	await get_tree().create_timer(0.3).timeout
	var click_sel: int = g._sel_idx

	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	g._unhandled_input(right)
	await get_tree().process_frame
	var key_sel: int = g._sel_idx

	g.next_page_btn.pressed.emit()
	await get_tree().process_frame
	var next_page_sel: int = g._sel_idx
	var next_page_visible: int = g.card_cards.filter(
		func(card: Button) -> bool: return card.visible).size()
	g.previous_page_btn.pressed.emit()
	await get_tree().process_frame
	var previous_page_sel: int = g._sel_idx

	var close_state := {"calls": 0}
	g.embedded_close = func() -> void:
		close_state.calls += 1
	g.back_btn.pressed.emit()
	await get_tree().process_frame
	var close_calls: int = close_state.calls

	if filter_ok and click_sel == target and key_sel == target + 1 \
			and next_page_sel == target + 1 + 12 and next_page_visible == 12 \
			and previous_page_sel == target + 1 and close_calls == 1:
		print("PASS: 点击、方向键、12 位分页、格位保留与内嵌返回均保持有效")
		get_tree().quit()
	else:
		print(
			"FAIL: filter_ok=%s click_sel=%d key_sel=%d next=%d visible=%d previous=%d close=%d"
			% [filter_ok, click_sel, key_sel, next_page_sel, next_page_visible,
				previous_page_sel, close_calls])
		get_tree().quit(1)


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)

extends GutTest

## 故事结算浮层骨架 行为锁定测试（2026-07-17 打地基批·任务10 子项）。
## 锁：胜=通关金字+只留继续钮；负/平=朱墨+再战/返回；奖励空=占位行·有=逐行；
##     再战/继续信号出口（story_screen 靠它们接重开/回列表）。

const ResultPanel := preload("res://src/ui/components/story_result_panel.gd")


func _panel() -> Control:
	var p: Control = ResultPanel.new()
	add_child_autofree(p)
	return p


func test_story_result_panel_win_shows_clear_and_continue_only() -> void:
	# Arrange
	var p := _panel()

	# Act
	p.show_result("某关（占位）", "win", [])

	# Assert
	assert_true(p.visible)
	assert_eq((p.find_child("ResultTitle", true, false) as Label).text, "通 关")
	assert_true((p.find_child("BtnContinue", true, false) as Button).visible)
	assert_false((p.find_child("BtnRetry", true, false) as Button).visible)
	assert_false((p.find_child("BtnBack", true, false) as Button).visible)


func test_story_result_panel_lose_shows_retry_and_back() -> void:
	# Arrange
	var p := _panel()

	# Act
	p.show_result("某关（占位）", "lose", [])

	# Assert
	assert_eq((p.find_child("ResultTitle", true, false) as Label).text, "未 通 关")
	assert_false((p.find_child("BtnContinue", true, false) as Button).visible)
	assert_true((p.find_child("BtnRetry", true, false) as Button).visible)
	assert_true((p.find_child("BtnBack", true, false) as Button).visible)


func test_story_result_panel_draw_counts_as_not_cleared() -> void:
	# Arrange
	var p := _panel()

	# Act
	p.show_result("某关（占位）", "draw", [])

	# Assert：平局=未通关路线（再战可用）
	assert_eq((p.find_child("ResultTitle", true, false) as Label).text, "平局 · 未通关")
	assert_true((p.find_child("BtnRetry", true, false) as Button).visible)


func test_story_result_panel_rewards_placeholder_and_rows() -> void:
	# Arrange / Act：空奖励=占位行
	var p := _panel()
	p.show_result("某关（占位）", "win", [])
	var box := p.find_child("RewardBox", true, false) as VBoxContainer
	assert_eq(box.get_child_count(), 1)
	assert_true((box.get_child(0) as Label).text.contains("占位"))

	# Arrange / Act：有奖励=逐行（新面板防同帧 queue_free 干扰计数）
	var p2 := _panel()
	p2.show_result("某关（占位）", "win", ["奖励条目甲（占位）", "奖励条目乙（占位）"])
	var box2 := p2.find_child("RewardBox", true, false) as VBoxContainer

	# Assert
	assert_eq(box2.get_child_count(), 2)
	assert_true((box2.get_child(0) as Label).text.contains("奖励条目甲"))


func test_story_result_panel_buttons_emit_signals() -> void:
	# Arrange
	var p := _panel()
	p.show_result("某关（占位）", "lose", [])
	watch_signals(p)

	# Act / Assert：再战
	(p.find_child("BtnRetry", true, false) as Button).pressed.emit()
	assert_signal_emitted(p, "retry_pressed")

	# Act / Assert：返回=走继续口（回列表）
	(p.find_child("BtnBack", true, false) as Button).pressed.emit()
	assert_signal_emitted(p, "continue_pressed")

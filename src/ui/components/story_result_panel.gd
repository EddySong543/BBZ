extends Control

## 故事关卡结算浮层骨架（2026-07-17 打地基批·任务10 子项——正式视觉/奖励系统另立项时在此基础上加戏）。
## 回程 toast 的升级件：story_screen._consume_battle_result 记账后弹本浮层——
## 胜=「通关」+继续；负/平=「未通关」+再战/返回。奖励区=数据口（levels.json 可选 rewards
## 字段·字符串数组占位）——奖励系统未立项·空=显示占位行。
## 视觉=家族最小成立版（骨架不加戏）：暗幕+深框奶油纸板（ui_tooltip 9-slice+贴形投影·
## 简介浮层同皮）+墨字+导航钮皮按钮（全游戏导航一语言·五态字色全覆盖防洗白）。
## ⚠ 文案红线：本件只放系统文案（胜利/再战等）·⛔剧情文案（结算旁白等小传定稿后由 Eddy 定）。

signal continue_pressed
signal retry_pressed

const TOOLTIP_TEX := preload("res://assets/ui/ui_tooltip.png")
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")
const TOOLTIP_MARGIN := 20
const NAV_PLATE_MARGIN_X := 22
const NAV_PLATE_MARGIN_Y := 20
const SHADOW_TINT := Color(0.10, 0.07, 0.05, 0.38)   # 贴形投影暖黑（家族同值）
const INK := Color(0.24, 0.19, 0.12)                 # 墨字（奶油纸上）
const INK_DIM := Color(0.24, 0.19, 0.12, 0.62)
const GOLD_CLEAR := Color("8f6a1e")                  # 泥金（通关✓同值·亮纸系）
const RED_FAIL := Color("a83a2c")                    # 朱墨（未通关·敌方语义同值）

const PANEL_RECT := Rect2(640, 316, 640, 448)

var _title_label: Label
var _level_label: Label
var _reward_box: VBoxContainer
var _btn_continue: Button
var _btn_retry: Button
var _btn_back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 90

	# 暗幕（点击=走「继续/返回」·独立 ColorRect ⛔modulate 压暗——BP 仪式同教训）
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.09, 0.085, 0.075, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# 纸板（贴形投影+深框奶油纸·简介浮层/BP 牌池同皮）
	var shadow := _tooltip_patch()
	shadow.position = PANEL_RECT.position + Vector2(6, 8)
	shadow.size = PANEL_RECT.size
	shadow.modulate = SHADOW_TINT
	add_child(shadow)
	var panel := _tooltip_patch()
	panel.name = "Paper"
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	add_child(panel)

	_title_label = _make_label("", 44, INK, PANEL_RECT.position + Vector2(0, 52))
	_title_label.name = "ResultTitle"
	_level_label = _make_label("", 24, INK_DIM, PANEL_RECT.position + Vector2(0, 126))

	var rule := ColorRect.new()
	rule.color = Color(INK, 0.30)
	rule.position = PANEL_RECT.position + Vector2(80, 178)
	rule.size = Vector2(PANEL_RECT.size.x - 160, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)

	var reward_head := _make_label(tr("战 利"), 20, INK_DIM, PANEL_RECT.position + Vector2(0, 198))
	reward_head.name = "RewardHead"
	_reward_box = VBoxContainer.new()
	_reward_box.name = "RewardBox"
	_reward_box.position = PANEL_RECT.position + Vector2(80, 236)
	_reward_box.size = Vector2(PANEL_RECT.size.x - 160, 110)
	_reward_box.add_theme_constant_override("separation", 6)
	add_child(_reward_box)

	_btn_continue = _make_nav_button(tr("继 续"), PANEL_RECT.position + Vector2(220, 366))
	_btn_continue.name = "BtnContinue"
	_btn_continue.pressed.connect(func() -> void: continue_pressed.emit())
	_btn_retry = _make_nav_button(tr("再 战"), PANEL_RECT.position + Vector2(104, 366))
	_btn_retry.name = "BtnRetry"
	_btn_retry.pressed.connect(func() -> void: retry_pressed.emit())
	_btn_back = _make_nav_button(tr("返 回"), PANEL_RECT.position + Vector2(336, 366))
	_btn_back.name = "BtnBack"
	_btn_back.pressed.connect(func() -> void: continue_pressed.emit())


## 弹结算：outcome="win"|"lose"|"draw"·rewards=占位字符串数组（levels.json rewards 字段·可空）。
func show_result(level_title: String, outcome: String, rewards: Array) -> void:
	var win := outcome == "win"
	_title_label.text = tr("通 关") if win else (tr("平局 · 未通关") if outcome == "draw" else tr("未 通 关"))
	_title_label.add_theme_color_override("font_color", GOLD_CLEAR if win else RED_FAIL)
	_level_label.text = tr(level_title)
	for c in _reward_box.get_children():
		c.queue_free()
	if rewards.is_empty():
		var ph := Label.new()
		ph.text = tr("（奖励待设·占位）")
		FontManager.apply(ph, 18)
		ph.add_theme_color_override("font_color", Color(INK, 0.40))
		_reward_box.add_child(ph)
	else:
		for r in rewards:
			var row := Label.new()
			row.text = "· " + tr(String(r))
			FontManager.apply(row, 18)
			row.add_theme_color_override("font_color", INK)
			_reward_box.add_child(row)
	# 胜=只留「继续」；负/平=「再战」+「返回」
	_btn_continue.visible = win
	_btn_retry.visible = not win
	_btn_back.visible = not win
	visible = true
	(_btn_continue if win else _btn_retry).grab_focus()
	# 入场 pop（0.14s 收拢淡入·家族标准）
	var paper := get_node("Paper") as Control
	paper.pivot_offset = paper.size * 0.5
	paper.scale = Vector2(1.06, 1.06)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.14)
	tw.tween_property(paper, "scale", Vector2.ONE, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func close() -> void:
	visible = false


func _on_dim_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		continue_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		accept_event()
		continue_pressed.emit()


func _tooltip_patch() -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = TOOLTIP_TEX
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.patch_margin_left = TOOLTIP_MARGIN
	p.patch_margin_right = TOOLTIP_MARGIN
	p.patch_margin_top = TOOLTIP_MARGIN
	p.patch_margin_bottom = TOOLTIP_MARGIN
	p.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE   # 中段平铺防颗粒拉伸
	p.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _make_label(text_v: String, size_v: int, col: Color, pos: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = text_v
	FontManager.apply(lbl, size_v)
	lbl.add_theme_color_override("font_color", col)
	lbl.position = pos
	lbl.size = Vector2(PANEL_RECT.size.x, size_v + 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	return lbl


## 导航钮皮按钮（bp_screen 确认钮同配方·⚠墨字五态全覆盖防默认灰字洗白——story 换装同坑）。
func _make_nav_button(text_v: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text_v
	btn.position = pos
	btn.size = Vector2(200, 56)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	FontManager.apply_btn(btn, 24)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(cn, INK)
	var plate := NinePatchRect.new()
	plate.name = "Plate"
	plate.texture = NAV_PLATE_TEX
	plate.patch_margin_left = NAV_PLATE_MARGIN_X
	plate.patch_margin_right = NAV_PLATE_MARGIN_X
	plate.patch_margin_top = NAV_PLATE_MARGIN_Y
	plate.patch_margin_bottom = NAV_PLATE_MARGIN_Y
	plate.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.show_behind_parent = true
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击
	btn.add_child(plate)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	btn.add_child(bj)
	add_child(btn)
	return btn

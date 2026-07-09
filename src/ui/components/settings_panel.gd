class_name SettingsPanel
extends Control

## 设置弹框（程序搭建·逻辑为主）。主菜单"设置"按钮打开。
## 改动即时应用 + 持久化（GameSettings）。点遮罩 / 关闭钮 / ESC 关闭。
##
## ⚠ 像素观感未经 F6 验收——配色沿用主菜单"典籍朱印"暖色系（墨字 + 羊皮板），
##   结构清晰、便于后续 .tscn 化或调色。本组件只负责设置的"逻辑 + 基本布局"。

signal closed

const INK := Color(0.20, 0.14, 0.08)         # 墨（羊皮上的字）
const INK_SOFT := Color(0.42, 0.34, 0.24)    # 淡墨（次级字）
const PANEL_BACKING := Color(0.16, 0.11, 0.07, 0.99)  # 墨色书脊衬底
const PANEL_FILL := Color(0.88, 0.82, 0.68, 0.99)     # 羊皮页填充
const SEP_COLOR := Color(0.45, 0.36, 0.24, 0.5)       # 暖墨分隔线
const CARD_SIZE := Vector2(580.0, 700.0)

## 显示模式选项（键=GameSettings 值·序=循环切换顺序）。
const WINDOW_MODES: Array[String] = ["windowed", "borderless", "fullscreen"]
const WINDOW_MODE_NAMES := {
	"windowed": "窗口化",
	"borderless": "全屏窗口化",
	"fullscreen": "全屏(独占)",
}

var _color_swatch: ColorRect
var _res_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 吞住背后输入
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


# ============================================================
# 构建
# ============================================================

func _build() -> void:
	# 半透遮罩（点击空白关闭）
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# 中央面板（墨书脊衬底 + 羊皮页）
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -CARD_SIZE.x * 0.5
	card.offset_top = -CARD_SIZE.y * 0.5
	card.offset_right = CARD_SIZE.x * 0.5
	card.offset_bottom = CARD_SIZE.y * 0.5
	add_child(card)

	var backing := ColorRect.new()
	backing.color = PANEL_BACKING
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_child(backing)
	var fill := ColorRect.new()
	fill.color = PANEL_FILL
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 3.0
	fill.offset_top = 3.0
	fill.offset_right = -3.0
	fill.offset_bottom = -3.0
	fill.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_child(fill)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 34)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "设置"
	FontManager.apply(title, 40)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(_separator())

	# —— 界面主色 翻转（必做项）——
	vbox.add_child(_color_row())
	# —— 显示（模式循环切换 + 窗口化分辨率·2026-07-09 取代旧全屏开关）——
	vbox.add_child(_window_mode_row())
	vbox.add_child(_resolution_row())
	_refresh_res_enabled()
	# —— 音量 ——
	vbox.add_child(_slider_row("总音量", "master_volume"))
	vbox.add_child(_slider_row("音乐", "music_volume"))
	vbox.add_child(_slider_row("音效", "sfx_volume"))

	vbox.add_child(_separator())

	# —— 底部按钮 ——
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 18)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var reset := _make_button("恢复默认")
	reset.pressed.connect(_on_reset)
	btn_row.add_child(reset)
	var close := _make_button("关闭")
	close.pressed.connect(_close)
	btn_row.add_child(close)
	vbox.add_child(btn_row)


# ============================================================
# 行构件
# ============================================================

func _separator() -> Control:
	var line := ColorRect.new()
	line.color = SEP_COLOR
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	FontManager.apply(l, 24)
	l.add_theme_color_override("font_color", INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	FontManager.apply_btn(b, 22)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK_SOFT)
	b.custom_minimum_size = Vector2(150.0, 50.0)
	return b


## 显示模式行：标签 + 循环切换钮（窗口化 → 全屏窗口化 → 全屏独占 → 循环）。
func _window_mode_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_row_label("显示模式"))
	var btn := _make_button(String(WINDOW_MODE_NAMES.get(String(GameSettings.get_value("window_mode")), "窗口化")))
	btn.custom_minimum_size = Vector2(210.0, 50.0)
	btn.pressed.connect(func() -> void:
		var cur: int = WINDOW_MODES.find(String(GameSettings.get_value("window_mode")))
		var next: String = WINDOW_MODES[(cur + 1) % WINDOW_MODES.size()]
		GameSettings.set_value("window_mode", next)
		btn.text = String(WINDOW_MODE_NAMES[next])
		_refresh_res_enabled())
	row.add_child(btn)
	return row


## 分辨率行（仅窗口化模式可用）：标签 + 循环切换钮（预设按屏幕大小过滤）。
func _resolution_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_row_label("分辨率"))
	_res_button = _make_button(String(GameSettings.get_value("resolution")))
	_res_button.custom_minimum_size = Vector2(210.0, 50.0)
	_res_button.pressed.connect(func() -> void:
		var opts: Array[String] = _available_resolutions()
		var cur: int = opts.find(String(GameSettings.get_value("resolution")))
		var next: String = opts[(cur + 1) % opts.size()]
		GameSettings.set_value("resolution", next)
		_res_button.text = next)
	row.add_child(_res_button)
	return row


## 预设分辨率按当前屏幕过滤（不给出比屏幕还大的选项）；全被滤掉时保底设计画布档。
func _available_resolutions() -> Array[String]:
	var scr := DisplayServer.screen_get_size()
	var out: Array[String] = []
	for r in GameSettings.RESOLUTION_PRESETS:
		var sz := GameSettings.parse_resolution(r)
		if sz.x <= scr.x and sz.y <= scr.y:
			out.append(r)
	if out.is_empty():
		out.append("1920x1080")
	return out


## 分辨率行仅窗口化模式可点（全屏两档尺寸由系统接管）。
func _refresh_res_enabled() -> void:
	if _res_button == null:
		return
	var windowed: bool = String(GameSettings.get_value("window_mode")) == "windowed"
	_res_button.disabled = not windowed
	_res_button.modulate.a = 1.0 if windowed else 0.45


## 滑块行（音量）：标签 + HSlider(0~1) + 百分比，即时写设置。
func _slider_row(label_text: String, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_row_label(label_text))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(GameSettings.get_value(key))
	slider.custom_minimum_size = Vector2(230.0, 36.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(70.0, 0.0)
	FontManager.apply(pct, 20)
	pct.add_theme_color_override("font_color", INK_SOFT)
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.text = "%d%%" % roundi(slider.value * 100.0)
	slider.value_changed.connect(func(v: float) -> void:
		GameSettings.set_value(key, v)
		pct.text = "%d%%" % roundi(v * 100.0))
	row.add_child(slider)
	row.add_child(pct)
	return row


## 界面主色 翻转行：标签 + 当前主色色块 + 「翻转颜色」钮。
## 点钮 → invert_colors 取反 → 实时刷新菜单/BP 波流背景 + 色块（红↔蓝即时可见）。
func _color_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_row_label("界面主色"))
	_color_swatch = ColorRect.new()
	_color_swatch.color = BootResult.dip_color()
	_color_swatch.custom_minimum_size = Vector2(48.0, 36.0)
	_color_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_color_swatch)
	var flip := _make_button("翻转颜色")
	flip.pressed.connect(_on_flip_color)
	row.add_child(flip)
	return row


# ============================================================
# 行为
# ============================================================

func _on_flip_color() -> void:
	GameSettings.set_value("invert_colors", not bool(GameSettings.get_value("invert_colors")))
	get_tree().call_group("wave_flow_bg", "refresh_colors")   # 实时刷新菜单/BP 背景
	if _color_swatch != null:
		_color_swatch.color = BootResult.dip_color()


func _on_reset() -> void:
	GameSettings.reset_defaults()
	get_tree().call_group("wave_flow_bg", "refresh_colors")
	# 重建面板以反映默认值
	for c in get_children():
		c.queue_free()
	_build()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()   # 拦下 ESC，别让主菜单也响应
		_close()


func _close() -> void:
	GameSettings.save()
	closed.emit()
	queue_free()

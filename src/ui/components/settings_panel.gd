class_name SettingsPanel
extends Control

## 设置弹框（主菜单/战斗共用·GameSettings 即时应用+持久化·点遮罩/关闭钮/ESC 关闭）。
## 2026-07-15 换装（Epic 项⑦·Eddy 选 A）：程序占位羊皮板退役→家族语言全套——
## 面板身=抽卡纸卡 item_draft_card ×2 整数放大（263×355→526×710·像素无损）+贴形投影；
## 标题=牌匾 9-slice 骑缝悬挂+墨字（图鉴同配方）；切换钮/底钮=导航钮皮（全游戏导航一语言）；
## 滑块=深巧克力轨+实心金方滑柄（纹样"粗笔+实心芯"同语）；主色 swatch=近黑描边框。
## 显示模式/分辨率链路 2026-07-15 实测 6 项 PASS（tools/display_probe·⚠编辑器内嵌运行不生效属正常）。

signal closed

const CARD_TEX := preload("res://assets/ui/item_draft_card.png")
const PLAQUE_TEX := preload("res://assets/ui/ui_plaque.png")
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")
const NAV_PLATE_MARGIN_X := 22   # v14 净面（main_menu/图鉴同值）
const NAV_PLATE_MARGIN_Y := 20

const INK := Color(0.24, 0.19, 0.12)           # 墨（纸面主文字·图鉴同值）
const INK_DIM := Color(0.48, 0.41, 0.28)       # 淡墨（次级字/分隔线·图鉴同值）
const NEAR_BLACK := Color("130c08")            # 近黑（家族描边色·资产实测）
const GOLD := Color("d4a94e")                  # 平头金（滑柄/填充带）
const CHOCO := Color("4f2b14")                 # 深巧克力（滑轨·家族纹线色）
const SHADOW_TINT := Color(0.10, 0.07, 0.05, 0.38)   # 贴形投影暖黑（图鉴牌匾同值）

const CARD_SIZE := Vector2(526.0, 710.0)       # item_draft_card 263×355 ×2 整数放大
const PLAQUE_SIZE := Vector2(240.0, 62.0)

## 显示模式选项（键=GameSettings 值·序=循环切换顺序）。
const WINDOW_MODES: Array[String] = ["windowed", "borderless", "fullscreen"]
const WINDOW_MODE_NAMES := {
	"windowed": "窗口化",
	"borderless": "全屏窗口化",
	"fullscreen": "全屏(独占)",
}

var _swatch_sb: StyleBoxFlat
var _res_button: Button
var _grabber_tex: ImageTexture


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
	# 半透暖黑遮罩（点击空白关闭）
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# 中央纸卡（贴形投影+卡身·入场轻收拢 pop）
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -CARD_SIZE.x * 0.5
	card.offset_top = -CARD_SIZE.y * 0.5
	card.offset_right = CARD_SIZE.x * 0.5
	card.offset_bottom = CARD_SIZE.y * 0.5
	card.pivot_offset = CARD_SIZE * 0.5
	add_child(card)
	card.scale = Vector2(0.96, 0.96)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var cshadow := _card_tex_rect()
	cshadow.position = Vector2(6.0, 8.0)
	cshadow.modulate = SHADOW_TINT
	card.add_child(cshadow)
	var body := _card_tex_rect()
	body.mouse_filter = Control.MOUSE_FILTER_STOP   # 面板身吞点击（防漏到遮罩关闭）
	card.add_child(body)

	# 牌匾标题（骑缝悬挂在卡顶·贴形投影——图鉴同配方）
	var px := (CARD_SIZE.x - PLAQUE_SIZE.x) * 0.5
	var py := -PLAQUE_SIZE.y * 0.5
	var pshadow := _plaque_rect()
	pshadow.position = Vector2(px + 6.0, py + 8.0)
	pshadow.modulate = SHADOW_TINT
	card.add_child(pshadow)
	var plaque := _plaque_rect()
	plaque.position = Vector2(px, py)
	card.add_child(plaque)
	var title := Label.new()
	title.text = tr("设置")
	title.position = Vector2(px, py - 4.0)
	title.size = PLAQUE_SIZE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	FontManager.apply(title, 36)
	title.add_theme_color_override("font_color", INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)

	# 内容（卡内线以内·顶部让开牌匾下半）
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 58)
	margin.add_theme_constant_override("margin_right", 58)
	margin.add_theme_constant_override("margin_top", 68)
	margin.add_theme_constant_override("margin_bottom", 48)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 26)
	margin.add_child(vbox)

	# —— 界面主色 翻转 ——
	vbox.add_child(_color_row())
	# —— 显示（模式循环切换 + 窗口化分辨率）——
	vbox.add_child(_window_mode_row())
	vbox.add_child(_resolution_row())
	_refresh_res_enabled()
	vbox.add_child(_separator())
	# —— 音量 ——
	vbox.add_child(_slider_row("总音量", "master_volume"))
	vbox.add_child(_slider_row("音乐", "music_volume"))
	vbox.add_child(_slider_row("音效", "sfx_volume"))
	vbox.add_child(_separator())

	# 弹性撑挡：把底钮压到卡底（内容组靠上·卡下部不留大片空白纸）
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	# —— 底部按钮 ——
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 22)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var reset := _make_button("恢复默认")
	reset.pressed.connect(_on_reset)
	btn_row.add_child(reset)
	var close := _make_button("关闭")
	close.pressed.connect(_close)
	btn_row.add_child(close)
	vbox.add_child(btn_row)


func _card_tex_rect() -> TextureRect:
	var t := TextureRect.new()
	t.texture = CARD_TEX
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = CARD_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _plaque_rect() -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = PLAQUE_TEX
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.patch_margin_left = 26   # 新牌匾（265×63）角钩区实量（图鉴同值）
	p.patch_margin_right = 26
	p.patch_margin_top = 23
	p.patch_margin_bottom = 23
	p.size = PLAQUE_SIZE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# ============================================================
# 行构件
# ============================================================

func _separator() -> Control:
	var line := ColorRect.new()
	line.color = Color(INK_DIM, 0.5)
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = tr(text)
	FontManager.apply(l, 24)
	l.add_theme_color_override("font_color", INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## 导航钮皮按钮（图鉴返回钮同配方：文字钮空样式+背后 9-slice 签牌+ButtonJuice）。
func _make_button(text: String, min_size := Vector2(150.0, 46.0)) -> Button:
	var b := Button.new()
	b.text = tr(text)
	FontManager.apply_btn(b, 22)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.55))
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.custom_minimum_size = min_size
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
	b.add_child(plate)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	b.add_child(bj)
	return b


## 显示模式行：标签 + 循环切换钮（窗口化 → 全屏窗口化 → 全屏独占 → 循环）。
func _window_mode_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_row_label("显示模式"))
	var btn := _make_button(String(WINDOW_MODE_NAMES.get(String(GameSettings.get_value("window_mode")), "窗口化")), Vector2(216.0, 46.0))
	btn.pressed.connect(func() -> void:
		var cur: int = WINDOW_MODES.find(String(GameSettings.get_value("window_mode")))
		var next: String = WINDOW_MODES[(cur + 1) % WINDOW_MODES.size()]
		GameSettings.set_value("window_mode", next)
		btn.text = tr(String(WINDOW_MODE_NAMES[next]))
		_refresh_res_enabled())
	row.add_child(btn)
	return row


## 分辨率行（仅窗口化模式可用）：标签 + 循环切换钮（预设按屏幕大小过滤）。
func _resolution_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_row_label("分辨率"))
	_res_button = _make_button(String(GameSettings.get_value("resolution")), Vector2(216.0, 46.0))
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


## 滑块行（音量）：标签 + 族色 HSlider（深巧克力轨+金填充+实心金方滑柄）+ 百分比。
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
	_style_slider(slider)
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(70.0, 0.0)
	FontManager.apply(pct, 20)
	pct.add_theme_color_override("font_color", INK_DIM)
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.text = "%d%%" % roundi(slider.value * 100.0)
	slider.value_changed.connect(func(v: float) -> void:
		GameSettings.set_value(key, v)
		pct.text = "%d%%" % roundi(v * 100.0))
	row.add_child(slider)
	row.add_child(pct)
	return row


## 滑块族色化：轨=深巧克力细条·已填带=金·滑柄=实心金方块+近黑描边（程序生成一次复用）。
func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = CHOCO
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("slider", track)
	var filled := StyleBoxFlat.new()
	filled.bg_color = GOLD
	filled.content_margin_top = 3.0
	filled.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	if _grabber_tex == null:
		var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
		img.fill(NEAR_BLACK)
		img.fill_rect(Rect2i(2, 2, 14, 14), GOLD)
		_grabber_tex = ImageTexture.create_from_image(img)
	slider.add_theme_icon_override("grabber", _grabber_tex)
	slider.add_theme_icon_override("grabber_highlight", _grabber_tex)
	slider.add_theme_icon_override("grabber_disabled", _grabber_tex)


## 界面主色 翻转行：标签 + 当前主色色块（近黑描边框）+ 「翻转颜色」钮。
## 点钮 → invert_colors 取反 → 实时刷新菜单/BP 波流背景 + 色块（红↔蓝即时可见）。
func _color_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_row_label("界面主色"))
	var swatch := Panel.new()
	_swatch_sb = StyleBoxFlat.new()
	_swatch_sb.bg_color = BootResult.dip_color()
	_swatch_sb.border_color = NEAR_BLACK
	for side in ["border_width_left", "border_width_right", "border_width_top", "border_width_bottom"]:
		_swatch_sb.set(side, 2)
	swatch.add_theme_stylebox_override("panel", _swatch_sb)
	swatch.custom_minimum_size = Vector2(48.0, 36.0)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
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
	if _swatch_sb != null:
		_swatch_sb.bg_color = BootResult.dip_color()


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

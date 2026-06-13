extends Control

## UI 材质方向对比样例（2026-06-13 Eddy：A/B/C/融合 都做一版同布局对照后再定）。
## 同一张"页+正文+三按钮(常态/悬停/主行动)+印"，套四套材质，按 1/2/3/4 切换：
##   1 = A 漆木鎏金（暖木+金，暗 UI）
##   2 = B 典籍朱印（亮羊皮+墨线+朱印+金箔，亮 UI）
##   3 = C 星璇靛紫（深靛紫+金丝+星点，暗 UI·暖向非冷灰）
##   4 = 融合（C 靛紫底 + A 金 + B 朱印行动）
## 全部复用现有 jelly shader 调参 → 证明"换材质≈改色参，结构不动"。开本场景按 F6。

const JELLY := preload("res://assets/shaders/canvas_button_jelly.gdshader")
const BG_SCENE := preload("res://src/ui/scenes/menu_background.tscn")

var _palettes: Array = [_pal_a(), _pal_b(), _pal_c(), _pal_fusion()]
var _idx: int = 0
var _content: Control
var _header: Label


# ============================================================
# 四套调色板（jelly 参数集）
# ============================================================

## A 漆木鎏金：暖胡桃木底（有渐变深度）+ 金棕浮雕边，hover 镀金箔，主行动朱漆红。暗 UI·亮金字。
func _pal_a() -> Dictionary:
	return {
		"name": "A · 漆木鎏金（暖木 + 金 / 暗 UI）",
		"fill": [Color(0.32, 0.21, 0.13), Color(0.19, 0.12, 0.07)],
		"fill_hot": [Color(0.40, 0.27, 0.16), Color(0.25, 0.16, 0.09)],
		"edge": [Color(0.52, 0.38, 0.20), Color(0.10, 0.06, 0.03)],
		"edge_hot": [Color(0.97, 0.85, 0.48), Color(0.42, 0.28, 0.10)],
		"text": Color(0.95, 0.88, 0.66), "text_soft": Color(0.74, 0.64, 0.46), "text_hot": Color(1.0, 0.92, 0.66),
		"title": Color(0.97, 0.85, 0.48),
		"primary_edge": Color(0.78, 0.32, 0.18), "primary_text": Color(1.0, 0.86, 0.62),
		"seal": [Color(0.78, 0.34, 0.18), Color(0.62, 0.22, 0.10), Color(0.92, 0.62, 0.32), Color(0.30, 0.10, 0.04), Color(1.0, 0.92, 0.70)],
		"divider": Color(0.60, 0.45, 0.22, 0.45), "dot": Color(0.78, 0.32, 0.18, 0.85),
		"noise": 0.06, "wear": 0.22, "corner": 0.14, "panel_corner": 0.06,
	}


## B 典籍朱印：哑光羊皮（关糖光）+ 墨线 + 朱印，hover 镀金箔。亮 UI·墨字。
func _pal_b() -> Dictionary:
	return {
		"name": "B · 典籍朱印（亮羊皮 + 墨线 + 朱印 / 亮 UI）",
		"fill": [Color(0.88, 0.82, 0.68), Color(0.82, 0.75, 0.60)],
		"fill_hot": [Color(0.95, 0.90, 0.76), Color(0.89, 0.82, 0.67)],
		"edge": [Color(0.60, 0.50, 0.36), Color(0.18, 0.12, 0.07)],
		"edge_hot": [Color(0.97, 0.85, 0.48), Color(0.40, 0.28, 0.10)],
		"text": Color(0.18, 0.12, 0.07), "text_soft": Color(0.46, 0.37, 0.26), "text_hot": Color(0.40, 0.28, 0.10),
		"title": Color(0.18, 0.12, 0.07),
		"primary_edge": Color(0.74, 0.24, 0.18), "primary_text": Color(0.52, 0.18, 0.12),
		"seal": [Color(0.80, 0.28, 0.22), Color(0.74, 0.24, 0.18), Color(0.88, 0.40, 0.32), Color(0.34, 0.08, 0.06), Color(0.96, 0.92, 0.80)],
		"divider": Color(0.18, 0.12, 0.07, 0.45), "dot": Color(0.74, 0.24, 0.18, 0.85),
		"noise": 0.08, "wear": 0.24, "corner": 0.14, "panel_corner": 0.06,
	}


## C 星璇靛紫：深靛紫（暖向·非冷灰）+ 金丝边 + 星点，hover 镀金。暗 UI·暖白字。
func _pal_c() -> Dictionary:
	return {
		"name": "C · 星璇靛紫（深靛紫 + 金丝 / 暗 UI）",
		"fill": [Color(0.17, 0.13, 0.26), Color(0.09, 0.06, 0.16)],
		"fill_hot": [Color(0.22, 0.17, 0.33), Color(0.12, 0.09, 0.21)],
		"edge": [Color(0.50, 0.42, 0.30), Color(0.05, 0.03, 0.10)],
		"edge_hot": [Color(0.95, 0.82, 0.46), Color(0.34, 0.24, 0.10)],
		"text": Color(0.90, 0.88, 0.80), "text_soft": Color(0.66, 0.62, 0.74), "text_hot": Color(1.0, 0.92, 0.70),
		"title": Color(0.86, 0.78, 0.98),
		"primary_edge": Color(0.64, 0.52, 0.86), "primary_text": Color(0.92, 0.86, 1.0),
		"seal": [Color(0.55, 0.45, 0.75), Color(0.40, 0.30, 0.60), Color(0.90, 0.78, 0.45), Color(0.15, 0.10, 0.25), Color(0.98, 0.92, 0.75)],
		"divider": Color(0.55, 0.50, 0.66, 0.42), "dot": Color(0.90, 0.78, 0.45, 0.85),
		"noise": 0.05, "wear": 0.14, "corner": 0.14, "panel_corner": 0.06,
	}


## 融合：C 靛紫底 + A 金边/金箔 + B 朱印行动。暗 UI·暖金米字。
func _pal_fusion() -> Dictionary:
	return {
		"name": "融合 · 靛紫底 + 鎏金 + 朱印行动（暗 UI）",
		"fill": [Color(0.16, 0.13, 0.25), Color(0.08, 0.06, 0.15)],
		"fill_hot": [Color(0.21, 0.17, 0.32), Color(0.11, 0.08, 0.20)],
		"edge": [Color(0.58, 0.46, 0.24), Color(0.05, 0.04, 0.10)],
		"edge_hot": [Color(0.99, 0.86, 0.50), Color(0.40, 0.28, 0.12)],
		"text": Color(0.94, 0.89, 0.74), "text_soft": Color(0.70, 0.66, 0.78), "text_hot": Color(1.0, 0.93, 0.70),
		"title": Color(0.97, 0.85, 0.50),
		"primary_edge": Color(0.80, 0.30, 0.22), "primary_text": Color(1.0, 0.86, 0.66),
		"seal": [Color(0.80, 0.28, 0.22), Color(0.74, 0.24, 0.18), Color(0.88, 0.40, 0.32), Color(0.34, 0.08, 0.06), Color(1.0, 0.92, 0.74)],
		"divider": Color(0.58, 0.46, 0.24, 0.42), "dot": Color(0.80, 0.30, 0.22, 0.85),
		"noise": 0.06, "wear": 0.18, "corner": 0.14, "panel_corner": 0.06,
	}


# ============================================================
# 场景
# ============================================================

func _ready() -> void:
	var bg := BG_SCENE.instantiate() as Control
	add_child(bg)
	move_child(bg, 0)
	# 顶部说明（白字深描边·任何变体/背景上都可读）
	_header = Label.new()
	_header.position = Vector2(0, 28)
	_header.size = Vector2(get_viewport_rect().size.x, 32)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontManager.apply(_header, 22)
	_header.add_theme_color_override("font_color", Color.WHITE)
	_header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_header.add_theme_constant_override("outline_size", 4)
	_header.z_index = 100
	add_child(_header)
	_show(0)


func _show(i: int) -> void:
	_idx = clampi(i, 0, _palettes.size() - 1)
	if _content:
		_content.free()
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 透传 → 子按钮仍可点
	add_child(_content)
	move_child(_content, 1)   # bg(0) 之上、header 之下
	var pal: Dictionary = _palettes[_idx]
	_build(pal, get_viewport_rect().size)
	_header.text = "材质对比  [%d/4]  %s    ·    按 1 / 2 / 3 / 4 切换" % [_idx + 1, pal["name"]]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1: _show(0)
			KEY_2: _show(1)
			KEY_3: _show(2)
			KEY_4: _show(3)


func _build(pal: Dictionary, vp: Vector2) -> void:
	var panel_size := Vector2(980, 660)
	var panel_pos := ((vp - panel_size) * 0.5).round()
	_content.add_child(_substrate_rect(panel_pos, panel_size, pal["panel_corner"], pal))

	var cx := panel_pos.x + panel_size.x * 0.5

	var title := _label("命 运 典 籍", Vector2(panel_pos.x, panel_pos.y + 46), Vector2(panel_size.x, 44), 32, pal["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)
	_seal_stamp(Vector2(cx - 150, panel_pos.y + 44), 40, "命", pal)

	var sub := _label(pal["name"], Vector2(panel_pos.x, panel_pos.y + 100), Vector2(panel_size.x, 26), 16, pal["text_soft"])
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(sub)

	_hairline(Vector2(panel_pos.x + 120, panel_pos.y + 142), panel_size.x - 240, pal)

	var body := _label(
		"「命运如书，英雄如印。每一次对决，都是翻开新的一页。」\n\n"
		+ "这是本套外壳语言：底材、勾边、点睛印、悬停镀光，构成统一的按钮/面板/卡牌质感。\n"
		+ "请将光标移到下方「常态」「确认」上，看悬停的镀光与抬升反馈。",
		Vector2(panel_pos.x + 120, panel_pos.y + 176), Vector2(panel_size.x - 240, 220), 16, pal["text"])
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_content.add_child(body)

	var bw := 260.0
	var bh := 68.0
	var gap := 40.0
	var row_w := bw * 3 + gap * 2
	var bx := cx - row_w * 0.5
	var by := panel_pos.y + panel_size.y - 130.0
	_btn("常 态", Vector2(bx, by), Vector2(bw, bh), false, false, pal)
	_btn("悬停展示", Vector2(bx + bw + gap, by), Vector2(bw, bh), true, false, pal)
	_btn("确 认", Vector2(bx + (bw + gap) * 2, by), Vector2(bw, bh), false, true, pal)

	var hint := _label("（中间为锁定的悬停态，便于左右对照）",
		Vector2(panel_pos.x, by + bh + 16), Vector2(panel_size.x, 24), 14, pal["text_soft"])
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(hint)


# ============================================================
# 部件工厂
# ============================================================

func _substrate_rect(pos: Vector2, sz: Vector2, corner: float, pal: Dictionary) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = JELLY
	m.set_shader_parameter("fill_top", pal["fill"][0])
	m.set_shader_parameter("fill_bottom", pal["fill"][1])
	m.set_shader_parameter("edge_inner", pal["edge"][0])
	m.set_shader_parameter("edge_outer", pal["edge"][1])
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 44.0)
	m.set_shader_parameter("corner", corner)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("noise_amt", pal["noise"])
	m.set_shader_parameter("wear", pal["wear"])
	m.set_shader_parameter("aspect", sz.x / maxf(sz.y, 1.0))
	r.material = m
	return r


func _btn(text: String, pos: Vector2, sz: Vector2, force_hot: bool, primary: bool, pal: Dictionary) -> void:
	var btn := Button.new()
	btn.position = pos
	btn.size = sz
	btn.text = text
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	FontManager.apply_btn(btn, 24)
	btn.add_theme_color_override("font_color", pal["primary_text"] if primary else pal["text"])
	btn.add_theme_color_override("font_hover_color", pal["text_hot"])
	var bg := _substrate_rect(Vector2.ZERO, sz, pal["corner"], pal)
	bg.name = "Bg"
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(bg)
	_btn_palette(bg, force_hot, primary, pal)
	_content.add_child(btn)
	if primary:
		var stamp := _seal_stamp(pos + Vector2(sz.x - 26, -14), 34, "印", pal)
		stamp.z_index = 2
	if not force_hot:
		btn.mouse_entered.connect(func() -> void: _btn_palette(bg, true, primary, pal))
		btn.mouse_exited.connect(func() -> void: _btn_palette(bg, false, primary, pal))
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	btn.add_child(bj)


func _btn_palette(bg: ColorRect, hot: bool, primary: bool, pal: Dictionary) -> void:
	var m := bg.material as ShaderMaterial
	m.set_shader_parameter("fill_top", pal["fill_hot"][0] if hot else pal["fill"][0])
	m.set_shader_parameter("fill_bottom", pal["fill_hot"][1] if hot else pal["fill"][1])
	m.set_shader_parameter("edge_inner", pal["edge_hot"][0] if hot else pal["edge"][0])
	var base_outer: Color = pal["primary_edge"] if primary else pal["edge"][1]
	m.set_shader_parameter("edge_outer", pal["edge_hot"][1] if hot else base_outer)


func _seal_stamp(pos: Vector2, sz: float, glyph: String, pal: Dictionary) -> Control:
	var s: Array = pal["seal"]
	var stamp := ColorRect.new()
	stamp.position = pos
	stamp.size = Vector2(sz, sz)
	stamp.color = Color.WHITE
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = JELLY
	m.set_shader_parameter("fill_top", s[0])
	m.set_shader_parameter("fill_bottom", s[1])
	m.set_shader_parameter("edge_inner", s[2])
	m.set_shader_parameter("edge_outer", s[3])
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 24.0)
	m.set_shader_parameter("corner", 0.18)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("noise_amt", 0.05)
	m.set_shader_parameter("wear", 0.18)
	m.set_shader_parameter("aspect", 1.0)
	stamp.material = m
	_content.add_child(stamp)
	var g := _label(glyph, pos, Vector2(sz, sz), 16, s[4])
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.z_index = 1
	_content.add_child(g)
	return stamp


func _hairline(pos: Vector2, w: float, pal: Dictionary) -> void:
	var ln := ColorRect.new()
	ln.position = pos
	ln.size = Vector2(w, 2)
	ln.color = pal["divider"]
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(ln)
	for dx in [-8.0, w]:
		var dot := ColorRect.new()
		dot.position = pos + Vector2(dx, -3)
		dot.size = Vector2(6, 8)
		dot.color = pal["dot"]
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(dot)


func _label(text: String, pos: Vector2, sz: Vector2, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	FontManager.apply(l, px)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

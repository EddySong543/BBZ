extends Control

## 一次性 DEMO：菜单波「降疲劳」调参台 —— B 平息动效 + E 静息区 + 色彩弧(舒适淡色↔满饱和)。F6 跑本场景。
##
## 不引用任何生产文件。背景 shader = tools/wave_calm_demo.gdshader（生产波拷贝 + B/E/色彩弧 旋钮·已对齐生产菜单亮度）。
## 用法：
##   · 顶部【色彩弧】：选调色板 A/B/C → 拖 sat 看「淡↔满」任意定格 → 按「▶ 播放色彩弧」一键看完
##     静息淡 → 点击点燃 → 红蓝对撞峰值 → 一波闪平息回淡 的全过程。
##   · 「蓝/红」切胜方色（菜单保留胜方色 → 淡色也按胜方取蓝侧/红侧锚色）。
##   · 中段【B 平息】【E 静息区】滑块细调静息态；预设钮快切对比。
##   · 右下「当前数值」实时显示，调满意把数字 + 选定调色板发我，我并回生产。Esc 退出。

const SHADER := preload("res://tools/wave_calm_demo.gdshader")

# —— 生产默认（= 满饱和基线）——
const PROD_DRIFT := 0.045
const PROD_YDRIFT := 0.6
const PROD_AMP := 0.18

# —— B「平息动效」预设（= 开局默认）——
const B_DRIFT := 0.022
const B_YDRIFT := 0.30
const B_AMP := 0.11
const B_BREATH := 0.12

# —— 舒适淡色调色板（每套一对：蓝胜 / 红胜·见对话提案 A/B/C）——
const PALETTES := [
	{name = "A 破晓宣纸", blue = Color("c2d4d8"), red = Color("ebd0c2")},
	{name = "B 晨雾天光", blue = Color("bad2e8"), red = Color("f2cec4")},
	{name = "C 暮色靛金", blue = Color("a6bcd0"), red = Color("dbb0a0")},
]

# —— 色彩弧时间线（秒）——
const SAT_IDLE := 0.25                  # 静息态饱和度（淡）
const ARC_HOLD0 := 0.5                  # 开场静息保持
const ARC_RISE := 0.8                   # 点击点燃·升到满
const ARC_PEAK := 0.5                   # 对撞峰值保持
const ARC_FALL := 1.7                   # 一波闪后平息回淡
const ARC_T1 := ARC_HOLD0
const ARC_T2 := ARC_T1 + ARC_RISE
const ARC_T3 := ARC_T2 + ARC_PEAK
const ARC_END := ARC_T3 + ARC_FALL

# —— 三卡真实位置（1920×1080 参考分辨率换算成 UV 锚点）——
const CARD_RECTS := [
	[0.1146, 0.1667, 0.3438, 0.7685],   # Story
	[0.3750, 0.1481, 0.6250, 0.7870],   # Match（居中）
	[0.6563, 0.1667, 0.8854, 0.7685],   # Tower
]

var _mat: ShaderMaterial
var _guides: Control

# —— 驱动状态 ——
var _phase := 0.0
var _wave_t := 0.0
var _breath_t := 0.0

# —— 色彩弧状态 ——
var _palette_idx := 0
var _sat_manual := SAT_IDLE              # sat 滑块值（不播放时生效）
var _playing := false
var _arc_t := 0.0

# —— 可调状态（开局 = B 平息 + E 开）——
var _drift := B_DRIFT
var _ydrift := B_YDRIFT
var _amp := B_AMP
var _breath_amt := B_BREATH
var _breath_speed := 0.5
var _rest_on := true
var _rest_cy := 0.47
var _rest_sx := 0.40
var _rest_sy := 0.33
var _rest_soft := 0.55
var _rest_motion := 0.25
var _rest_smooth := 0.40
var _use_blue := true

var _sliders: Dictionary = {}
var _vlabels: Dictionary = {}
var _rest_check: CheckButton
var _blue_check: CheckButton
var _guide_check: CheckButton
var _readout: Label
var _phase_label: Label
var _palette_btns: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_guides()
	_build_panel()
	_push_static()
	_refresh_palette_btns()
	_refresh_readout()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.WHITE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	bg.material = _mat
	add_child(bg)
	get_viewport().size_changed.connect(_update_aspect)
	_update_aspect()


func _build_guides() -> void:
	_guides = Control.new()
	_guides.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guides.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guides.visible = false
	for r: Array in CARD_RECTS:
		var p := Panel.new()
		p.anchor_left = r[0]
		p.anchor_top = r[1]
		p.anchor_right = r[2]
		p.anchor_bottom = r[3]
		p.offset_left = 0.0
		p.offset_top = 0.0
		p.offset_right = 0.0
		p.offset_bottom = 0.0
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.0, 0.0, 0.0, 0.18)
		sb.border_color = Color(1.0, 0.95, 0.7, 0.9)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(10)
		p.add_theme_stylebox_override("panel", sb)
		_guides.add_child(p)
	add_child(_guides)


func _build_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scroll.offset_left = 20.0
	scroll.offset_top = 20.0
	scroll.offset_right = 580.0
	scroll.offset_bottom = 1050.0
	var panel := PanelContainer.new()
	scroll.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_add_title(box, "菜单波调参台 · B 平息 + E 静息区 + 色彩弧")
	_add_hint(box, "选调色板 → 拖 sat 或按▶播放色彩弧。Esc 退出。")

	# ===== 色彩弧 =====
	_add_section(box, "色彩弧 · 舒适淡色 ↔ 满饱和对撞")
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	box.add_child(prow)
	for i in PALETTES.size():
		var b := Button.new()
		b.text = PALETTES[i]["name"]
		b.toggle_mode = true
		b.pressed.connect(_set_palette.bind(i))
		prow.add_child(b)
		_palette_btns.append(b)
	_add_slider(box, "sat 饱和度(0淡/1满)", "sat", 0.0, 1.0, 0.01, _sat_manual)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	box.add_child(arow)
	var play := Button.new()
	play.text = "▶ 播放色彩弧"
	play.pressed.connect(_play_arc)
	arow.add_child(play)
	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 14)
	_phase_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_phase_label.text = "静息·舒适淡色"
	arow.add_child(_phase_label)

	# ===== 全局开关 =====
	_rest_check = _add_check(box, "E 静息区 开", _rest_on, func(on: bool) -> void:
		_rest_on = on
		_push_static()
		_refresh_readout())
	_blue_check = _add_check(box, "蓝胜方色（关=红）", _use_blue, func(on: bool) -> void:
		_use_blue = on
		_push_static()
		_refresh_readout())
	_guide_check = _add_check(box, "显示卡牌参考框", false, func(on: bool) -> void:
		_guides.visible = on)

	# ===== 预设 =====
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 6)
	box.add_child(presets)
	_add_button(presets, "满饱和基线", _apply_baseline)
	_add_button(presets, "只 B", _apply_only_b)
	_add_button(presets, "只 E", _apply_only_e)
	_add_button(presets, "B + E", _apply_be)

	_add_section(box, "B · 平息动效")
	_add_slider(box, "drift 横向流速", "drift", 0.005, 0.08, 0.001, _drift)
	_add_slider(box, "y_drift 纵向漂速", "ydrift", 0.1, 1.2, 0.01, _ydrift)
	_add_slider(box, "wave_amp 波振幅", "amp", 0.04, 0.30, 0.005, _amp)
	_add_slider(box, "breath 呼吸幅度", "breath", 0.0, 0.5, 0.01, _breath_amt)

	_add_section(box, "E · 静息区（需开上面开关）")
	_add_slider(box, "中心 Y", "rcy", 0.30, 0.70, 0.01, _rest_cy)
	_add_slider(box, "椭圆宽", "rsx", 0.20, 0.60, 0.01, _rest_sx)
	_add_slider(box, "椭圆高", "rsy", 0.15, 0.50, 0.01, _rest_sy)
	_add_slider(box, "边缘羽化", "rsoft", 0.05, 1.0, 0.01, _rest_soft)
	_add_slider(box, "区内振幅留存", "rmot", 0.0, 1.0, 0.01, _rest_motion)
	_add_slider(box, "区内颗粒留存", "rsm", 0.0, 1.0, 0.01, _rest_smooth)

	_add_section(box, "当前数值（抄这段并回生产）")
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 13)
	_readout.add_theme_color_override("font_color", Color(0.95, 0.92, 0.75))
	box.add_child(_readout)

	add_child(scroll)


# ── UI 构建小工具 ─────────────────────────────────────────

func _add_title(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(1.0, 0.97, 0.85))
	box.add_child(l)


func _add_hint(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.82))
	box.add_child(l)


func _add_section(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = "— " + text + " —"
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	box.add_child(l)


func _add_button(parent: HBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


func _add_check(box: VBoxContainer, text: String, pressed: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = pressed
	c.toggled.connect(cb)
	box.add_child(c)
	return c


func _add_slider(box: VBoxContainer, text: String, key: String, lo: float, hi: float, step: float, val: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(150, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(230, 0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vlbl := Label.new()
	vlbl.custom_minimum_size = Vector2(60, 0)
	vlbl.text = _fmt(val)
	vlbl.add_theme_font_size_override("font_size", 13)
	s.value_changed.connect(func(v: float) -> void:
		_set_param(key, v)
		vlbl.text = _fmt(v))
	row.add_child(lbl)
	row.add_child(s)
	row.add_child(vlbl)
	box.add_child(row)
	_sliders[key] = s
	_vlabels[key] = vlbl


func _fmt(v: float) -> String:
	return "%.3f" % v


# ── 参数写入 ─────────────────────────────────────────────

func _set_param(key: String, v: float) -> void:
	match key:
		"sat":
			_sat_manual = v
			_playing = false   # 手动拖 sat → 停止播放
		"drift": _drift = v
		"ydrift": _ydrift = v
		"amp": _amp = v
		"breath": _breath_amt = v
		"rcy": _rest_cy = v
		"rsx": _rest_sx = v
		"rsy": _rest_sy = v
		"rsoft": _rest_soft = v
		"rmot": _rest_motion = v
		"rsm": _rest_smooth = v
	_push_static()
	_refresh_readout()


## 推「非时间 / 非 sat」uniform（sat 与相位在 _process 推）。
func _push_static() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("wave_amp", _amp)
	_mat.set_shader_parameter("use_blue", 1.0 if _use_blue else 0.0)
	_mat.set_shader_parameter("drift_dir", 1.0 if _use_blue else -1.0)
	_mat.set_shader_parameter("rest_enable", 1.0 if _rest_on else 0.0)
	_mat.set_shader_parameter("rest_center", Vector2(0.5, _rest_cy))
	_mat.set_shader_parameter("rest_size", Vector2(_rest_sx, _rest_sy))
	_mat.set_shader_parameter("rest_soft", _rest_soft)
	_mat.set_shader_parameter("rest_motion", _rest_motion)
	_mat.set_shader_parameter("rest_smooth", _rest_smooth)
	_mat.set_shader_parameter("pale_color", _current_pale())


## 当前 调色板 + 胜方 对应的舒适淡锚色。
func _current_pale() -> Color:
	var p: Dictionary = PALETTES[_palette_idx]
	return p["blue"] if _use_blue else p["red"]


func _update_aspect() -> void:
	if _mat == null:
		return
	var s := get_viewport_rect().size
	if s.y > 0.0:
		_mat.set_shader_parameter("aspect", s.x / s.y)


func _refresh_palette_btns() -> void:
	for i in _palette_btns.size():
		_palette_btns[i].button_pressed = (i == _palette_idx)


func _refresh_readout() -> void:
	if _readout == null:
		return
	var pale := _current_pale()
	var p: Dictionary = PALETTES[_palette_idx]
	var lines := [
		"调色板 = %s" % p["name"],
		"侧 = %s  淡锚色 = #%s" % ["蓝" if _use_blue else "红", pale.to_html(false)],
		"sat(静息) = %.2f" % _sat_manual,
		"—— B 平息 ——",
		"drift_speed=%.3f  y_drift=%.3f" % [_drift, _ydrift],
		"wave_amp=%.3f  breath_amt=%.3f" % [_amp, _breath_amt],
		"—— E 静息区 ——",
		"rest_enable=%s  center=(0.50,%.2f)" % [str(_rest_on), _rest_cy],
		"rest_size=(%.2f,%.2f) soft=%.2f" % [_rest_sx, _rest_sy, _rest_soft],
		"rest_motion=%.2f  rest_smooth=%.2f" % [_rest_motion, _rest_smooth],
	]
	_readout.text = "\n".join(lines)


# ── 色彩弧 ────────────────────────────────────────────────

func _set_palette(idx: int) -> void:
	_palette_idx = idx
	_refresh_palette_btns()
	_push_static()
	_refresh_readout()


func _play_arc() -> void:
	_playing = true
	_arc_t = 0.0


## 色彩弧 sat(t)：静息淡 → 点燃升满 → 峰值 → 平息回淡。
func _arc_sat(t: float) -> float:
	if t < ARC_T1:
		return SAT_IDLE
	if t < ARC_T2:
		var u := (t - ARC_T1) / ARC_RISE
		return lerpf(SAT_IDLE, 1.0, u * u)                 # ease-in 点燃
	if t < ARC_T3:
		return 1.0                                          # 对撞峰值
	if t < ARC_END:
		var u := (t - ARC_T3) / ARC_FALL
		return lerpf(1.0, SAT_IDLE, 1.0 - (1.0 - u) * (1.0 - u))  # ease-out 平息
	return SAT_IDLE


func _arc_phase(t: float) -> String:
	if t < ARC_T1:
		return "① 静息·舒适淡色"
	if t < ARC_T2:
		return "② 点击 → 冲击波点燃"
	if t < ARC_T3:
		return "③ 红蓝对撞·峰值"
	if t < ARC_END:
		return "④ 一波闪 → 平息入菜单"
	return "静息·舒适淡色"


# ── 预设 ─────────────────────────────────────────────────

func _set_slider(key: String, v: float) -> void:
	var s: HSlider = _sliders.get(key)
	if s != null:
		s.value = v


func _apply_baseline() -> void:
	_rest_check.button_pressed = false
	_set_slider("drift", PROD_DRIFT)
	_set_slider("ydrift", PROD_YDRIFT)
	_set_slider("amp", PROD_AMP)
	_set_slider("breath", 0.0)


func _apply_only_b() -> void:
	_rest_check.button_pressed = false
	_set_slider("drift", B_DRIFT)
	_set_slider("ydrift", B_YDRIFT)
	_set_slider("amp", B_AMP)
	_set_slider("breath", B_BREATH)


func _apply_only_e() -> void:
	_rest_check.button_pressed = true
	_set_slider("drift", PROD_DRIFT)
	_set_slider("ydrift", PROD_YDRIFT)
	_set_slider("amp", PROD_AMP)
	_set_slider("breath", 0.0)


func _apply_be() -> void:
	_rest_check.button_pressed = true
	_set_slider("drift", B_DRIFT)
	_set_slider("ydrift", B_YDRIFT)
	_set_slider("amp", B_AMP)
	_set_slider("breath", B_BREATH)


# ── 驱动 ─────────────────────────────────────────────────

func _process(delta: float) -> void:
	_phase += delta * _drift
	_wave_t += delta * _ydrift
	_breath_t += delta * _breath_speed
	if _mat == null:
		return
	_mat.set_shader_parameter("phase", _phase)
	_mat.set_shader_parameter("wave_time", _wave_t)
	_mat.set_shader_parameter("breath", sin(_breath_t) * _breath_amt)
	# 色彩弧：播放时按时间线推 sat，否则用滑块值。
	var sat_eff := _sat_manual
	if _playing:
		_arc_t += delta
		sat_eff = _arc_sat(_arc_t)
		if _phase_label != null:
			_phase_label.text = _arc_phase(_arc_t)
		if _arc_t >= ARC_END:
			_playing = false
			sat_eff = SAT_IDLE
			if _phase_label != null:
				_phase_label.text = "静息·舒适淡色"
	_mat.set_shader_parameter("sat", sat_eff)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

extends Control

## 一次性 DEMO：菜单波「B 平息动效 + E 静息区」对比调参台。F6 跑本场景即可。
##
## 不引用任何生产文件。背景 shader = tools/wave_calm_demo.gdshader（生产波拷贝 + B/E 旋钮）。
## 用法：
##   · 右上四个预设钮快速切 [生产基线 / 只B / 只E / B+E]，先用它一眼比出差别。
##   · 左侧滑块细调；右下「当前数值」实时显示，调到满意把数字记下，喊我并回 canvas_env_wave_flow。
##   · 「红/蓝」切胜方色；「卡牌参考框」叠出三卡真实位置，看静息区是否罩住卡。
##   · Esc 退出。

const SHADER := preload("res://tools/wave_calm_demo.gdshader")

# —— 生产默认（= 基线，rest 关闭时与现网完全一致）——
const PROD_DRIFT := 0.045
const PROD_YDRIFT := 0.6
const PROD_AMP := 0.18

# —— B「平息动效」预设 ——
const B_DRIFT := 0.022
const B_YDRIFT := 0.30
const B_AMP := 0.11
const B_BREATH := 0.12

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

# —— 可调状态（滑块/钮写入，_process / _push_static 推给 shader）——
var _drift := PROD_DRIFT
var _ydrift := PROD_YDRIFT
var _amp := PROD_AMP
var _breath_amt := 0.0
var _breath_speed := 0.5
var _rest_on := false
var _rest_cy := 0.47
var _rest_sx := 0.40
var _rest_sy := 0.33
var _rest_soft := 0.55
var _rest_motion := 0.25
var _rest_smooth := 0.40
var _use_blue := true

var _sliders: Dictionary = {}        # key -> HSlider
var _vlabels: Dictionary = {}        # key -> Label（数值）
var _rest_check: CheckButton
var _blue_check: CheckButton
var _guide_check: CheckButton
var _readout: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_guides()
	_build_panel()
	_push_static()
	_refresh_readout()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.WHITE                       # shader 乘 COLOR，须白
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
	scroll.position = Vector2(20, 20)
	scroll.custom_minimum_size = Vector2(520, 0)
	scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scroll.offset_left = 20.0
	scroll.offset_top = 20.0
	scroll.offset_right = 560.0
	scroll.offset_bottom = 1040.0
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

	_add_title(box, "菜单波 · B 平息动效 + E 静息区 · 调参台")
	_add_hint(box, "先用预设一眼比差别，再用滑块细调。Esc 退出。")

	# —— 预设钮 ——
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 6)
	box.add_child(presets)
	_add_button(presets, "生产基线", _apply_baseline)
	_add_button(presets, "只 B", _apply_only_b)
	_add_button(presets, "只 E", _apply_only_e)
	_add_button(presets, "B + E", _apply_be)

	# —— 全局开关 ——
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


## 把所有「非时间」uniform 推给 shader（时间相位在 _process 推）。
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


func _update_aspect() -> void:
	if _mat == null:
		return
	var s := get_viewport_rect().size
	if s.y > 0.0:
		_mat.set_shader_parameter("aspect", s.x / s.y)


func _refresh_readout() -> void:
	if _readout == null:
		return
	var lines := [
		"drift_speed   = %.3f" % _drift,
		"y_drift_speed = %.3f" % _ydrift,
		"wave_amp      = %.3f" % _amp,
		"breath_amt    = %.3f" % _breath_amt,
		"rest_enable   = %s" % ("true" if _rest_on else "false"),
		"rest_center   = (0.50, %.2f)" % _rest_cy,
		"rest_size     = (%.2f, %.2f)" % [_rest_sx, _rest_sy],
		"rest_soft     = %.2f" % _rest_soft,
		"rest_motion   = %.2f" % _rest_motion,
		"rest_smooth   = %.2f" % _rest_smooth,
		"color         = %s" % ("蓝" if _use_blue else "红"),
	]
	_readout.text = "\n".join(lines)


# ── 预设 ─────────────────────────────────────────────────

func _set_slider(key: String, v: float) -> void:
	var s: HSlider = _sliders.get(key)
	if s != null:
		s.value = v      # 触发 value_changed → _set_param → 推 shader + 刷读数


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
	if _mat != null:
		_mat.set_shader_parameter("phase", _phase)
		_mat.set_shader_parameter("wave_time", _wave_t)
		_mat.set_shader_parameter("breath", sin(_breath_t) * _breath_amt)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

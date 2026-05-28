extends Control

## 波波攒 · 对波加载界面（原型 · 多档颜色 + 持续涌入小波 版）
##
## 时间轴（一条线，绝无 sleep / wait / hold / 死帧）：
##   t=0      ──┐
##   推进 0.85s  │  pulse_l_x 0→0.5、pulse_r_x 1→0.5（平滑、连续从两侧推进到中央）
##   t=0.85   ──┤
##   撞击 0.20s  │  pulse_amp 1→0 + center_amp 0→1 + wave_amp 0→0.22 + intensity 短促闪
##   t=1.05   ──┘
##   僵持（_process 接管）：
##     · wave_time 持续推进 → 两侧小波不断涌入中央（永不静止）
##     · clash_pos 在 0.5 附近 _struggle 小幅游走
##     · center_amp 0.9-1.1 微脉动（只影响中央白柱，不全屏闪烁）
##     · 等待玩家点击
##
## 像素机制：shader 64 列大格、每格纯色；亮度量化 40 档 → 蓝/红各 40 种由暗到亮
## 相邻格 cuv 差 1/64 → L 差跨多档 → 自然显格颗粒；不需要任何描边/暗缝。

const ADVANCE_TIME := 0.85
const IMPACT_TIME := 0.20
const SWEEP_TIME := 0.85
const WAVE_SPEED := 6.0       # 持续涌入小波的相位推进速度
const WAVE_AMP_INTRO := 0.10  # 推进期小波（背景纹理让方格颗粒可见，被 pulse 主导）
const WAVE_AMP_TARGET := 0.25 # 撞击后小波稳态振幅

@onready var _wave: ColorRect = $Wave

var _mat: ShaderMaterial
var _t := 0.0
var _wave_t := 0.0     # 小波相位（每帧持续推进，全程不停）
var _phase := "advance"
var _title: Label
var _prompt: Label


func _ready() -> void:
	_mat = _wave.material as ShaderMaterial
	_update_aspect()
	get_viewport().size_changed.connect(_update_aspect)
	_build_labels()
	if get_tree().root.has_meta("wave_screenshot_mode"):
		_phase = "done"
		set_process(false)
		return
	# 起手：两道大波在屏幕最外缘；底色档 ~14（base 0.35 × 40 档）= 中等蓝/红已就位
	_mat.set_shader_parameter("pulse_l_x", 0.0)
	_mat.set_shader_parameter("pulse_r_x", 1.0)
	_mat.set_shader_parameter("pulse_amp", 1.0)
	_mat.set_shader_parameter("center_amp", 0.0)
	_mat.set_shader_parameter("wave_amp", WAVE_AMP_INTRO)
	_mat.set_shader_parameter("wave_time", 0.0)
	_mat.set_shader_parameter("clash_pos", 0.5)
	_mat.set_shader_parameter("intensity", 1.0)
	_run_intro()


func _update_aspect() -> void:
	var s := get_viewport_rect().size
	if s.y > 0.0:
		_mat.set_shader_parameter("aspect", s.x / s.y)


func _build_labels() -> void:
	_title = Label.new()
	_title.text = "波波攒之王"
	FontManager.apply(_title, 96)
	_title.add_theme_color_override("font_color", Color("#fdf3d0"))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_title.add_theme_constant_override("outline_size", 6)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 80.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.modulate.a = 0.0
	add_child(_title)

	_prompt = Label.new()
	_prompt.text = ""
	FontManager.apply(_prompt, 36)
	_prompt.add_theme_color_override("font_color", Color("#e8eef7"))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -150.0
	_prompt.offset_bottom = -90.0
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)


## 单一时间轴：推进 → 撞击 → 僵持，全程 tween 连贯，无任何 timer/hold。
func _run_intro() -> void:
	# ── 1) 推进：两道大波从屏幕外缘平滑推进到中央 ─────
	_phase = "advance"
	var tw_a := create_tween().set_parallel(true)
	tw_a.tween_method(_set_pulse_l, 0.0, 0.5, ADVANCE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_a.tween_method(_set_pulse_r, 1.0, 0.5, ADVANCE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw_a.finished

	# ── 2) 撞击：脉冲消散 + center 起 + 小波起 + intensity 短促闪 ─────
	_phase = "impact"
	var tw_i := create_tween().set_parallel(true)
	tw_i.tween_method(_set_pulse_amp, 1.0, 0.0, IMPACT_TIME)
	tw_i.tween_method(_set_center, 0.0, 1.0, IMPACT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_i.tween_method(_set_wave_amp, WAVE_AMP_INTRO, WAVE_AMP_TARGET, IMPACT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_i.tween_method(_set_intensity, 1.0, 1.18, 0.08)
	tw_i.tween_method(_set_intensity, 1.18, 1.0, IMPACT_TIME - 0.08).set_delay(0.08)
	tw_i.tween_property(_title, "modulate:a", 1.0, IMPACT_TIME)
	await tw_i.finished

	# ── 3) 僵持：_process 接管 ─────
	_phase = "ready"
	_prompt.text = "点击屏幕进入游戏"


func _process(_delta: float) -> void:
	_t += _delta
	# 小波相位全程推进（不依赖 _phase）→ 撞击后 wave_amp>0 时立刻有运动中的波
	_wave_t += _delta * WAVE_SPEED
	_mat.set_shader_parameter("wave_time", _wave_t)
	if _phase == "ready":
		_struggle()
		# 中央白柱微脉动 0.9-1.1 → 局部脉动，不全屏闪
		var c := 1.0 + sin(_t * 3.2) * 0.10
		_mat.set_shader_parameter("center_amp", c)
		_prompt.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)


## 僵持期：边界小幅游走（双频率，互不相让的"角力"感）。
func _struggle() -> void:
	var pos := 0.5 + sin(_t * 1.3) * 0.022 + sin(_t * 2.9 + 1.0) * 0.010
	_mat.set_shader_parameter("clash_pos", pos)


func _input(event: InputEvent) -> void:
	if _phase != "ready":
		return
	var go := false
	if event is InputEventMouseButton:
		go = event.pressed
	elif event is InputEventScreenTouch:
		go = event.pressed
	elif event is InputEventKey:
		go = event.pressed and not event.echo
	if go:
		_trigger_sweep()


## 点击 → 随机一方盖过（base_L 由 flood 自动 tween 提亮 → "逐渐高亮过渡"）。
func _trigger_sweep() -> void:
	_phase = "sweeping"
	var blue_wins := randf() < 0.5
	var target := 1.0 if blue_wins else 0.0
	var pt := create_tween()
	pt.tween_property(_prompt, "modulate:a", 0.0, 0.25)
	var cur := _mat.get_shader_parameter("clash_pos") as float
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(_set_clash, cur, target, SWEEP_TIME)
	tw.tween_callback(_on_swept.bind(blue_wins))


func _on_swept(blue_wins: bool) -> void:
	_phase = "done"
	var who := "蓝方" if blue_wins else "红方"
	print("[wave_clash] %s 盖过 → 进入游戏 (placeholder, 未接入)" % who)


# ── shader 参数 setter ────────────────────────────────────────
func _set_clash(v: float) -> void:
	_mat.set_shader_parameter("clash_pos", v)

func _set_intensity(v: float) -> void:
	_mat.set_shader_parameter("intensity", v)

func _set_pulse_l(v: float) -> void:
	_mat.set_shader_parameter("pulse_l_x", v)

func _set_pulse_r(v: float) -> void:
	_mat.set_shader_parameter("pulse_r_x", v)

func _set_pulse_amp(v: float) -> void:
	_mat.set_shader_parameter("pulse_amp", v)

func _set_center(v: float) -> void:
	_mat.set_shader_parameter("center_amp", v)

func _set_wave_amp(v: float) -> void:
	_mat.set_shader_parameter("wave_amp", v)

extends Control

## 波波攒 · 对波加载界面（原型 · 风格化重制 v2 · 2026-05-29）
##
## 时间轴（一条线，绝无 sleep/wait/hold 死帧；连击的"蓄力顿挫"期 _process 仍在涌波）：
##   t=0      ──┐
##   推进 0.85s  │  pulse_l_x 0→0.5、pulse_r_x 1→0.5（平滑、连续从两侧推进到中央）
##   t=0.85   ──┤
##   撞击 0.20s  │  pulse_amp 1→0 + center_amp 0→1 + wave_amp 0→target + intensity 短促闪
##   t=1.05   ──┘
##   僵持（_process 接管）：
##     · phase_l/phase_r 持续累加 → 两侧非对称浪头不断从屏外涌入中央（屏外淡入·中央淡出）
##     · clash_pos 在 0.5 附近 _struggle 小幅游走
##     · center_amp 微脉动（只影响中央白柱，不全屏闪）
##     · 等待玩家点击
##   点击 → 连击盖过（C 型）：
##     胜方波加速冲锋 → 4 击猛攻（中线 clash_pos 小范围受击震颤 + 每击 hit_flash 局部闪，张力累积）
##     → 第 5 下崩溃决堤：clash_pos 从中央一鼓作气冲到 0/1 + burst 扩散环 + 白闪
##
## 像素机制：shader 64 列大格、每格纯色；亮度量化 40 档 + Bayer 抖动 → 复古像素渐变
## 波形：非对称浪头（陡前缘 + 长拖尾）；颗粒：2D 格点 hash（非水平长条）。

const ADVANCE_TIME := 0.85
const IMPACT_TIME := 0.20
const WAVE_AMP_INTRO := 0.10   # 推进期小波（背景纹理让方格颗粒可见，被 pulse 主导）
const WAVE_AMP_TARGET := 0.18  # 撞击后稳态振幅

const Y_DRIFT_SPEED := 1.2     # 波纹纵向漂浮速度（与推进相位解耦）
const BASE_PHASE_SPEED := 0.45 # 僵持期两侧波相位推进速度
const CHARGE_PHASE_SPEED := 2.4 # 盖过期胜方加速冲锋的相位速度
const LOSER_PHASE_SPEED := 0.18 # 盖过期败方被压制（波变疏弱）

@onready var _wave: ColorRect = $Wave

var _mat: ShaderMaterial
var _t := 0.0
var _wave_t := 0.0             # 波纹纵向漂浮相位
var _phase_l := 0.0            # 蓝侧波累积相位
var _phase_r := 0.25           # 红侧波累积相位（初始偏移 → 左右不同步）
var _speed_l := BASE_PHASE_SPEED
var _speed_r := BASE_PHASE_SPEED
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
	# 起手：两道大波在屏幕最外缘；底色档 ~14（base 0.35 × 40 档）已就位
	_mat.set_shader_parameter("pulse_l_x", 0.0)
	_mat.set_shader_parameter("pulse_r_x", 1.0)
	_mat.set_shader_parameter("pulse_amp", 1.0)
	_mat.set_shader_parameter("center_amp", 0.0)
	_mat.set_shader_parameter("wave_amp", WAVE_AMP_INTRO)
	_mat.set_shader_parameter("phase_l", _phase_l)
	_mat.set_shader_parameter("phase_r", _phase_r)
	_mat.set_shader_parameter("wave_time", 0.0)
	_mat.set_shader_parameter("clash_pos", 0.5)
	_mat.set_shader_parameter("intensity", 1.0)
	_mat.set_shader_parameter("hit_flash", 0.0)
	_mat.set_shader_parameter("burst", 0.0)
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


func _process(delta: float) -> void:
	_t += delta
	# 波相位全程推进（不依赖 _phase）→ 撞击后 wave_amp>0 时立刻有运动中的波
	_wave_t += delta * Y_DRIFT_SPEED
	_phase_l += delta * _speed_l
	_phase_r += delta * _speed_r
	_mat.set_shader_parameter("wave_time", _wave_t)
	_mat.set_shader_parameter("phase_l", _phase_l)
	_mat.set_shader_parameter("phase_r", _phase_r)
	if _phase == "ready":
		_struggle()
		# 中央白柱微脉动 1.0-1.20 → 中心微上调一档；clamp 后不爆白
		var c := 1.10 + sin(_t * 3.2) * 0.10
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


## 点击 → 连击盖过（C 型）：胜方波加速 → 4 击顿挫退边界 → 第 5 下崩溃爆发。
func _trigger_sweep() -> void:
	_phase = "sweeping"
	var blue_wins := randf() < 0.5
	# 胜方加速冲锋，败方被压制（波变疏弱）
	if blue_wins:
		_speed_l = CHARGE_PHASE_SPEED
		_speed_r = LOSER_PHASE_SPEED
	else:
		_speed_r = CHARGE_PHASE_SPEED
		_speed_l = LOSER_PHASE_SPEED
	var pt := create_tween()
	pt.tween_property(_prompt, "modulate:a", 0.0, 0.18)
	_run_combo(blue_wins)


## 连击序列：4 击猛攻（中线小范围受击震颤 + 每击局部闪蓄力）→ 第 5 下崩溃决堤。
func _run_combo(blue_wins: bool) -> void:
	# 4 击蓄力：中线 clash_pos 围绕中央(0.5)小范围受击震颤（朝胜方弹一小截再回弹，
	# 守住、不单向移动），配合胜方波加速冲锋 + 每击 hit_flash 局部闪体现"一道道猛攻"；
	# 张力累积到第 5 下才崩溃决堤。
	var strikes := 4
	var dir := 1.0 if blue_wins else -1.0
	for i in strikes:
		var dur := 0.13 - i * 0.018  # 每击的持续（越往后越快）
		var kick := 0.022 + i * 0.004  # 震幅随击数略增（越撞越猛）
		_set_hit(1.0)
		var tw := create_tween()
		tw.tween_method(_set_hit, 1.0, 0.0, dur + 0.06)
		# 中线受击震颤：朝胜方弹出一小截，再回弹到中央（围绕 0.5 抖动，不单向移动）
		var kt := create_tween()
		kt.tween_method(_set_clash, 0.5, 0.5 + dir * kick, dur * 0.4) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		kt.tween_method(_set_clash, 0.5 + dir * kick, 0.5, dur * 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		# 蓄力顿挫（越往后越短）；此期 _process 仍在涌波，非死帧
		var pause := 0.13 - i * 0.022
		await get_tree().create_timer(pause).timeout

	# ── 第 5 下：崩溃爆发 ─────
	var target := 1.0 if blue_wins else 0.0
	var cur2 := _mat.get_shader_parameter("clash_pos") as float
	_set_hit(1.0)
	var bt := create_tween().set_parallel(true)
	bt.tween_method(_set_clash, cur2, target, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bt.tween_method(_set_hit, 1.0, 0.0, 0.18)
	bt.tween_method(_set_burst, 0.0, 1.2, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 白闪：短促"砰"一下（0.07s 冲到 1.30 再落回），避免长时间过曝糊白
	bt.tween_method(_set_intensity, 1.0, 1.30, 0.07)
	bt.tween_method(_set_intensity, 1.30, 1.0, 0.33).set_delay(0.07)
	await bt.finished
	_set_burst(0.0)
	_on_swept(blue_wins)


func _on_swept(blue_wins: bool) -> void:
	_phase = "done"
	var who := "蓝方" if blue_wins else "红方"
	print("[wave_clash] %s 连击盖过 → 进入游戏 (placeholder, 未接入)" % who)


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

func _set_hit(v: float) -> void:
	_mat.set_shader_parameter("hit_flash", v)

func _set_burst(v: float) -> void:
	_mat.set_shader_parameter("burst", v)

extends Control

## 波波攒 · 对波启动过场（boot_screen）—— 游戏 main_scene 入口。
##
## 从原型 prototypes/wave_clash_title/ 提升为生产场景（2026-05-29）。完整机制/迭代见原型 README。
## 左蓝右红两道波推进 → 撞击 → 中央僵持（持续涌波）→ 点击屏幕 → 连击盖过 → 进入标题屏。
##
## 时间轴（一条线，绝无 sleep/wait/hold 死帧；连击"蓄力顿挫"期 _process 仍在涌波）：
##   推进 0.85s → 撞击 0.20s → 僵持(_process 接管，等待点击) → 连击盖过(C 型) → 切场景。
## 连击盖过：胜方波加速冲锋 → 4 击猛攻（中线阻尼震颤 + hit_flash 局部闪 + 轻 shake）
##   → 第 5 下崩溃决堤（clash 冲到 0/1 + burst 全屏光爆发 + 强 shake）
##   → 交棒全局波幕（TransitionManager.reveal_into）：胜方波同色同向接管 → 切菜单 → 排走揭幕。
##
## 像素机制：shader 64 列大格、每格纯色；亮度量化 40 档 + Bayer 抖动。
## 视觉 v3「对波解剖」（2026-07-17·canvas_boot_wave_clash.gdshader）：暗档底场（无满屏噪点）
## + 波前三层（暗缘/爆亮芯/色鞘·电性碎沿·脉动呼吸）+ 向心能量丝 + 窄炽角力光墙；
## 撞点火花/电弧演出在 clash_fx.gd 节点层（本脚本喂 seam + 按节拍 burst）。
## ⚠ 旧 wave_clash.gdshader 仍归主菜单 mode_card 卡面用，两文件独立。

const NEXT_SCENE := "res://src/ui/main_menu.tscn"

# preload 而非裸 class_name：新建全局类在 headless/GUT 场景缓存未刷新时会报 not declared。
const AudioEventsBoot := preload("res://src/core/audio_events.gd")
const ClashFx := preload("res://src/ui/components/clash_fx.gd")

const ADVANCE_TIME := 0.85
const IMPACT_TIME := 0.20
const WAVE_AMP_INTRO := 0.10   # 推进期小波（背景纹理让方格颗粒可见，被 pulse 主导）
const WAVE_AMP_TARGET := 0.18  # 撞击后稳态振幅

const Y_DRIFT_SPEED := 1.2     # 波纹纵向漂浮速度（与推进相位解耦）
const BASE_PHASE_SPEED := 0.45 # 僵持期两侧波相位推进速度
const CHARGE_PHASE_SPEED := 2.4 # 盖过期胜方加速冲锋的相位速度
const LOSER_PHASE_SPEED := 0.18 # 盖过期败方被压制（波变疏弱）
const SHAKE_DECAY := 0.05       # shake 幅度衰减速度（UV/秒）
const SHAKE_HIT := 0.0045       # 连击每击的轻微 shake
const SHAKE_BURST := 0.016      # 崩溃决堤的强 shake
const SHAKE_IMPACT := 0.014     # 初次对撞的强 shake（≈崩溃，略弱让结局更猛）
const RIPPLE_TIME := 1.2        # 初次对撞涟漪向外荡开的时长（放慢 → 看清格子逐列步进）

@onready var _wave: ColorRect = $Wave

var _mat: ShaderMaterial
var _t := 0.0
var _wave_t := 0.0             # 波纹纵向漂浮相位
var _phase_l := 0.0            # 蓝侧波累积相位
var _phase_r := 0.25           # 红侧波累积相位（初始偏移 → 左右不同步）
var _speed_l := BASE_PHASE_SPEED
var _speed_r := BASE_PHASE_SPEED
var _shake_amt := 0.0          # 当前 shake 幅度（_process 每帧衰减）
var _clash_cur := 0.5          # clash_pos 当前值（撞点特效层每帧要读）
var _phase := "advance"
var _title: TitleLogo
var _fx: ClashFx


func _ready() -> void:
	AudioEventsBoot.ensure_buses()   # 建 Music/SFX 总线（音频事件骨架）——须在音量应用前
	GameSettings.load_and_apply()   # 应用持久化设置（窗口模式 / 音量 / 界面主色翻转）
	PixelGlyphs.preheat()   # icon/王冠预热：缓存全量生成 + 字形可渲染冒烟检查
	_mat = _wave.material as ShaderMaterial
	_update_aspect()
	get_viewport().size_changed.connect(_update_aspect)
	_fx = ClashFx.new()   # 撞点火花/电弧层：Wave 之上、标题之下
	add_child(_fx)
	_build_labels()
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
	_mat.set_shader_parameter("ripple", 0.0)
	_mat.set_shader_parameter("shake", Vector2.ZERO)
	_run_intro()


func _update_aspect() -> void:
	var s := get_viewport_rect().size
	if s.y > 0.0:
		_mat.set_shader_parameter("aspect", s.x / s.y)


func _build_labels() -> void:
	# 标题 logo「波波攒」+ 副标题「点击进入游戏」：撞击瞬间逐字入场（演出见 title_logo.gd）。
	# 旧底部"点击屏幕进入游戏"提示已并入标题组件作副标题（2026-06-10）。
	_title = TitleLogo.new()
	_title.impact_shake.connect(_on_title_shake)
	add_child(_title)


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

	# ── 2) 撞击：脉冲消散 + center 起 + 小波起 + 轻 shake ─────
	#   （涟漪 + intensity 轻闪均暂去除——对比观感中；机制保留，可随时加回。）
	_phase = "impact"
	_shake_amt = SHAKE_IMPACT       # 初次对撞 shake（_process 内自然衰减）
	_title.play_entrance()          # 撞击瞬间 → 标题逐字入场
	_fx.set_active(true)            # 撞点演出开启：僵持自然迸溅 + 偶发电弧
	_fx.burst(14, 0.0, 1.2)         # 初撞对称迸溅一股
	var tw_i := create_tween().set_parallel(true)
	tw_i.tween_method(_set_pulse_amp, 1.0, 0.0, IMPACT_TIME)
	tw_i.tween_method(_set_center, 0.0, 1.0, IMPACT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_i.tween_method(_set_wave_amp, WAVE_AMP_INTRO, WAVE_AMP_TARGET, IMPACT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_i.finished

	# ── 3) 僵持：_process 接管 ─────
	_phase = "ready"


func _process(delta: float) -> void:
	_t += delta
	# 波相位全程推进（不依赖 _phase）→ 撞击后 wave_amp>0 时立刻有运动中的波
	_wave_t += delta * Y_DRIFT_SPEED
	_phase_l += delta * _speed_l
	_phase_r += delta * _speed_r
	_mat.set_shader_parameter("wave_time", _wave_t)
	_mat.set_shader_parameter("phase_l", _phase_l)
	_mat.set_shader_parameter("phase_r", _phase_r)
	_fx.set_seam(_clash_cur * get_viewport_rect().size.x)   # 火花/电弧跟随撞点
	# 受击 shake：随机抖动 UV，按 SHAKE_DECAY 衰减归零
	if _shake_amt > 0.0:
		_shake_amt = max(0.0, _shake_amt - delta * SHAKE_DECAY)
		if _shake_amt <= 0.0:
			_mat.set_shader_parameter("shake", Vector2.ZERO)
		else:
			var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amt
			_mat.set_shader_parameter("shake", off)
	if _phase == "ready":
		_struggle()
		# 中央白柱微脉动 1.0-1.20 → 中心微上调一档；clamp 后不爆白
		var c := 1.10 + sin(_t * 3.2) * 0.10
		_mat.set_shader_parameter("center_amp", c)


## 僵持期：边界小幅游走（双频率，互不相让的"角力"感）。
func _struggle() -> void:
	var pos := 0.5 + sin(_t * 1.3) * 0.022 + sin(_t * 2.9 + 1.0) * 0.010
	_mat.set_shader_parameter("clash_pos", pos)


func _input(event: InputEvent) -> void:
	# 标题完全落定（副标题就位）后才接受点击——避免"能点但提示还没浮出来"的窗口
	if _phase != "ready" or not _title.is_settled():
		return
	# 仅鼠标左键触发（键盘/触摸/其余键一律不响应）
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_trigger_sweep()


## 点击 → 连击盖过（C 型）：胜方波加速 → 4 击震颤蓄力 → 第 5 下崩溃爆发。
func _trigger_sweep() -> void:
	_phase = "sweeping"
	var blue_wins := randf() < 0.5
	BootResult.set_winner(blue_wins)  # 记下原始随机胜方 → effective_blue_wins() 再叠加界面主色翻转
	# ⚠ 决堤实际"盖屏色"必须用 effective（含界面主色翻转开关），否则翻转开时
	#    boot 决堤是蓝、菜单/BP/过场幕却走红——胜方色与背景色对不上（2026-06-27 修复）。
	#    show_blue 既驱动 clash 朝哪侧崩溃决堤，也决定盖屏色（蓝填左/红填右），
	#    与 wave_flow_bg / TransitionManager 同读 effective → 全链路同色。
	var show_blue := BootResult.effective_blue_wins()
	# 胜方加速冲锋，败方被压制（波变疏弱）
	if show_blue:
		_speed_l = CHARGE_PHASE_SPEED
		_speed_r = LOSER_PHASE_SPEED
	else:
		_speed_r = CHARGE_PHASE_SPEED
		_speed_l = LOSER_PHASE_SPEED
	# 标题退场延后到决堤瞬间（_run_combo 内）——连击期间标题留场随每击被震推
	_run_combo(show_blue)


## 连击序列：4 击猛攻（中线阻尼震颤 + 每击局部闪/轻 shake 蓄力）→ 第 5 下崩溃决堤。
func _run_combo(blue_wins: bool) -> void:
	# 4 击蓄力：中线 clash_pos 围绕中央(0.5)做阻尼震颤（被撞后来回摆动、幅度衰减，丝滑），
	# 配合胜方波加速冲锋 + 每击 hit_flash 局部闪 + 轻微 shake 体现"一道道猛攻"；
	# 张力累积到第 5 下才崩溃决堤。
	var strikes := 3
	var dir := 1.0 if blue_wins else -1.0
	for i in strikes:
		var dur := 0.13 - i * 0.018   # 每击的持续（越往后越快）
		var kick := 0.024 + i * 0.005  # 震幅随击数略增（越撞越猛）
		_set_hit(1.0)
		_shake_amt = SHAKE_HIT         # 每击轻微 shake
		_title.combo_hit(dir)          # 标题随每击被朝胜方方向震推
		_fx.burst(10, dir, 1.5)        # 每击一股火花砸向败方侧
		_fx.fire_arc()                 # 击点电弧闪现
		var tw := create_tween()
		tw.tween_method(_set_hit, 1.0, 0.0, dur + 0.06)
		# 中线受击震颤：阻尼正弦来回摆动并衰减（丝滑，无急停转折）
		var kt := create_tween()
		kt.tween_method(_apply_kick.bind(dir, kick), 0.0, 1.0, dur * 2.2)
		await tw.finished
		# 蓄力顿挫（越往后越短）；此期 _process 仍在涌波，非死帧
		var pause := 0.13 - i * 0.022
		await get_tree().create_timer(pause).timeout

	# ── 第 5 下：崩溃决堤——中线从中央一鼓作气冲到底盖过 ─────
	_title.play_exit(blue_wins)   # 决堤瞬间标题才被波冲走（与盖屏同步，0.34s 内可见）
	var target := 1.0 if blue_wins else 0.0
	var cur2 := _mat.get_shader_parameter("clash_pos") as float
	_set_hit(1.0)
	_shake_amt = SHAKE_BURST          # 崩溃强 shake（随 _process 自然衰减）
	_fx.burst(26, dir, 2.2)           # 决堤大迸发（随 seam 冲锋一路拖尾）
	var bt := create_tween().set_parallel(true)
	bt.tween_method(_set_clash, cur2, target, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bt.tween_method(_set_hit, 1.0, 0.0, 0.16)
	# 全屏光爆发：burst 0→1.3 驱动中央光晕扩展到全屏再自然衰落（shader 内 glow，取代旧白闪）
	bt.tween_method(_set_burst, 0.0, 1.3, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 盖屏即交棒：clash 冲到底的瞬间（0.34s）立刻让全局波幕接管，不等 burst 收尾
	# （旧版 await bt.finished 多卡 0.16s 死等才切场景——Eddy 反馈间隔过长）。
	# burst 余晖与波幕同色同向无缝衔接；boot 释放时残余 tween 随节点一并销毁。
	await get_tree().create_timer(0.34).timeout
	# 决堤已把整屏洗成胜方色波 → 切菜单 → 胜方波朝自己的推进方向整体排走，
	# 亲手揭开菜单（与 menu→bp→battle 同一套转场语言）。
	_phase = "done"
	TransitionManager.reveal_into(NEXT_SCENE, 0.5)


## 标题动画请求屏幕 shake（王落地等）→ 并入现有 shake 衰减循环。
func _on_title_shake(strength: float) -> void:
	_shake_amt = maxf(_shake_amt, strength)


## 受击震颤：u(0→1) 驱动阻尼正弦，中线围绕中央 0.5 来回摆动并衰减（丝滑）。
func _apply_kick(u: float, dir: float, amp: float) -> void:
	var osc := sin(u * PI * 2.6) * exp(-u * 3.0)
	_set_clash(0.5 + dir * amp * osc)


# ── shader 参数 setter ────────────────────────────────────────
func _set_clash(v: float) -> void:
	_clash_cur = v
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

func _set_ripple(v: float) -> void:
	_mat.set_shader_parameter("ripple", v)

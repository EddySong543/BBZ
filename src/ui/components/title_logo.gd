class_name TitleLogo
extends Control

## 「波波攒」标题 logo —— Ark Pixel 12px 字体 + 逐字入场动画，boot_screen 撞击瞬间触发。
##
## 字体：Ark Pixel 12px ×14 整数倍 = 168px/字，描边 14px=1 字体像素（全 UI 统一 12px 基底·整数倍保像素硬边）。
##
## 配色（2026-06-11 1A「与王冠同金」）：3 字统一王冠同源金——字身平涂主金 + 笔画上/下缘结构棱线
## （canvas_ui_title_glyph shader）+ 1 字体像素纯黑描边 + 下落投影。⚠ 字色全程恒定，动画绝不改色。
##
## 入场（2026-06-18 重编排 v2·撞击瞬间触发）——单一节奏线，三字各按本义出场、不强行因果：
##   ① 对波冲入：波₁从左 / 波₂从右 BACK 过冲冲入，过冲最近点 = 相撞。
##      相撞只补一道竖直接缝白闪（两浪相拍的压缩感），**不单独震屏 / 不迸火花**——
##      骑在背景撞击那一下上（boot 的 SHAKE_IMPACT 即此刻的相撞震），消除"标题与背景各撞一次"的糊。
##   ② 「攒」积聚：金色像素方块自「攒」**四周向字心攒聚**（攒=积聚之本义）。
##      ⚠ 与两波相撞**无因果**——v1 让"相撞甩出碎块喂攒"被否（撞击产生攒不合逻辑）；攒自行积聚成形。
##   ③ 「攒」成形（唯一高潮）：方块抵达即与「攒」交叉淡入（方块"变成"字，非硬切）+ 小幅落定收重
##      （纯像素位移·不缩放免糊）+ 字身金闪 + 全片唯一一次大震屏。**无外扩光环**（向外发散与"积聚"相悖）。
##   ④ 收尾扫光：「攒」成形后，一道斜向亮带自左掠到右、依次扫过「波波攒」字身（glyph shader `sweep` 参数·`_anim_sweep`）。
##   ⑤ 副标题「点击进入游戏」：「攒」落定后逐字轻巧上浮淡入。
## 待机：双层漂浮（字间快波浪 BOB·波峰从「波」传向「攒」再过副标题 + 整体慢涌 SLOW）+ 偶发「攒」金粒上浮。
##   = 原版漂浮，仅去掉「两波之间的小火花」（相撞为一次性事件，待机不迸火花）。
## 连击期：每击朝胜方方向震推 + 三字快闪一拍（combo_hit）。
## 退场：play_exit(blue_wins) 随胜方波推进方向逐字推走淡出（含副标题）。

signal impact_shake(strength: float)

const CHARS: Array[String] = ["波", "波", "攒"]
const SUB_CHARS: Array[String] = ["点", "击", "进", "入", "游", "戏"]
const FONT_PATH := "res://assets/font/ark-pixel-12px-proportional-zh_cn.ttf"
const FONT_SCALE := 14                             # 12px 基底 ×14 = 1 字体像素占 14 屏幕像素
const CHAR_PX := 168                               # = 12 × FONT_SCALE
const OUTLINE_PX := 14                             # 恰好 1 个字体像素的黑描边（= FONT_SCALE）
const CHAR_GAP := 16

const SUB_PX := 36                                 # 副标题 12px 基底 ×3
const SUB_SCALE := 3
const SUB_OUTLINE_PX := 3                          # 1 个字体像素
const SUB_GAP := 4
const SUB_TOP_GAP := 30                            # 副标题与标题底部的间距

const GLYPH_SHADER := preload("res://assets/shaders/canvas_ui_title_glyph.gdshader")
const COLOR_FRAG := Color("#f4c84b")               # 攒聚碎块 = 标题金（渐变中间档）
const COLOR_RING := Color("#ffe08a")               # 蓄力光波 = 亮金（王冠高光/浪尖同源）
const SPARK_WHITE := Color("#f2f7ff")              # 相撞接缝白闪（白热压缩）
const SHADOW_COLOR := Color(0.02, 0.03, 0.06, 0.55)
const SHADOW_OFFSET := 14                          # 投影下落 1 字体像素（= FONT_SCALE）

# ── 待机（= 原版双层漂浮，仅去掉「两波之间小火花」）──
const BOB_AMP_PX := 1                              # 待机起伏振幅（字体像素，按 FONT_SCALE 整步进）
const BOB_SPEED := 2.4                             # = 背景波纵向漂浮 ×2，整数比 → 标题"浮在波上"
const BOB_PHASE_STEP := 0.55                       # 错相 → 波浪从左往右穿过标题
const SLOW_SPEED := 0.8                            # 整体慢涌频率

# ── 入场时间轴（秒，从撞击瞬间起算）──
# 节奏线：对波冲入·相撞（与背景同一下）→ 「攒」自四周积聚成形（与相撞无因果）
#   → 「攒」交叉淡入收定 = 唯一高潮（全片仅此一次大震屏）→ 副标题上浮。
const BO_FROM := 560.0                             # 两波冲入起点离落位的横向距离
const BO_DUR := 0.18                               # 波冲入（BACK 过冲 → 相撞 → 收定）
const CLASH_T := 0.13                              # 两波过冲最近点（相撞）→ 接缝白闪（无独立震屏·骑背景那一下）
const ZAN_GATHER_T := 0.18                         # 相撞甩出的碎块自接缝起、向「攒」字心流去
const ZAN_FLY_DUR := 0.22                          # 碎块流到字心时长（抵达即与「攒」交叉淡入）
const ZAN_SLAM := Vector2(0, -10.0)                # 「攒」成形从上方小幅落入收定（纯像素位移·不缩放免糊）
const ZAN_SLAM_DUR := 0.18                         # 「攒」落入收定时长
const SUB_DELAY := 0.48                            # 副标题起浮（「攒」成形后）
const SETTLE_T := 1.00                             # 入场完全落定（开始接受点击）
const SHAKE_ZAN_LAND := 0.016                      # 「攒」成形震屏——全片唯一大震（相撞不再单独震）
const SWEEP_AFTER := 0.15                          # 「攒」成形后多久开始收尾扫光
const SWEEP_DUR := 0.45                            # 扫光自左掠到右的时长（结束 ≈ SETTLE_T）

var _chars: Array[Label] = []
var _subs: Array[Label] = []
var _base_pos: Array[Vector2] = []                 # 主标题各字落定位置
var _sub_base: Array[Vector2] = []                 # 副标题各字落定位置
var _widths: Array[float] = []                     # 主标题各字宽度
var _ch_h := 0.0                                   # 字面高度
var _title_center := Vector2.ZERO                  # 整行标题中心（蓄力光波圆心）
var _entrance_done := false
var _exiting := false
var _t := 0.0
var _mote_next := 2.5                              # 下一次能量微粒的 _t 时刻


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var font := load(FONT_PATH) as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	# 先建 Label 测量各字宽度 → 整体居中排版（屏幕正中央）
	var total := 0.0
	for i in CHARS.size():
		var lb := _make_glyph_label(CHARS[i], font, CHAR_PX, OUTLINE_PX, SHADOW_OFFSET)
		_chars.append(lb)
		# 首帧前 Label.get_minimum_size() 未反映字体覆写 → 直接用字体量宽
		var w := font.get_string_size(CHARS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, CHAR_PX).x
		_widths.append(w)
		total += w
	total += CHAR_GAP * (CHARS.size() - 1)

	var vp := get_viewport_rect().size
	_ch_h = font.get_height(CHAR_PX)
	var title_top := roundf((vp.y - _ch_h) * 0.5)
	var x := roundf((vp.x - total) * 0.5)
	for i in _chars.size():
		_chars[i].position = Vector2(x, title_top)
		_base_pos.append(_chars[i].position)
		x += _widths[i] + CHAR_GAP
	var last_i := _chars.size() - 1
	_title_center = Vector2(
		(_base_pos[0].x + _base_pos[last_i].x + _widths[last_i]) * 0.5,
		title_top + _ch_h * 0.5)

	# 扫光：把每字左/右缘映射到「标题整行」归一化 x（0=行左,1=行右），供 glyph shader 扫光带跨字连续掠过
	var row_left := _base_pos[0].x
	var row_w := (_base_pos[last_i].x + _widths[last_i]) - row_left
	for i in _chars.size():
		var gmat := _chars[i].material as ShaderMaterial
		gmat.set_shader_parameter("glyph_u0", (_base_pos[i].x - row_left) / row_w)
		gmat.set_shader_parameter("glyph_u1", (_base_pos[i].x + _widths[i] - row_left) / row_w)

	# 副标题「点击进入游戏」：同款样式缩小档，居中于标题下方
	var sub_widths: Array[float] = []
	var sub_total := 0.0
	for i in SUB_CHARS.size():
		var lb := _make_glyph_label(SUB_CHARS[i], font, SUB_PX, SUB_OUTLINE_PX, SUB_SCALE)
		_subs.append(lb)
		var w := font.get_string_size(SUB_CHARS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_PX).x
		sub_widths.append(w)
		sub_total += w
	sub_total += SUB_GAP * (SUB_CHARS.size() - 1)
	var sub_y := roundf(title_top + _ch_h + SUB_TOP_GAP)
	var sx := roundf((vp.x - sub_total) * 0.5)
	for i in _subs.size():
		_subs[i].position = Vector2(sx, sub_y)
		_sub_base.append(_subs[i].position)
		sx += sub_widths[i] + SUB_GAP


## 标题字 Label 工厂：白字身（渐变 shader 着色）+ 黑描边 + 下落投影，初始透明。
func _make_glyph_label(ch: String, font: FontFile, px: int,
		outline: int, shadow_off: int) -> Label:
	var lb := Label.new()
	lb.text = ch
	lb.add_theme_font_override("font", font)
	lb.add_theme_font_size_override("font_size", px)
	# 字身纯白 → 色阶 shader 相乘后显出金；描边/投影保持深色
	lb.add_theme_color_override("font_color", Color.WHITE)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	lb.add_theme_constant_override("outline_size", outline)
	lb.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	lb.add_theme_constant_override("shadow_offset_x", 0)
	lb.add_theme_constant_override("shadow_offset_y", shadow_off)
	var mat := ShaderMaterial.new()
	mat.shader = GLYPH_SHADER
	mat.set_shader_parameter("glyph_height", font.get_height(px))
	mat.set_shader_parameter("px_size", float(px) / 12.0)   # 1 字体像素的屏幕尺寸（棱线粒度）
	lb.material = mat
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.modulate.a = 0.0
	add_child(lb)
	return lb


## 入场总谱（boot 撞击瞬间调用）：对波冲入·相撞 → 喂「攒」 → 「攒」交叉淡入收定（唯一高潮）。
func play_entrance() -> void:
	_anim_bo(_chars[0], -BO_FROM)        # 波₁ 从左冲入
	_anim_bo(_chars[1], BO_FROM)         # 波₂ 从右冲入
	_anim_clash()                        # 两波过冲最近点：接缝白闪（骑背景相撞那一下，不单独震）
	_anim_zan(_chars[2])                 # 攒：四周方块积聚 → 交叉淡入收定 + 金闪 + 震屏（无外扩光环）
	_anim_sweep()                        # 收尾：攒成形后一道光自左掠到右扫过字身
	_anim_subtitle()                     # 副标题：攒落定后逐字上浮淡入
	get_tree().create_timer(SETTLE_T).timeout.connect(func() -> void:
		if not _exiting:
			_entrance_done = true)


## 波：横向冲入 + BACK 回弹过冲（浪头拍上岸的劲；两波过冲最近点 = 相撞）。
func _anim_bo(lb: Label, from_dx: float) -> void:
	var target := lb.position
	lb.position = target + Vector2(from_dx, 0)
	lb.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(lb, "position", target, BO_DUR) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 两波过冲最近点（相撞）只补一道竖直接缝白闪——两浪相拍的压缩感。
## ⚠ 不迸火花、不单独震屏：骑在背景撞击那一下上（boot 的 SHAKE_IMPACT），消除"双撞糊"。
func _anim_clash() -> void:
	var ct := create_tween()
	ct.tween_interval(CLASH_T)
	ct.tween_callback(_spawn_seam_flash)


## 波₁波₂之间的相撞点（接缝），= 一次性入场特效起点。
func _wave_meet_point() -> Vector2:
	var x := (_chars[0].position.x + _widths[0] + _chars[1].position.x) * 0.5
	var y := (_chars[0].position.y + _chars[1].position.y) * 0.5 + _ch_h * 0.5
	return Vector2(x, y)


## 接缝白闪：相撞瞬间一道竖直白色压缩光，快速横向铺开并淡灭（两浪相拍的劲，克制·不刷火花）。
func _spawn_seam_flash() -> void:
	var pos := _wave_meet_point()
	var bar := ColorRect.new()
	bar.color = SPARK_WHITE
	bar.size = Vector2(FONT_SCALE * 1.5, _ch_h * 0.9)
	bar.pivot_offset = bar.size * 0.5
	bar.position = pos - bar.size * 0.5
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var tw := create_tween()
	tw.tween_property(bar, "modulate:a", 0.0, 0.14).from(0.85)
	tw.parallel().tween_property(bar, "scale", Vector2(2.2, 1.0), 0.14).from(Vector2(0.4, 1.0))
	tw.tween_callback(bar.queue_free)


## 攒（积聚→唯一高潮）：金块自四周攒聚字心 → 抵达即与「攒」交叉淡入收定（与相撞无因果）。
func _anim_zan(lb: Label) -> void:
	var center := _base_pos[2] + Vector2(_widths[2], _ch_h) * 0.5
	var tw := create_tween()
	tw.tween_interval(ZAN_GATHER_T)
	tw.tween_callback(func() -> void: _spawn_zan_gather(center))
	tw.tween_interval(ZAN_FLY_DUR)
	tw.tween_callback(func() -> void: _form_zan(lb))


## 「攒」积聚（攒=积聚之本义）：金色像素方块自「攒」四周（360°环绕·非接缝）向字心攒聚；
## 抵达瞬间淡出 → 与「攒」淡入交叉，方块"变成"字（修掉旧版"聚拢后硬切贴字"的断裂）。
## ⚠ 起点是「攒」自身四周、不是相撞接缝——攒按本义自行积聚、与两波相撞无因果（v1 因果被否）。
## 一次性入场特效，非热路径，允许临时分配。
func _spawn_zan_gather(center: Vector2) -> void:
	for i in 16:
		var frag := ColorRect.new()
		frag.color = COLOR_FRAG if randf() < 0.7 else COLOR_RING
		var s := float(FONT_SCALE * (2 if randf() < 0.5 else 3))
		frag.size = Vector2(s, s)
		# 四周环绕散布起步（360°·攒之本义），加速向字心攒聚（EASE_IN = 越聚越快、像被积拢）
		var ang := randf() * TAU
		var dist := randf_range(180.0, 300.0)
		frag.position = center + Vector2(cos(ang), sin(ang)) * dist - frag.size * 0.5
		frag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frag)
		var delay := randf_range(0.0, 0.08)
		var fly := maxf(ZAN_FLY_DUR - delay, 0.08)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(frag, "position", center - frag.size * 0.5, fly) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# 抵达即淡出（与「攒」交叉淡入同窗）
		var ftw := create_tween()
		ftw.tween_interval(maxf(ZAN_FLY_DUR - 0.06, 0.0))
		ftw.tween_property(frag, "modulate:a", 0.0, 0.06).from(1.0)
		ftw.tween_callback(frag.queue_free)


## 「攒」成形收定（唯一高潮）：交叉淡入（非硬切）+ 从上方小幅落定（纯像素位移·不缩放免糊）
## + 字身金闪（积聚之力锁入字内）+ 全片唯一一次大震屏。
## ⚠ 去掉旧版外扩光环——向外发散与"积聚"相悖（不协调）；冲击交给金闪 + 震屏 + 积聚本身。
func _form_zan(lb: Label) -> void:
	var target := lb.position
	lb.position = target + ZAN_SLAM
	var tw := create_tween()
	tw.tween_property(lb, "modulate:a", 1.0, 0.06).from(0.0)
	tw.parallel().tween_property(lb, "position", target, ZAN_SLAM_DUR) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash(lb, 0.24)
	impact_shake.emit(SHAKE_ZAN_LAND)


## 收尾扫光：「攒」成形后一道斜向亮带自左掠到右、依次扫过「波波攒」字身（glyph shader sweep 参数）。
## 标题整行归一化（每字 glyph_u0/u1 在 _build 设好），故亮带跨字连续掠过、不在字间断。掠完关闭。
func _anim_sweep() -> void:
	var begin := ZAN_GATHER_T + ZAN_FLY_DUR + SWEEP_AFTER
	var tw := create_tween()
	tw.tween_interval(begin)
	tw.tween_method(_set_sweep, -0.2, 1.2, SWEEP_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: _set_sweep(-1.0))   # 掠完关闭（回到零影响态）


func _set_sweep(v: float) -> void:
	for lb in _chars:
		(lb.material as ShaderMaterial).set_shader_parameter("sweep", v)


## 副标题：攒字落定后逐字轻巧上浮淡入，左→右小错峰呼应波浪方向。
func _anim_subtitle() -> void:
	for j in _subs.size():
		var lb := _subs[j]
		var target := lb.position
		lb.position = target + Vector2(0, 18)
		var tw := create_tween()
		tw.tween_interval(SUB_DELAY + j * 0.03)
		tw.tween_callback(func() -> void: lb.modulate.a = 1.0)
		tw.tween_property(lb, "position", target, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 字身短暂打白再回落渐变本色（shader flash 参数，黑描边/投影不受影响）。
func _flash(lb: Label, dur: float) -> void:
	var mat := lb.material as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(u: float) -> void:
		mat.set_shader_parameter("flash", u),
		1.0, 0.0, dur)


## 入场是否完全落定（boot 用于门控"点击进入"——副标题就位后才接受点击）。
func is_settled() -> bool:
	return _entrance_done


## 连击受击：每次猛攻把整个标题朝胜方推进方向猛推一下又弹回，同时三字快闪一拍。
func combo_hit(dir: float) -> void:
	if _exiting:
		return
	for tr in _all_elements():
		var ox := tr.position.x
		var tw := create_tween()
		tw.tween_property(tr, "position:x", ox + dir * 10.0, 0.05) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(tr, "position:x", ox, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for lb in _chars:
		_flash(lb, 0.12)


## 「攒」字呼出 1-2 粒金色能量微粒，缓缓上飘消散（呼应核心动作"攒"；克制：≥4s 一次）。
func _spawn_zan_mote() -> void:
	var zan := _chars[2]
	for i in randi_range(1, 2):
		var mote := ColorRect.new()
		mote.color = COLOR_RING
		mote.size = Vector2(FONT_SCALE, FONT_SCALE)   # 1 个字体像素
		mote.position = zan.position + Vector2(
			randf_range(20.0, zan.size.x - 20.0), randf_range(10.0, 60.0))
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mote)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(mote, "position:y",
			mote.position.y - randf_range(40.0, 64.0), 1.2)
		tw.tween_property(mote, "modulate:a", 0.0, 1.2).from(0.9) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mote.queue_free)


func _all_elements() -> Array[Control]:
	var all: Array[Control] = []
	for lb in _chars:
		all.append(lb)
	for lb in _subs:
		all.append(lb)
	return all


## 退场：随胜方波推进方向逐字推走淡出（蓝胜向右排走，红胜向左）。
func play_exit(blue_wins: bool) -> void:
	_exiting = true
	_entrance_done = false
	var dir := 1.0 if blue_wins else -1.0
	var last_rank := float(_chars.size() - 1)
	var items: Array = []
	for i in _chars.size():
		items.append([_chars[i], float(i)])
	for j in _subs.size():
		items.append([_subs[j], j * last_rank / (_subs.size() - 1)])
	for item_v in items:
		var item: Array = item_v
		var tr := item[0] as Control
		var rank := item[1] as float
		var order := rank if blue_wins else (last_rank - rank)
		var tw := create_tween()
		tw.tween_interval(order * 0.04)
		tw.tween_property(tr, "position:x", tr.position.x + dir * 200.0, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(tr, "modulate:a", 0.0, 0.22)


## 调试辅助（tools/title_preview.gd 居中测量用）：标题整行字身区域。
func get_title_rect() -> Rect2:
	var last := _chars[_chars.size() - 1]
	var left := _chars[0].position.x - 4.0
	var right := last.position.x + last.size.x + 4.0
	var top := _chars[0].position.y
	var bottom := _chars[0].position.y + _chars[0].size.y
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _process(delta: float) -> void:
	if not _entrance_done:
		return
	_t += delta
	# 双层漂浮（= 原版）：①字间快波浪（BOB_SPEED 错相，波峰从「波」传向「攒」再传过副标题）
	# ②整体慢涌（SLOW_SPEED 全员同相）——快慢两频叠加才像浮在水面
	var slow := roundi(sin(_t * SLOW_SPEED) * 3.0) * 2
	for i in _chars.size():
		var off := roundi(sin(_t * BOB_SPEED - i * BOB_PHASE_STEP) * BOB_AMP_PX) \
			* FONT_SCALE + slow
		_chars[i].position.y = _base_pos[i].y + off
	for j in _subs.size():
		var off_s := roundi(sin(_t * BOB_SPEED - (CHARS.size() + j) * BOB_PHASE_STEP) \
			* BOB_AMP_PX) * SUB_SCALE + slow
		_subs[j].position.y = _sub_base[j].y + off_s
	# 攒字能量微粒（随机间隔，克制频率）
	if _t >= _mote_next:
		_mote_next = _t + randf_range(3.2, 5.0)
		_spawn_zan_mote()

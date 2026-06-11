class_name TitleLogo
extends Control

## 「波波攒之王」标题 logo —— Fusion Pixel 10px 字体 + 逐字入场动画，boot_screen 撞击瞬间触发。
##
## 字体：Ark Pixel 12px ×10 整数倍 = 120px/字，描边 10px=1 字体像素（2026-06-10 Eddy 选定全 UI 统一 12px）。
## （手工方格字形保留在 pixel_glyphs.gd —— 王冠仍用其像素稿；Fusion 10px 也在 assets/font/ 可随时换回对比。）
##
## 配色（2026-06-10 Eddy 决议·弃逐字多彩）：5 字统一金色系——字身纵向渐变（亮金→深琥珀，
## canvas_ui_title_glyph shader）+ 1 字体像素黑描边 + 下落投影；王冠金底红宝石。
##
## 入场（撞击瞬间，前 3 字同时开演）：
##   波₁：从左冲入带回弹 —— 对撞的左侧波本体
##   波₂：从右冲入带回弹 —— 对撞的右侧波本体
##   攒：像素方块从四周攒聚成字 —— "攒"=积聚，游戏核心动作
##   之王+王冠：绑定为一组，压轴从天砸落，落地震屏闪金 —— 王者加冕
## 副标题「点击进入游戏」：与标题同款金渐变/描边/投影（缩小档），居中于标题下方；
## 王落地后逐字上浮淡入，待机与标题共用同一道波浪（相位接在王之后继续传）。
## 待机（双层漂浮 + 点缀）：①字间快波浪（波峰从「波」传向「王」再传过副标题）
## ②整体慢涌（全员同相低频）③定期白光掠过王冠（仅王冠，字身不扫）④攒字能量微粒。
## 连击期：每击被朝胜方方向震推 + 同向白光快扫王冠（combo_hit）。
## 退场：play_exit(blue_wins) 随胜方波推进方向逐字推走淡出（含副标题/王冠）。

signal impact_shake(strength: float)

const CHARS: Array[String] = ["波", "波", "攒", "之", "王"]
const SUB_CHARS: Array[String] = ["点", "击", "进", "入", "游", "戏"]
const FONT_PATH := "res://assets/font/ark-pixel-12px-proportional-zh_cn.ttf"
const FONT_SCALE := 10                             # 12px 基底 ×10 = 1 字体像素占 10 屏幕像素
const CHAR_PX := 120
const OUTLINE_PX := 10                             # 恰好 1 个字体像素的黑描边
const CHAR_GAP := 12
const CROWN_SCALE := 4                             # 王冠像素稿（PixelGlyphs）的放大倍数
const CROWN_OVERLAP := 24                          # 王冠底部压入字格顶部的深度
const CROWN_X_NUDGE := -5.0                        # 王字形在字宽内左右留白不对称 → 实测(title_preview)左修 5px

const SUB_PX := 36                                 # 副标题 12px 基底 ×3
const SUB_SCALE := 3
const SUB_OUTLINE_PX := 3                          # 1 个字体像素
const SUB_GAP := 4
const SUB_TOP_GAP := 24                            # 副标题与标题底部的间距

const GLYPH_SHADER := preload("res://assets/shaders/canvas_ui_title_glyph.gdshader")
const CROWN_SHADER := preload("res://assets/shaders/canvas_ui_title_crown.gdshader")
const COLOR_FRAG := Color("#f4c84b")               # 攒聚方块 = 标题金（渐变中间档）
const SHADOW_COLOR := Color(0.02, 0.03, 0.06, 0.55)
const SHADOW_OFFSET := 10                          # 投影下落 1 字体像素

const BOB_AMP_PX := 1                              # 待机起伏振幅（字体像素，按 FONT_SCALE 整步进）
const BOB_SPEED := 2.4                             # = 背景波纵向漂浮 Y_DRIFT_SPEED(1.2)×2，整数比 → 标题"浮在波上"
const BOB_PHASE_STEP := 0.55                       # 错相 → 波浪从左往右穿过标题
const SLOW_SPEED := 0.8                            # 整体慢涌频率（与字间快波浪叠成双层漂浮）
const SHEEN_INTERVAL := 4.5                        # 待机掠光间隔（替代旧的王字单独闪金）
const SHAKE_KING_LAND := 0.012

const DROP_DELAY := 0.50                           # 之王组在前 3 字之后压轴砸落

var _chars: Array[Label] = []
var _subs: Array[Label] = []
var _crown: TextureRect
var _base_pos: Array[Vector2] = []                 # 主标题各字落定位置（含王冠，下标 5）
var _sub_base: Array[Vector2] = []                 # 副标题各字落定位置
var _drop_span := Rect2()                          # 「之王」落点区域（砸落预备阴影用）
var _mats: Array[ShaderMaterial] = []              # 全部字身+王冠材质（扫光统一驱动）
var _entrance_done := false
var _exiting := false
var _t := 0.0
var _sheen_t := 3.0                                # 预热：落定后约 1.5s 迎来第一道掠光
var _mote_next := 2.5                              # 下一次能量微粒的 _t 时刻


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var font := load(FONT_PATH) as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	# 先建 Label 测量各字宽度 → 整体居中排版（屏幕正中央）
	var widths: Array[float] = []
	var total := 0.0
	for i in CHARS.size():
		var lb := _make_glyph_label(CHARS[i], font, CHAR_PX, OUTLINE_PX, SHADOW_OFFSET)
		_chars.append(lb)
		# 首帧前 Label.get_minimum_size() 未反映字体覆写 → 直接用字体量宽
		var w := font.get_string_size(CHARS[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, CHAR_PX).x
		widths.append(w)
		total += w
	total += CHAR_GAP * (CHARS.size() - 1)

	var vp := get_viewport_rect().size
	var ch_h := font.get_height(CHAR_PX)
	var x := roundf((vp.x - total) * 0.5)
	for i in _chars.size():
		var lb := _chars[i]
		var pos := Vector2(x, roundf((vp.y - ch_h) * 0.5))
		lb.position = pos
		_base_pos.append(pos)
		x += widths[i] + CHAR_GAP

	# 王冠：居中戴在「王」字正上方，底部略压入字头（仍用手工像素稿）
	var crown_tex := PixelGlyphs.crown_texture()
	_crown = TextureRect.new()
	_crown.texture = crown_tex
	_crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crown.stretch_mode = TextureRect.STRETCH_SCALE
	_crown.size = Vector2(crown_tex.get_size()) * CROWN_SCALE
	_crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crown.modulate.a = 0.0
	var crown_pos := Vector2(
		roundf(_base_pos[4].x + (widths[4] - _crown.size.x) * 0.5 + CROWN_X_NUDGE),
		roundf(_base_pos[4].y - _crown.size.y + CROWN_OVERLAP))
	_crown.position = crown_pos
	add_child(_crown)
	_base_pos.append(crown_pos)
	# 「之王」落点区域：x 跨两字，y 在字底（砸落预备阴影沿此展开）
	_drop_span = Rect2(_base_pos[3].x, (vp.y - ch_h) * 0.5 + ch_h - 14.0,
		_base_pos[4].x + widths[4] - _base_pos[3].x, 12.0)

	# 副标题「点击进入游戏」：同款样式缩小档，居中于标题下方
	var sub_widths: Array[float] = []
	var sub_total := 0.0
	for i in SUB_CHARS.size():
		var lb := _make_glyph_label(SUB_CHARS[i], font, SUB_PX, SUB_OUTLINE_PX, SUB_SCALE)
		_subs.append(lb)
		var w := font.get_string_size(SUB_CHARS[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_PX).x
		sub_widths.append(w)
		sub_total += w
	sub_total += SUB_GAP * (SUB_CHARS.size() - 1)
	var sub_y := roundf((vp.y - ch_h) * 0.5 + ch_h + SUB_TOP_GAP)
	var sx := roundf((vp.x - sub_total) * 0.5)
	for i in _subs.size():
		var pos := Vector2(sx, sub_y)
		_subs[i].position = pos
		_sub_base.append(pos)
		sx += sub_widths[i] + SUB_GAP

	# 扫光只作用于王冠（2026-06-10 Eddy 决议：字身不扫）→ 坐标系 = 王冠自身归一化 x
	var cmat := ShaderMaterial.new()
	cmat.shader = CROWN_SHADER
	cmat.set_shader_parameter("x_offset", 0.0)
	cmat.set_shader_parameter("title_width", _crown.size.x)
	_crown.material = cmat
	_mats.append(cmat)


## 标题字 Label 工厂：白字身（渐变 shader 着色）+ 黑描边 + 下落投影，初始透明。
func _make_glyph_label(ch: String, font: FontFile, px: int,
		outline: int, shadow_off: int) -> Label:
	var lb := Label.new()
	lb.text = ch
	lb.add_theme_font_override("font", font)
	lb.add_theme_font_size_override("font_size", px)
	# 字身纯白 → 色阶 shader 相乘后显出金；描边/投影保持深色
	lb.add_theme_color_override("font_color", Color.WHITE)
	# 描边深褐而非纯黑：金属字轮廓带暖意，纯黑=贴纸感（2026-06-11 反 PPT 艺术字 A）
	lb.add_theme_color_override("font_outline_color", Color("#2a1606", 0.95))
	lb.add_theme_constant_override("outline_size", outline)
	lb.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	lb.add_theme_constant_override("shadow_offset_x", 0)
	lb.add_theme_constant_override("shadow_offset_y", shadow_off)
	var mat := ShaderMaterial.new()
	mat.shader = GLYPH_SHADER
	mat.set_shader_parameter("glyph_height", font.get_height(px))
	mat.set_shader_parameter("px_size", float(px) / 12.0)   # 1 字体像素的屏幕尺寸（抖动/棱线粒度）
	lb.material = mat
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.modulate.a = 0.0
	add_child(lb)
	return lb


## 入场总谱（boot 撞击瞬间调用）：波波攒同时开演 → 之王+王冠绑定压轴砸落。
func play_entrance() -> void:
	_anim_bo(_chars[0], -560.0)            # 波₁ 从左冲入
	_anim_bo(_chars[1], 560.0)             # 波₂ 从右冲入
	_anim_zan(_chars[2])                   # 攒：方块攒聚
	_anim_king_group()                     # 之王+王冠：从天砸落
	_anim_subtitle()                       # 副标题：王落地后逐字上浮淡入
	get_tree().create_timer(1.25).timeout.connect(func() -> void:
		if not _exiting:
			_entrance_done = true)


## 波：横向冲入 + BACK 回弹过冲（浪头拍上岸的劲）。
func _anim_bo(lb: Label, from_dx: float) -> void:
	var target := lb.position
	lb.position = target + Vector2(from_dx, 0)
	lb.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(lb, "position", target, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 攒：像素方块从四周向字心攒聚 → 聚拢瞬间字体白闪现身。
func _anim_zan(lb: Label) -> void:
	var center := lb.position + lb.get_minimum_size() * 0.5
	_spawn_zan_fragments(center)
	var tw := create_tween()
	tw.tween_interval(0.32)   # 等方块飞完
	tw.tween_callback(func() -> void:
		lb.modulate.a = 1.0
		_flash(lb, 0.18))


func _spawn_zan_fragments(center: Vector2) -> void:
	# 一次性入场特效，非热路径——此处允许临时分配。
	# 10 块 ×3 字体像素（原 16×2）：撞击瞬间信息密度高，单块更大才读得出"攒聚"。
	for i in 10:
		var frag := ColorRect.new()
		frag.color = COLOR_FRAG
		frag.size = Vector2(FONT_SCALE * 3, FONT_SCALE * 3)
		frag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ang := randf() * TAU
		var dist := randf_range(160.0, 280.0)
		frag.position = center + Vector2(cos(ang), sin(ang)) * dist - frag.size * 0.5
		add_child(frag)
		var tw := create_tween()
		tw.tween_interval(randf_range(0.0, 0.08))
		tw.tween_property(frag, "position", center - frag.size * 0.5, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(frag.queue_free)


## 之王+王冠：从天加速砸落 → 落地震屏 + 闪光 + 下压回弹（加冕盖章）。
## 预备（Anticipation）：落点阴影暗斑先行变大，把视线引到砸落处；
## 跟随（Follow-through）：王冠比之王晚 0.06s 落定并独立回弹——王先落地、冠才扣上。
func _anim_king_group() -> void:
	_spawn_drop_shadow()
	for tr: Control in [_chars[3], _chars[4]]:
		var target := tr.position
		tr.position = target + Vector2(0, -360)
		var tw := create_tween()
		tw.tween_interval(DROP_DELAY)
		tw.tween_callback(func() -> void: tr.modulate.a = 1.0)
		tw.tween_property(tr, "position", target, 0.20) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		# 落地下压 12px 再弹回（重物盖章的余韵）
		tw.tween_property(tr, "position", target + Vector2(0, 12), 0.05) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(tr, "position", target, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 王冠：晚 0.06s 同轨下落 + 更深的独立回弹
	var crown_target := _crown.position
	_crown.position = crown_target + Vector2(0, -360)
	var ct := create_tween()
	ct.tween_interval(DROP_DELAY + 0.06)
	ct.tween_callback(func() -> void: _crown.modulate.a = 1.0)
	ct.tween_property(_crown, "position", crown_target, 0.20) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	ct.tween_property(_crown, "position", crown_target + Vector2(0, 16), 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ct.tween_property(_crown, "position", crown_target, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 落地瞬间：震屏 + 之白闪 + 王金闪（只挂一次，不随组内每元素重复）
	var fx := create_tween()
	fx.tween_interval(DROP_DELAY + 0.20)
	fx.tween_callback(func() -> void:
		impact_shake.emit(SHAKE_KING_LAND)
		_flash(_chars[3], 0.16)
		_flash(_chars[4], 0.16))


## 砸落预备阴影：落点处暗斑提前 0.15s 出现并随下落逼近变大变实，落地瞬间散去。
func _spawn_drop_shadow() -> void:
	var sh := ColorRect.new()
	sh.color = Color(0, 0, 0, 0.0)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sh)
	var st := create_tween()
	st.tween_interval(DROP_DELAY - 0.15)
	st.tween_method(_grow_drop_shadow.bind(sh), 0.0, 1.0, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	st.tween_property(sh, "color:a", 0.0, 0.10)
	st.tween_callback(sh.queue_free)


func _grow_drop_shadow(u: float, sh: ColorRect) -> void:
	var w := lerpf(_drop_span.size.x * 0.35, _drop_span.size.x, u)
	sh.size = Vector2(w, _drop_span.size.y)
	sh.position = Vector2(
		_drop_span.position.x + (_drop_span.size.x - w) * 0.5, _drop_span.position.y)
	sh.color.a = u * 0.22   # 峰值透明度（2026-06-10 0.38→0.22：Eddy 反馈偏暗）


## 副标题：王落地（加冕收尾）后逐字轻巧上浮淡入，左→右小错峰呼应波浪方向。
func _anim_subtitle() -> void:
	for j in _subs.size():
		var lb := _subs[j]
		var target := lb.position
		lb.position = target + Vector2(0, 15)
		var tw := create_tween()
		tw.tween_interval(DROP_DELAY + 0.32 + j * 0.03)
		tw.tween_callback(func() -> void: lb.modulate.a = 1.0)
		tw.tween_property(lb, "position", target, 0.15) \
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


## 连击受击：每次猛攻把整个标题朝胜方推进方向猛推一下又弹回，
## 同时一道白光顺着推搡方向快扫王冠（boot 连击期逐击调用）。
func combo_hit(dir: float) -> void:
	if _exiting:
		return
	play_sheen(dir, 0.18)
	for tr in _all_elements():
		var ox := tr.position.x
		var tw := create_tween()
		tw.tween_property(tr, "position:x", ox + dir * 10.0, 0.05) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(tr, "position:x", ox, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 白光掠过王冠（连击冲击 / 待机掠光）。dir>0 = 从左向右（与波浪传导同向）。
func play_sheen(dir: float, dur: float = 0.35) -> void:
	var from := -0.15 if dir > 0.0 else 1.15
	var to := 1.15 if dir > 0.0 else -0.15
	var tw := create_tween()
	tw.tween_method(_set_sheen, from, to, dur)
	tw.tween_callback(_set_sheen.bind(-1.0))   # 复位隐藏


func _set_sheen(v: float) -> void:
	for m in _mats:
		m.set_shader_parameter("sheen_pos", v)


## 「攒」字呼出 1-2 粒金色能量微粒，缓缓上飘消散（呼应核心动作"攒"；克制：≥3.2s 一次）。
func _spawn_zan_mote() -> void:
	var zan := _chars[2]
	for i in randi_range(1, 2):
		var mote := ColorRect.new()
		mote.color = Color("#ffe08a")
		mote.size = Vector2(FONT_SCALE, FONT_SCALE)   # 1 个字体像素
		mote.position = zan.position + Vector2(
			randf_range(20.0, zan.size.x - 20.0), randf_range(10.0, 50.0))
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mote)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(mote, "position:y",
			mote.position.y - randf_range(36.0, 56.0), 1.2)
		tw.tween_property(mote, "modulate:a", 0.0, 1.2).from(0.9) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mote.queue_free)


func _all_elements() -> Array[Control]:
	var all: Array[Control] = []
	for lb in _chars:
		all.append(lb)
	all.append(_crown)
	for lb in _subs:
		all.append(lb)
	return all


## 退场：随胜方波推进方向逐字推走淡出（蓝胜向右排走，红胜向左）。
func play_exit(blue_wins: bool) -> void:
	_exiting = true
	_entrance_done = false
	var dir := 1.0 if blue_wins else -1.0
	# [节点, 横向位次(0..4)]：王冠跟王同批；副标题按自身位次同节奏被推走
	var items: Array = []
	for i in _chars.size():
		items.append([_chars[i], i])
	items.append([_crown, 4])
	for j in _subs.size():
		items.append([_subs[j], j * 4.0 / (_subs.size() - 1)])
	for item_v in items:
		var item: Array = item_v
		var tr := item[0] as Control
		var rank := item[1] as float
		var order := rank if blue_wins else (4.0 - rank)
		var tw := create_tween()
		tw.tween_interval(order * 0.04)
		tw.tween_property(tr, "position:x", tr.position.x + dir * 200.0, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(tr, "modulate:a", 0.0, 0.22)


## 调试辅助（tools/title_preview.gd 对齐测量用）：王冠 / 王字的当前屏幕区域。
func get_crown_rect() -> Rect2:
	return Rect2(_crown.position, _crown.size)


func get_king_rect() -> Rect2:
	var lb := _chars[4]
	var crown_bottom := _crown.position.y + _crown.size.y
	var top := maxf(lb.position.y, crown_bottom + 4.0)   # 避开王冠像素
	return Rect2(Vector2(lb.position.x - 4.0, top),
		Vector2(lb.size.x + 8.0, lb.position.y + lb.size.y - top))


func _process(delta: float) -> void:
	if not _entrance_done:
		return
	_t += delta
	# 双层漂浮：①字间快波浪（BOB_SPEED 错相，波峰从「波」传向「王」再传过副标题）
	# ②整体慢涌（SLOW_SPEED 全员同相，±6px / 2px 步进）——快慢两频叠加才像浮在水面
	var slow := roundi(sin(_t * SLOW_SPEED) * 3.0) * 2
	for i in _chars.size():
		var off := roundi(sin(_t * BOB_SPEED - i * BOB_PHASE_STEP) * BOB_AMP_PX) \
			* FONT_SCALE + slow
		_chars[i].position.y = _base_pos[i].y + off
		if i == 4:  # 王冠戴在王头上，跟随王的起伏
			_crown.position.y = _base_pos[5].y + off
	for j in _subs.size():
		var off_s := roundi(sin(_t * BOB_SPEED - (CHARS.size() + j) * BOB_PHASE_STEP) \
			* BOB_AMP_PX) * SUB_SCALE + slow
		_subs[j].position.y = _sub_base[j].y + off_s
	# 待机掠光：定期一道白光左→右掠过王冠（与波浪传导同向，替代旧王字单独闪金）
	_sheen_t += delta
	if _sheen_t >= SHEEN_INTERVAL:
		_sheen_t = 0.0
		play_sheen(1.0)
	# 攒字能量微粒（随机间隔，克制频率）
	if _t >= _mote_next:
		_mote_next = _t + randf_range(3.2, 5.0)
		_spawn_zan_mote()

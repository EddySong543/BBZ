class_name HeroFrame
extends Panel

## 回纹头像框(2026-07-13 换皮·同日二版：128px 精准资产+宝石退役+敌我=框色)：满幅头像 + 贴图边框 + 阵营暗底。
## 头像立绘(portrait_path·带背景方图) → 填满框内(stretch COVERED + clip)；底色层(BgFill)兜底头像没覆盖处(如底部)。
## 节点层级(自下而上)：BgFill → Portrait 头像(像素化+posterize·nearest) → InnerFX 内阴影+扫描线 → Bg 贴图边框 → NameLabel。
## 敌我=整框换色变体（我方暖骨 hero_avatar_frame.png / 敌方赤陶 _enemy.png·img_recolor 同源换色）——
## 四角阵营宝石(Corners)已退役(Eddy 2026-07-13)。按 player_color 红蓝倾向自动选贴图·调用方零改动。
## 状态走 Bg modulate：阵亡压灰·选中提亮。内部FX：PortraitMat 像素颗粒；InnerFXMat 暗角+扫描线。

## 选中补色（冷亮蓝白）：与战斗底部动作按钮 _set_btn_selected 的高亮一致。
const SELECTED_TINT := Color(1.28, 1.42, 1.6)

## 敌我框贴图（同源换色变体·tools/img_recolor.gd 产出）。
const FRAME_TEX := preload("res://assets/ui/hero_avatar_frame.png")             # 我方=暖骨
const FRAME_TEX_ENEMY := preload("res://assets/ui/hero_avatar_frame_enemy.png") # 敌方=阵营红 #D24A44(2026-07-17 Eddy："红淡了"·C86A5E 偏粉→提饱和对齐我方框色感)

@export var portrait_path: String = "":
	set(v):
		portrait_path = v
		if is_node_ready():
			_refresh_portrait()

@export var hero_name: String = "":
	set(v):
		hero_name = v
		if is_node_ready() and _name_label:
			(_name_label as Label).text = v.substr(0, 2)

@export var is_active: bool = false:
	set(v):
		is_active = v
		if is_node_ready():
			_refresh_style()

## 选中态：替补被点选、准备换人时高亮（冷亮蓝白补色 + 弹跳放大）→ 选择动画，与底部动作按钮一致。
@export var is_selected: bool = false:
	set(v):
		is_selected = v
		if is_node_ready():
			_refresh_style()
			modulate = SELECTED_TINT if v else Color.WHITE   # 补色：与底部按钮选中同款冷亮蓝白
			_play_select_pop(v)

@export var player_color: Color = Color("#3f86c8"):
	set(v):
		player_color = v
		if is_node_ready():
			_refresh_style()

## ★ 圆角统一控制 ★ —— UV 比例半径(0=直角)，一处同步到全部 4 层(边框/头像/内阴影/底色)的像素圆角。
## 想整体调圆角就改这一个值（或在 HeroFrame 节点的 Inspector 改）。
@export_range(0.0, 0.4, 0.005) var corner_radius: float = 0.3:
	set(v):
		corner_radius = v
		if is_node_ready():
			_apply_corner_radius()

@export var is_dead: bool = false:
	set(v):
		is_dead = v
		if is_node_ready():
			_refresh_style()

@export var frame_size: Vector2 = Vector2(72, 72):
	set(v):
		frame_size = v
		if is_node_ready():
			size = v

## 头像水平翻转（P2 对手头像朝左用）。
@export var flip_h: bool = false:
	set(v):
		flip_h = v
		if is_node_ready() and _portrait:
			(_portrait as TextureRect).flip_h = v

# ── 菱形模式（2026-07-18 Eddy·ref10 左侧头像语言）────────────────────
# **opt-in**：默认 false = 回纹方框原样。本组件同时被 BP 牌池 / 阵亡替补浮窗 /
# 英雄图鉴共用，默认行为绝不能动（同 hero_card 类型框模式的 opt-in 先例）。
# 开启后：回纹框/内阴影/底色三层隐藏 → 菱形外框（暗底+描边）+ 头像只收下半。
@export var diamond_mode: bool = false:
	set(v):
		diamond_mode = v
		if is_node_ready():
			_apply_diamond_mode()

## 菱形模式下头像相对框的放大倍率。**底边对齐框底** → 调大只向上长（头顶自然溢出框外）。
@export_range(1.0, 2.5, 0.05) var diamond_portrait_zoom: float = 1.15:
	set(v):
		diamond_portrait_zoom = v
		if is_node_ready() and diamond_mode:
			_layout_diamond_portrait()

## 菱形模式下头像整体再上移的像素（正=更往上顶·负=下沉）。
@export var diamond_portrait_rise: float = 0.0:
	set(v):
		diamond_portrait_rise = v
		if is_node_ready() and diamond_mode:
			_layout_diamond_portrait()

## 菱形亮边宽度（成品像素·阵营色）。
@export var diamond_stroke_px: float = 4.0:
	set(v):
		diamond_stroke_px = v
		if is_node_ready() and diamond_mode:
			_apply_diamond_mode()

## 亮边外面那圈近黑压边宽度（成品像素）。单亮边贴夜空显单薄 → 外套暗边才立得住。
@export var diamond_rim_px: float = 2.0:
	set(v):
		diamond_rim_px = v
		if is_node_ready() and diamond_mode:
			_apply_diamond_mode()

## 上半收口：**负数 = 完全不收**（默认·ref10 原意：上半头像盖过上半菱形框，Eddy 2026-07-18 拍板）。
## ≥0 则把菱形顶点往上拉长这么多像素再收口（0 = 上下一样收死）——想把头顶收紧时才用。
@export var diamond_top_slack_px: float = -1.0:
	set(v):
		diamond_top_slack_px = v
		if is_node_ready() and diamond_mode:
			_layout_diamond_portrait()

var _portrait: TextureRect
var _name_label: Label
var _bg: TextureRect          # 贴图边框（2026-07-13 换皮·原 shader ColorRect）
var _bg_fill: ColorRect
var _inner_fx: ColorRect
var _switch_label: Label   # 主动换人：armed 时盖在立绘上显示「切换」二字（任务5）
var _sel_tween: Tween      # 选中弹跳动画（选择动作时的 pop）
var _diamond: ColorRect    # 菱形外框（diamond_mode 懒建）
static var _cache: Dictionary = {}

const DIAMOND_FRAME_SHADER := preload("res://assets/shaders/canvas_ui_diamond_frame.gdshader")
const DIAMOND_MASK_SHADER := preload("res://assets/shaders/canvas_ui_diamond_mask.gdshader")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# 入树时套用 frame_size → size。frame_size 的 setter 仅在 is_node_ready() 才应用，
	# 若调用方在 add_child(节点未 ready·如游离 wrap) 之前设 frame_size，size 会停在默认值；
	# 这里在 _ready 兜底套用，保证任何用法下框尺寸都正确（修被动换人浮窗头像不对齐）。
	size = frame_size
	_setup_children()
	_apply_corner_radius()
	_apply_diamond_mode()
	_refresh_portrait()
	_refresh_style()


func _setup_children() -> void:
	_portrait = _find_child_named("Portrait") as TextureRect
	_bg = _find_child_named("Bg") as TextureRect
	_bg_fill = _find_child_named("BgFill") as ColorRect
	_inner_fx = _find_child_named("InnerFX") as ColorRect
	_name_label = _find_child_named("NameLabel") as Label
	if _name_label:
		_name_label.visible = false   # 头像框不显示英雄名(节点保留备用)


func _find_child_named(cname: String) -> Node:
	for c in get_children():
		if c.name == cname:
			return c
	return null


## 把 corner_radius 一处同步到 4 层材质(边框/头像/内阴影/底色) → 统一控制圆角。
func _apply_corner_radius() -> void:
	for n in [_bg, _portrait, _inner_fx, _bg_fill]:
		if n != null and n.material is ShaderMaterial:
			(n.material as ShaderMaterial).set_shader_parameter("corner_radius", corner_radius)


func _refresh_portrait() -> void:
	if not _portrait:
		return
	if portrait_path == "" or not ResourceLoader.exists(portrait_path):
		_portrait.visible = false
		return
	# 头像立绘(带背景方图·无透明边)，整图填满即可，无需裁切。
	var tex: Texture2D
	if _cache.has(portrait_path):
		tex = _cache[portrait_path]
	else:
		tex = load(portrait_path)
		_cache[portrait_path] = tex
	(_portrait as TextureRect).texture = tex
	(_portrait as TextureRect).visible = true
	(_portrait as TextureRect).flip_h = flip_h
	if diamond_mode:
		_layout_diamond_portrait()   # rect 形状取决于纹理长宽比 → 换头像必须重排


func _refresh_style() -> void:
	# 敌我=整框换色贴图（我方暖骨/敌方赤陶·按 player_color 红蓝倾向选）；状态走 Bg modulate。
	# 头像像素化/内阴影/扫描线由 PortraitMat + InnerFX 处理(常驻·与状态无关)。
	var fill: Color
	var frame_mod: Color
	if is_dead:
		fill = Color(0.1, 0.1, 0.11)
		frame_mod = Color(0.42, 0.43, 0.46)   # 贴图框压灰（≈旧灰边档位）
	else:
		fill = Color(0.17, 0.145, 0.115)      # 暖底·抬出近黑(原0.11像黑洞→暖深褐)
		frame_mod = Color.WHITE

	# 选中高亮（换人待确认）：提亮边框（≈旧 e_mid.lightened(0.4) 档位·偏暖）。
	if is_selected and not is_dead:
		frame_mod = Color(1.35, 1.32, 1.18)

	if _bg:
		_bg.texture = FRAME_TEX_ENEMY if player_color.r > player_color.b else FRAME_TEX
		_bg.modulate = frame_mod

	if _bg_fill:
		_bg_fill.color = fill

	# 菱形模式同吃三态：描边沿用敌我配色（我方暖骨 / 敌方阵营红 #D24A44 = 方框贴图同色源），
	# 内填沿用方框那套暖底/阵亡近黑，状态走 modulate。
	if _diamond != null and diamond_mode:
		var dm := _diamond.material as ShaderMaterial
		var enemy := player_color.r > player_color.b
		dm.set_shader_parameter("stroke_color", Color("#d24a44") if enemy else Color(0.93, 0.89, 0.78))
		dm.set_shader_parameter("fill_color", fill)
		_diamond.modulate = frame_mod

	if _portrait:
		if is_dead:
			(_portrait as TextureRect).modulate = Color(0.45, 0.45, 0.5)
		else:
			(_portrait as TextureRect).modulate = Color.WHITE

	if _name_label:
		(_name_label as Label).text = hero_name.substr(0, 2) if hero_name != "" else ""


# ============================================================
# 菱形模式（opt-in·ref10 左侧头像语言）
# ============================================================

## 切换菱形/方框两套外观。方框三层（回纹框 Bg / 内阴影 InnerFX / 底色 BgFill）整组隐藏，
## 换上菱形外框；头像换遮罩材质并重新摆位。关掉即完全复原（BP/浮窗/图鉴走的就是这条）。
func _apply_diamond_mode() -> void:
	for n in [_bg, _inner_fx, _bg_fill]:
		if n != null:
			(n as CanvasItem).visible = not diamond_mode

	if diamond_mode and _diamond == null:
		_diamond = ColorRect.new()
		_diamond.name = "DiamondFrame"
		_diamond.color = Color.WHITE   # ColorRect 的 color 会进片元 COLOR → 必须白，否则给菱形整体上色
		_diamond.material = ShaderMaterial.new()
		(_diamond.material as ShaderMaterial).shader = DIAMOND_FRAME_SHADER
		_diamond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_diamond)
		move_child(_diamond, 0)   # 树序最底 → 头像画在菱形之上
	if _diamond != null:
		_diamond.visible = diamond_mode
		if diamond_mode:
			var m := _diamond.material as ShaderMaterial
			m.set_shader_parameter("size_px", frame_size)
			m.set_shader_parameter("stroke_px", diamond_stroke_px)
			m.set_shader_parameter("rim_px", diamond_rim_px)

	if _portrait == null:
		return
	var p := _portrait as TextureRect
	if diamond_mode:
		p.clip_contents = false     # 顶部要溢出框外 → 不能裁
		# ⚠必须 STRETCH_SCALE：只有它保证「实际绘制的四边形 == 控件 rect」，
		# 遮罩 shader 才能拿 node_size_px 把 UV 换算成正确像素坐标。
		# KEEP_ASPECT_COVERED 会画出比 rect 更大的四边形（非正方立绘更明显：
		# h01 29×31 → 高出 6.9%），UV 映射随之错位 → 下巴逃出遮罩、压在描边上（踩过）。
		# 不失真的办法=下面按纹理长宽比给 rect 定形，SCALE 就等于原比例绘制。
		p.stretch_mode = TextureRect.STRETCH_SCALE
		var mm := ShaderMaterial.new()
		mm.shader = DIAMOND_MASK_SHADER
		p.material = mm
		_layout_diamond_portrait()
	# 关闭分支不复原 material/几何：本组件所有非菱形用法都从未开过菱形模式，
	# 运行时来回切换没有用例（真需要时再补，别为假设写代码）。


## 头像摆位：**底边对齐框底**的正方形，边长 = frame × zoom（再按 rise 上移）。
## 于是 zoom 只往上长 → 头顶溢出框外、下巴始终落在菱形收口处，一个旋钮控制观感。
func _layout_diamond_portrait() -> void:
	if _portrait == null or not diamond_mode:
		return
	var p := _portrait as TextureRect
	# rect 按纹理长宽比定形（非正方立绘 h01/h03/h05/h15 才有区别）→ STRETCH_SCALE 零失真，
	# 且绘制四边形 == rect，遮罩坐标才对得上。
	var h: float = frame_size.y * diamond_portrait_zoom
	var w: float = h
	var tex: Texture2D = p.texture
	if tex != null and tex.get_height() > 0:
		w = h * float(tex.get_width()) / float(tex.get_height())
	var px: float = (frame_size.x - w) * 0.5
	var py: float = frame_size.y - h - diamond_portrait_rise
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.position = Vector2(px, py)
	p.size = Vector2(w, h)
	# 菱形几何换算到头像节点的局部像素坐标（头像比框大且上移 → 必须减去自身原点）
	var m := p.material as ShaderMaterial
	if m != null:
		m.set_shader_parameter("node_size_px", p.size)
		m.set_shader_parameter("dia_center_px", frame_size * 0.5 - p.position)
		m.set_shader_parameter("dia_half_px", frame_size * 0.5)
		m.set_shader_parameter("inset_px", diamond_stroke_px + diamond_rim_px)   # 亮边+压边两圈都要让出来
		m.set_shader_parameter("top_slack_px", diamond_top_slack_px)


func set_hp(_hp: int, _max_hp: int) -> void:
	pass


## 主动换人 armed 态（任务5）：on=立绘隐藏、框内居中显示「切换」二字 + 边框高亮放大；
## off=恢复立绘、去高亮。点替补框进入此态，再次点击=确认换人。
func set_switch_prompt(on: bool, label_text: String = "切换") -> void:
	if _switch_label == null:
		_switch_label = Label.new()
		_switch_label.name = "SwitchPrompt"
		_switch_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_switch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_switch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_switch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fm := get_node_or_null("/root/FontManager")
		if fm != null:
			fm.apply(_switch_label, 16)
		_switch_label.add_theme_color_override("font_color", Color.WHITE)
		_switch_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_switch_label.add_theme_constant_override("outline_size", 4)
		add_child(_switch_label)   # 加在最后 → 渲染在边框/立绘之上
	_switch_label.text = tr(label_text)   # 「切换」(己方换人) / 「揪」(h21 敌方揪目标) 复用同一 label
	_switch_label.visible = on
	if _portrait:
		if on:
			_portrait.visible = false
		else:
			_refresh_portrait()
	# armed ≠ selected（任务5修订）：仅显示「切换」二字 + 隐立绘，不自动高亮；
	# 选中高亮/选择动画由调用方再点一次时通过 is_selected 触发。


## 选择弹跳动画：选中=带 overshoot 放大(像底部按钮 ButtonJuice)；取消=回弹归位。
func _play_select_pop(on: bool) -> void:
	pivot_offset = size * 0.5
	if _sel_tween and _sel_tween.is_valid():
		_sel_tween.kill()
	_sel_tween = create_tween()
	if on:
		_sel_tween.tween_property(self, "scale", Vector2.ONE * 1.12, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_sel_tween.tween_property(self, "scale", Vector2.ONE, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

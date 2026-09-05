@tool
class_name ModeCard
extends Button

## 命运牌模式入口（主菜单三牌阵·第七轮设计 2026-06-11）。
## 牌面=battle 框语言像素框 + 顶部小注 + 纹章（王冠纹理或单字大印）+ 底部名牌横带（牌名+副标）。
## 常态=银框；hover/手柄焦点=金框+放大（Eddy 决议：高亮+放大只属于悬停态，不属于某张固定的牌）。
## 牌体尺寸在 .tscn 里用 offsets 可视化调整；子节点全部运行时自绘（HeroFrame 同范式），
## 文案/纹章走 @export，未来换手绘牌面美术=替换纹章区贴图，结构不动。
##
## 用法：Button 节点挂本脚本，设置 card_title/card_subtitle/card_caption + emblem_char 或 use_crown。

const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")
const CAMPFIRE_SHADER := preload("res://assets/shaders/canvas_ui_campfire.gdshader")
const RIDGES_SHADER := preload("res://assets/shaders/canvas_ui_mountain_ridges.gdshader")
const ROUNDED_FILL_SHADER := preload("res://assets/shaders/canvas_ui_rounded_fill.gdshader")
const SOFT_SHADOW_SHADER := preload("res://assets/shaders/canvas_ui_soft_shadow.gdshader")

# 柔性投影（2026-06-13 Eddy 选 A）：把牌从动态波流背景里拔出 + hover 抬升加深。
const SHADOW_BASE := Color(0.0, 0.0, 0.0, 0.5)   # 常态投影色/浓度
const SHADOW_HOVER_A := 0.64                     # hover 抬升时投影加深
const SHADOW_SOFT := 16.0                        # 软边宽度(px)=核相对节点边内缩
const SHADOW_DROP := 12.0                        # 投影下移(px)→方向光投影(顶光)

## 圆角半径（高度 UV 比例·≈29px@650 高牌=纵向 4 台阶·像素台阶圆角，2026-06-12 Eddy 批）。
## 框 shader 与衬底遮罩共用此值+同 pixel_grid/aspect → 台阶逐格对齐。
## 0.03 实测台阶只有 2-3 级，读成"缺角"而非圆角 → 0.045。
const CORNER_RADIUS := 0.045

# 命运牌框语言：2026-06-13 B「典籍朱印」全局铺。命运牌是暗色艺术展示位（卡内有波流/未来
# 立绘），强行亮羊皮会和艺术打架，故走「暗页暖金牌」：常态=干净暖骨边 + 干净暗页，悬停镀亮金。
# ⚠ 去脏（2026-06-13 二修）：常态边/填充曾用中明度暖棕(aged bronze + 暖棕页)=泥巴色→脏。
#   改干净暖骨(高明度低饱和暖中性)边 + 够暗的近黑暖页(暗≠脏)；中明度暖棕是污渍带，绕开。
const EDGE_OUTER := Color(0.05, 0.045, 0.04)         # 近黑暖（外轮廓）
const SILVER_MID := Color(0.72, 0.66, 0.52)          # 常态边（干净暖骨色·非泥棕）
const SILVER_INNER := Color(0.43, 0.38, 0.28)        # 常态内线（暖中性·清）
const GOLD_MID := Color(0.90, 0.74, 0.36)            # 悬停边（干净亮金箔）
const GOLD_INNER := Color(0.50, 0.39, 0.18)
const GOLD_TEXT := Color("#f4c84b")

const FILL_COLD := Color(0.085, 0.080, 0.072, 0.97)  # 常态牌面（近黑暖·暗≠脏）
const FILL_WARM := Color(0.125, 0.115, 0.10, 0.97)   # 悬停牌面（提亮一档·仍干净）
const TITLE_COLD := Color(0.95, 0.90, 0.78)          # 常态标题（暖米白）
const SUB_COL := Color(0.84, 0.78, 0.66, 0.90)
const CAP_COL := Color(0.84, 0.78, 0.66, 0.55)
const EMBLEM_COL := Color(0.86, 0.76, 0.58, 0.85)

@export var card_title: String = "模式":
	set(v):
		card_title = v
		if _title:
			_title.text = tr(v)
@export var card_subtitle: String = "":
	set(v):
		card_subtitle = v
		if _sub:
			_sub.text = tr(v)
@export var card_caption: String = "":
	set(v):
		card_caption = v
		if _cap:
			_cap.text = tr("· %s ·") % tr(v) if v != "" else ""
@export var emblem_char: String = "":
	set(v):
		emblem_char = v
		if _emblem:
			_emblem.text = v
@export var use_crown: bool = false
## 牌面程序美术母题（全 shader 生成·零贴图·故事/远征两卡动效语言统一·2026-06-24 B 路线）：
##   CAMPFIRE 炉火夜话暖篝火（故事卡）/ RIDGES 登天关冷山脊纵深（远征卡）。
##   母题层垫在框线之下、名牌带文字加描边压住保可读。
enum ArtKind { NONE, CAMPFIRE, RIDGES }
@export var art_kind: ArtKind = ArtKind.NONE
@export var title_font_size: int = 32
## 悬停/焦点放大倍率（高亮+放大=悬停专属效果）。
@export_range(1.0, 1.2) var hover_grow: float = 1.05
## 名牌横带高度占牌高比例。
@export_range(0.1, 0.3) var band_ratio: float = 0.19

var _shadow: ColorRect               # 柔性投影（最底层·尺寸超出卡体容纳软边）
var _shadow_mat: ShaderMaterial
var _backing: ColorRect
var _backing_mat: ShaderMaterial     # 圆角遮罩（外层·full rect）
var _fill: ColorRect
var _fill_mat: ShaderMaterial        # 圆角遮罩（内层·inset 4px 同心弧）
var _art: ColorRect = null           # 程序美术层（_fill 之上 / 框线之下）
var _art_mat: ShaderMaterial = null
var _art_time: float = 0.0
var _art_warm: float = 0.0           # 山脊母题冷暖（0=冷夜配蓝背景 / 1=暖日配红背景·main_menu 据胜方色设）
var _frame: ColorRect
var _frame_mat: ShaderMaterial
var _inner_lines: Array[ColorRect] = []
var _corner_bars: Array[ColorRect] = []      # 包角受光面（亮）
var _corner_shadows: Array[ColorRect] = []   # 包角厚度衬底（暗·偏移 2px 下右）
var _band: ColorRect
var _sep: ColorRect
var _title: Label
var _sub: Label
var _cap: Label
var _emblem: Label
var _crown: TextureRect

var _hot: bool = false
var _tw: Tween
var _shadow_tw: Tween

var _crown_scale: float = 6.0        # 王冠纹章倍率


func _ready() -> void:
	# 清掉 Button 默认皮肤 → 牌面全自绘
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_build()
	_layout()
	_apply_palette()
	resized.connect(_layout)
	mouse_entered.connect(_set_hot.bind(true))
	mouse_exited.connect(_set_hot.bind(false))
	focus_entered.connect(_set_hot.bind(true))
	focus_exited.connect(_set_hot.bind(false))
	button_down.connect(_on_down)
	button_up.connect(_on_up)


func _build() -> void:
	# 圆角=三层各自按像素台阶自切（backing/fill 用 rounded_fill、art 用对应母题 shader
	# 内置遮罩、框线在 frame shader 内沿弧重算）。⚠ 不能用 clip_children 统一裁：
	# Godot 的 clip mask 不执行父节点自定义 shader → 子层直角会从弧外露出（实测踩坑）。
	# 投影必须最先建 → 子节点序最底 → 画在 _backing 之下；ColorRect 自身白色，
	# alpha 由 shader 的 shadow_color 决定（白色保证继承的 modulate.a 不被染色，仅传递）。
	_shadow = _rect(Color.WHITE)
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = SOFT_SHADOW_SHADER
	_shadow_mat.set_shader_parameter("shadow_color", SHADOW_BASE)
	_shadow_mat.set_shader_parameter("softness_px", SHADOW_SOFT)
	_shadow.material = _shadow_mat
	_backing = _rect(EDGE_OUTER)
	_backing_mat = ShaderMaterial.new()
	_backing_mat.shader = ROUNDED_FILL_SHADER
	_backing.material = _backing_mat
	_fill = _rect(FILL_COLD)
	_fill_mat = ShaderMaterial.new()
	_fill_mat.shader = ROUNDED_FILL_SHADER
	_fill.material = _fill_mat
	# 程序美术母题层（框线之下·名牌带之上）。两卡同走 shader 语言、零贴图。
	# CAMPFIRE=暗暖炉火 + 上升火星 + 呼吸；RIDGES=冷色多层山脊纵深 + 视差 + 山谷雾。
	if art_kind != ArtKind.NONE and not Engine.is_editor_hint():
		_art = _rect(Color.WHITE)
		_art_mat = ShaderMaterial.new()
		match art_kind:
			ArtKind.CAMPFIRE:
				_art_mat.shader = CAMPFIRE_SHADER
				_art_mat.set_shader_parameter("cells_x", 54.0)
				_art_mat.set_shader_parameter("intensity", 1.0)
				_art_mat.set_shader_parameter("levels", 40)   # 光晕过渡更细 → banding 更弱
				_art_mat.set_shader_parameter("dither_amt", 1.0)
			ArtKind.RIDGES:
				_art_mat.shader = RIDGES_SHADER
				_art_mat.set_shader_parameter("cells_x", 54.0)
				_art_mat.set_shader_parameter("intensity", 1.0)
				_art_mat.set_shader_parameter("levels", 32)
				_art_mat.set_shader_parameter("dither_amt", 1.0)
				_art_mat.set_shader_parameter("warm", _art_warm)
		_art.material = _art_mat
	_frame = _rect(Color.WHITE)
	_frame_mat = ShaderMaterial.new()
	_frame_mat.shader = FRAME_SHADER
	_frame_mat.set_shader_parameter("border_px", 1.5)
	_frame_mat.set_shader_parameter("noise_amt", 0.035)   # 暖色边降噪→去脏粒（2026-06-13）
	# 2026-06-11 2A 去科幻感：撤常态青镀线（冷色 emissive 细线=全息/科技 UI 公式）、撤竹节
	# （细框上等距分段读成铆钉/能量管节）。保留方向光（中性体积感）；金镀线改为 hover 专属
	# （_apply_palette 随 hot 开关）。质感重心移到四角双色金属包角。
	_frame_mat.set_shader_parameter("light_amount", 0.13)
	_frame.material = _frame_mat

	for i in 4:
		_inner_lines.append(_rect(Color.WHITE))
	# 四角金属包角 = 暗色厚度衬底（先建=画在下层）+ 亮色受光面（后建=画在上层）
	for i in 8:
		_corner_shadows.append(_rect(Color.WHITE))
	for i in 8:
		_corner_bars.append(_rect(Color.WHITE))

	_band = _rect(Color(0.0, 0.0, 0.0, 0.30))
	_sep = _rect(Color.WHITE)

	_cap = _label(CAP_COL)
	_cap.text = tr("· %s ·") % tr(card_caption) if card_caption != "" else ""
	_title = _label(TITLE_COLD)
	_title.text = tr(card_title)
	_sub = _label(SUB_COL)
	_sub.text = tr(card_subtitle)
	_emblem = _label(EMBLEM_COL)
	_emblem.text = emblem_char

	if use_crown and not Engine.is_editor_hint():
		_crown = TextureRect.new()
		_crown.texture = PixelGlyphs.crown_texture()
		_crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_crown.stretch_mode = TextureRect.STRETCH_SCALE
		_crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 正面默认不放王冠；需要时由具体模式调用方控制。
		_crown.visible = false
		add_child(_crown)

	if not Engine.is_editor_hint():
		FontManager.apply(_cap, 14)
		FontManager.apply(_title, title_font_size)
		FontManager.apply(_sub, 16)
		FontManager.apply(_emblem, 96)
	# 场景卡美术上的文字需描边压亮背景；名牌带加深保住标题可读
	if _art:
		for lbl: Label in [_cap, _title, _sub]:
			lbl.add_theme_constant_override("outline_size", 2)
			lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
		_band.color = Color(0.0, 0.0, 0.0, 0.55)
	set_process(_art != null)


## 牌面布局：全部按当前 size 计算（.tscn 改 offsets 即所见即所得）。
func _layout() -> void:
	pivot_offset = size * 0.5
	var band_h := size.y * band_ratio

	# 柔性投影：核=卡体大小，节点外扩 softness 容纳软边，整体下移 SHADOW_DROP→顶光方向投影。
	# 核圆角 = 卡角半径(px)，与卡体圆角一致。
	_shadow.position = Vector2(-SHADOW_SOFT, -SHADOW_SOFT + SHADOW_DROP)
	_shadow.size = size + Vector2(SHADOW_SOFT * 2.0, SHADOW_SOFT * 2.0)
	_shadow_mat.set_shader_parameter("rect_px", _shadow.size)
	_shadow_mat.set_shader_parameter("softness_px", SHADOW_SOFT)
	_shadow_mat.set_shader_parameter("corner_px", CORNER_RADIUS * size.y)

	_backing.position = Vector2.ZERO
	_backing.size = size
	_fill.position = Vector2(4, 4)
	_fill.size = size - Vector2(8, 8)
	if _art:
		_art.position = _fill.position
		_art.size = _fill.size
		_art_mat.set_shader_parameter("aspect", _art.size.x / maxf(_art.size.y, 1.0))
	_frame.position = Vector2.ZERO
	_frame.size = size
	# 圆角参数：外层（框/衬底）共用同值同格 → 台阶逐格对齐；内层（fill/art·inset 4px）
	# 用同心弧换算半径（外弧半径 - 4px），被框 outer 暗层盖住台阶差
	var card_aspect := size.x / maxf(size.y, 1.0)
	var grid := size.x / 5.0
	_frame_mat.set_shader_parameter("pixel_grid", grid)
	_frame_mat.set_shader_parameter("corner_radius", CORNER_RADIUS)
	_frame_mat.set_shader_parameter("aspect", card_aspect)
	_backing_mat.set_shader_parameter("pixel_grid", grid)
	_backing_mat.set_shader_parameter("corner_radius", CORNER_RADIUS)
	_backing_mat.set_shader_parameter("aspect", card_aspect)
	var inner_h := maxf(size.y - 8.0, 1.0)
	var inner_rr := (CORNER_RADIUS * size.y - 4.0) / inner_h
	var inner_asp := (size.x - 8.0) / inner_h
	var inner_grid := (size.x - 8.0) / 5.0
	_fill_mat.set_shader_parameter("pixel_grid", inner_grid)
	_fill_mat.set_shader_parameter("corner_radius", inner_rr)
	_fill_mat.set_shader_parameter("aspect", inner_asp)
	if _art_mat:
		_art_mat.set_shader_parameter("corner_radius", inner_rr)
		_art_mat.set_shader_parameter("corner_grid", inner_grid)
		# 像素格随卡宽缩放 → 各卡像素尺寸一致（横向大卡不再比小卡粗·目标 ≈10px/格）。
		_art_mat.set_shader_parameter("cells_x", maxf(roundf(size.x / 10.0), 24.0))

	# 内细线框
	var inset := 18.0
	var lines: Array[Rect2] = [
		Rect2(inset, inset, size.x - inset * 2.0, 1),
		Rect2(inset, size.y - inset, size.x - inset * 2.0, 1),
		Rect2(inset, inset, 1, size.y - inset * 2.0),
		Rect2(size.x - inset, inset, 1, size.y - inset * 2.0),
	]
	for i in 4:
		_inner_lines[i].position = lines[i].position
		_inner_lines[i].size = lines[i].size

	# 四角金属包角（2A：L 形角花升级双色——亮受光面 + 暗厚度衬底偏移 2px 下右，
	# 顶光方向与边框方向光/标题投影一致；角落承重=手工感，替代被撤的边中段细节）
	var arm := 20.0
	var th := 4.0
	var pad := inset + 6.0
	var origins: Array = [
		[Vector2(pad, pad), Vector2(1, 1)],
		[Vector2(size.x - pad, pad), Vector2(-1, 1)],
		[Vector2(pad, size.y - pad), Vector2(1, -1)],
		[Vector2(size.x - pad, size.y - pad), Vector2(-1, -1)],
	]
	var shadow_off := Vector2(2, 2)
	for i in 4:
		var origin: Vector2 = origins[i][0]
		var dir: Vector2 = origins[i][1]
		var hbar := _corner_bars[i * 2]
		hbar.position = Vector2(origin.x if dir.x > 0 else origin.x - arm,
			origin.y if dir.y > 0 else origin.y - th)
		hbar.size = Vector2(arm, th)
		var vbar := _corner_bars[i * 2 + 1]
		vbar.position = Vector2(origin.x if dir.x > 0 else origin.x - th,
			origin.y if dir.y > 0 else origin.y - arm)
		vbar.size = Vector2(th, arm)
		for k in 2:
			var bright := _corner_bars[i * 2 + k]
			var shadow := _corner_shadows[i * 2 + k]
			shadow.position = bright.position + shadow_off
			shadow.size = bright.size

	# 名牌横带
	var band_y := size.y - band_h
	_band.position = Vector2(8, band_y)
	_band.size = Vector2(size.x - 16, band_h - 10)
	_sep.position = Vector2(24, band_y)
	_sep.size = Vector2(size.x - 48, 2)

	_cap.position = Vector2(0, 20)
	_cap.size = Vector2(size.x, 22)
	_title.position = Vector2(0, band_y + 16)
	_title.size = Vector2(size.x, title_font_size * 1.4)
	_sub.position = Vector2(0, band_y + 16 + title_font_size + 12)
	_sub.size = Vector2(size.x, 26)

	# 纹章居中于美术区（名牌带以上）
	var art_h := size.y - band_h
	_emblem.position = Vector2(0, art_h * 0.5 - 70)
	_emblem.size = Vector2(size.x, 140)
	if _crown:
		_crown.size = Vector2(_crown.texture.get_size()) * _crown_scale
		_crown.position = Vector2((size.x - _crown.size.x) * 0.5, (art_h - _crown.size.y) * 0.5)


## 银/金两套牌面（金=悬停/焦点专属；牌背模式金框常驻）。
func _apply_palette() -> void:
	var hot := _hot
	var mid := GOLD_MID if hot else SILVER_MID
	var inner := GOLD_INNER if hot else SILVER_INNER
	_frame_mat.set_shader_parameter("edge_outer", EDGE_OUTER)
	_frame_mat.set_shader_parameter("edge_mid", mid)
	_frame_mat.set_shader_parameter("edge_inner", inner)
	# 内缘镀线 = hover/焦点专属亮金（加冕语义）；常态无镀线——状态编码靠"平时没有金"
	# （2A：常态月光青已撤，冷色 emissive 线=科幻 UI 公式，与本作题材不符）
	_frame_mat.set_shader_parameter("accent_strength", 0.6 if hot else 0.0)
	_frame_mat.set_shader_parameter("accent_color", Color(1.0, 0.878, 0.541))
	_fill.color = FILL_WARM if hot else FILL_COLD
	_sep.color = Color(mid, 0.5)
	_title.add_theme_color_override("font_color", GOLD_TEXT if hot else TITLE_COLD)
	for ln in _inner_lines:
		ln.color = Color(mid, 0.30)
	# 金属包角：受光面实色 + 厚度衬底用边框内层深色（银/金随态）
	for cb in _corner_bars:
		cb.color = Color(mid, 0.95)
	for cs in _corner_shadows:
		cs.color = Color(inner, 0.90)


## 故事/远征母题统一使用单一 anim_time 驱动。
func _process(delta: float) -> void:
	if _art_mat == null:
		return
	_art_time += delta
	_art_mat.set_shader_parameter("anim_time", _art_time)


## 山脊母题冷暖切换（0=冷夜配蓝背景 / 1=暖日配红背景）。仅 RIDGES 母题生效。
func set_art_warm(w: float) -> void:
	_art_warm = w
	if _art_mat != null and art_kind == ArtKind.RIDGES:
		_art_mat.set_shader_parameter("warm", w)


func _set_hot(hot: bool) -> void:
	if disabled:
		return
	if _hot == hot:
		return
	_hot = hot
	_apply_palette()
	z_index = 1 if hot else 0
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2.ONE * (hover_grow if hot else 1.0), 0.18)\
		.set_trans(Tween.TRANS_BACK if hot else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 投影随抬升加深（卡放大→影变大由父级缩放带动，浓度由本 tween 推）
	_tween_shadow(SHADOW_HOVER_A if hot else SHADOW_BASE.a)


## 投影浓度渐变（hover 抬升=加深 / 离开=回落）。
func _tween_shadow(to_a: float) -> void:
	if _shadow_mat == null:
		return
	if _shadow_tw and _shadow_tw.is_valid():
		_shadow_tw.kill()
	var from_a: float = (_shadow_mat.get_shader_parameter("shadow_color") as Color).a
	_shadow_tw = create_tween()
	_shadow_tw.tween_method(
		func(a: float) -> void:
			_shadow_mat.set_shader_parameter("shadow_color", Color(SHADOW_BASE.r, SHADOW_BASE.g, SHADOW_BASE.b, a)),
		from_a, to_a, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_down() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2.ONE * (hover_grow * 0.96 if _hot else 0.97), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_up() -> void:
	_set_pressed_rebound()


func _set_pressed_rebound() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2.ONE * (hover_grow if _hot else 1.0), 0.14)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ── 节点工厂 ──

func _rect(col: Color, parent: Control = null) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(r)
	return r


func _label(col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

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
const WAVE_CLASH_SHADER := preload("res://assets/shaders/wave_clash.gdshader")
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
## 牌面程序美术母题（全 shader 生成·零贴图·三卡动效语言统一·2026-06-24 B 路线）：
##   WAVE_CLASH 活的蓝红对波（匹配卡）/ CAMPFIRE 炉火夜话暖篝火（故事卡）/
##   RIDGES 登天关冷山脊纵深（远征卡）。母题层垫在框线之下、名牌带文字加描边压住保可读。
enum ArtKind { NONE, WAVE_CLASH, CAMPFIRE, RIDGES }
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
var _art: ColorRect = null           # 对波美术层（_fill 之上 / 框线之下）
var _art_mat: ShaderMaterial = null
var _art_phase_l: float = 0.0
var _art_phase_r: float = 0.37       # 错相起步：左右波不同步更像两军各自涌
var _art_time: float = 0.0
var _art_speed: float = 1.0          # 对波速率倍率（匹配中"临战升温"渐升至 READY 档）
var _art_warm: float = 0.0           # 山脊母题冷暖（0=冷夜配蓝背景 / 1=暖日配红背景·main_menu 据胜方色设）
var _ready_tw: Tween                 # 升温/回落渐变
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

# ---- 牌背模式（盖牌+王冠呼吸）----
# ⚠ 2026-06-12 起主菜单匹配不再翻面（改 set_battle_ready 临战升温——对波卡面
# 翻成静态王冠=出戏）。API 保留给未来联机场景（断线重连/观战盖牌等）。
var _face_down: bool = false
var _gold_locked: bool = false       # 牌背期间金框常驻（不随鼠标进出变化）
var _crown_scale: float = 6.0        # 王冠纹章倍率：正面 ×6 / 牌背 ×4
var _flip_tw: Tween
var _breath_tw: Tween                # 牌背王冠呼吸
var _float_tw: Tween                 # 牌背轻浮动
var _float_home_y: float = 0.0


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
	# 圆角=三层各自按像素台阶自切（backing/fill 用 rounded_fill、art 用 wave_clash
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
	# 程序美术母题层（框线之下·名牌带之上）。三卡同走 shader 语言、零贴图。
	# WAVE_CLASH=低速常燃对波（无大波推进/无爆发，双侧小波涌入 + 中央僵持微光柱）；
	# CAMPFIRE=暗暖炉火 + 上升火星 + 呼吸；RIDGES=冷色多层山脊纵深 + 视差 + 山谷雾。
	if art_kind != ArtKind.NONE and not Engine.is_editor_hint():
		_art = _rect(Color.WHITE)
		_art_mat = ShaderMaterial.new()
		match art_kind:
			ArtKind.WAVE_CLASH:
				_art_mat.shader = WAVE_CLASH_SHADER
				_art_mat.set_shader_parameter("clash_pos", 0.5)
				_art_mat.set_shader_parameter("cells_x", 48.0)
				_art_mat.set_shader_parameter("intensity", 0.85)
				_art_mat.set_shader_parameter("pulse_amp", 0.0)
				_art_mat.set_shader_parameter("center_amp", 0.30)
				# v3 对波解剖后回调（2026-07-17 波家族同步）：芯/鞘增益比旧亮度带高一截，
				# 0.42 会顶到爆白——0.20 与 boot 稳态 0.18 同档。
				_art_mat.set_shader_parameter("wave_amp", 0.20)
				_art_mat.set_shader_parameter("levels", 40)
				_art_mat.set_shader_parameter("dither_amt", 1.0)
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
		# 正面不放王冠（2026-06-12 Eddy：对波卡面自明，王冠多余）——
		# 王冠只在牌背出现（盖牌图记+匹配中呼吸+found_flash 闪金）。
		_crown.visible = false
		add_child(_crown)

	if not Engine.is_editor_hint():
		FontManager.apply(_cap, 14)
		FontManager.apply(_title, title_font_size)
		FontManager.apply(_sub, 16)
		FontManager.apply(_emblem, 96)
	# 对波美术上的文字需描边压亮浪；名牌带加深保住标题可读
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
	var hot := _hot or _gold_locked
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


## 对波美术驱动：双侧小波各自累积相位（速率微差→不同步）+ 纵向漂浮。
## 仅 art_wave_clash 卡开 process；牌背期间美术隐藏但相位继续走（翻回不跳变）。
## _art_speed=临战升温倍率（set_battle_ready 渐变驱动，常态 1.0）。
func _process(delta: float) -> void:
	if _art_mat == null:
		return
	if art_kind == ArtKind.WAVE_CLASH:
		_art_phase_l += delta * 0.085 * _art_speed
		_art_phase_r += delta * 0.097 * _art_speed
		_art_time += delta * 1.2 * _art_speed
		_art_mat.set_shader_parameter("phase_l", _art_phase_l)
		_art_mat.set_shader_parameter("phase_r", _art_phase_r)
		_art_mat.set_shader_parameter("wave_time", _art_time)
	else:
		# 篝火/山脊：单一 anim_time 驱动（火焰演化/火星上升/呼吸 与 山脊视差/雾气漂移同源）
		_art_time += delta
		_art_mat.set_shader_parameter("anim_time", _art_time)


## 山脊母题冷暖切换（0=冷夜配蓝背景 / 1=暖日配红背景）。main_menu 据 boot 胜方色调用，
## 设置面板翻转界面主色时也会重调，使远征卡始终与背景对波色协调。仅 RIDGES 母题生效。
func set_art_warm(w: float) -> void:
	_art_warm = w
	if _art_mat != null and art_kind == ArtKind.RIDGES:
		_art_mat.set_shader_parameter("warm", w)


## 临战升温（匹配中状态·2026-06-12 取代翻面盖牌——把全场最活的卡翻成静态王冠=出戏）：
## on=波速渐升 ×3 + 中央僵持光柱上探 + 整卡亮度微升 + 金框常驻 ——"两军开始集结"；
## off=各参数缓落回常燃档。文案切换由调用方（main_menu）负责。
func set_battle_ready(on: bool) -> void:
	if _art_mat == null or art_kind != ArtKind.WAVE_CLASH:
		return
	_gold_locked = on
	# 升温期间抑制悬停缩放（金框已常驻·放大会盖住下方取消钮）：归位并复位 hot 态
	if on:
		_hot = false
		z_index = 0
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		_tw.tween_property(self, "scale", Vector2.ONE, 0.18)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_apply_palette()
	if _ready_tw and _ready_tw.is_valid():
		_ready_tw.kill()
	_ready_tw = create_tween().set_parallel(true)
	_ready_tw.tween_property(self, "_art_speed", 3.0 if on else 1.0, 1.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_art_param("center_amp", 0.55 if on else 0.30, 1.2)
	_tween_art_param("intensity", 1.0 if on else 0.85, 1.2)
	_tween_art_param("wave_amp", 0.50 if on else 0.42, 1.2)


func _tween_art_param(param: String, to: float, dur: float) -> void:
	var from: float = _art_mat.get_shader_parameter(param)
	_ready_tw.tween_method(
		func(v: float) -> void: _art_mat.set_shader_parameter(param, v),
		from, to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_hot(hot: bool) -> void:
	if disabled or _face_down or _gold_locked:
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


# ── 牌背模式（匹配中=盖牌等对手）──

## 翻面（横向压缩→中点换面→回弹展开·BP REVEAL 同语言）。await 可等动画完成。
## down=true 进牌背：隐藏正面信息（小注/字印），王冠缩小+呼吸+牌体轻浮动，金框常驻；
## down=false 翻回正面恢复一切。牌名/副标文字由调用方（main_menu）通过 card_title/card_subtitle 改。
func flip_face(down: bool) -> void:
	if _face_down == down:
		return
	if _tw and _tw.is_valid():
		_tw.kill()
	if _flip_tw and _flip_tw.is_valid():
		_flip_tw.kill()
	if not down:
		_stop_back_anims()
	# 压缩（顺带把 hover 缩放归一，防止翻完后 x/y 不一致）
	_flip_tw = create_tween().set_parallel(true)
	_flip_tw.tween_property(self, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip_tw.tween_property(self, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _flip_tw.finished
	_face_down = down
	_gold_locked = down
	_apply_face()
	_apply_palette()
	_flip_tw = create_tween()
	_flip_tw.tween_property(self, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _flip_tw.finished
	if down:
		_start_back_anims()


## 匹配成功一拍：对波真撞一次（撞闪 + 竖直涟漪荡开 + 波速尖峰）+ 牌体弹震
## （屏幕轻震由 main_menu 负责）。卡里的战争打响 → 波幕转场进 BP 叙事连贯。
func found_flash() -> void:
	_stop_back_anims()
	if _ready_tw and _ready_tw.is_valid():
		_ready_tw.kill()
	if _art_mat and art_kind == ArtKind.WAVE_CLASH:
		var t := create_tween().set_parallel(true)
		t.tween_method(
			func(v: float) -> void: _art_mat.set_shader_parameter("hit_flash", v),
			1.0, 0.0, 0.4)
		# 初撞涟漪：两道竖直亮带自中央荡开（boot 同语言）
		t.tween_method(
			func(v: float) -> void: _art_mat.set_shader_parameter("ripple", v),
			0.0, 1.0, 0.5)
		# 波速尖峰后缓落（撞击的余势）
		_art_speed = 5.0
		t.tween_property(self, "_art_speed", 1.0, 0.8)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _crown:
		_crown.modulate = Color(2.2, 2.2, 1.5)
		var tc := create_tween()
		tc.tween_property(_crown, "modulate", Color.WHITE, 0.35)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 牌背内容切换：正面信息收起 / 王冠倍率切换（_layout 复用 _crown_scale）。
func _apply_face() -> void:
	_cap.visible = not _face_down and card_caption != ""
	_emblem.visible = not _face_down and emblem_char != ""
	if _art:
		_art.visible = not _face_down   # 牌背=安静深色面（呼吸王冠是主角）
	if _crown:
		_crown.visible = _face_down     # 王冠=牌背专属（正面已撤 2026-06-12）
	_crown_scale = 4.0 if _face_down else 6.0
	_layout()


## 牌背待机：王冠呼吸（明暗 1.5s 周期）+ 牌体轻浮动（±3px 正弦）——"盖着的牌在等待中活着"。
func _start_back_anims() -> void:
	if _crown:
		_breath_tw = create_tween().set_loops()
		_breath_tw.tween_property(_crown, "modulate:a", 0.55, 0.75)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_breath_tw.tween_property(_crown, "modulate:a", 1.0, 0.75)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_home_y = position.y
	_float_tw = create_tween().set_loops()
	_float_tw.tween_property(self, "position:y", _float_home_y - 3.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tw.tween_property(self, "position:y", _float_home_y + 3.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_back_anims() -> void:
	if _breath_tw and _breath_tw.is_valid():
		_breath_tw.kill()
	if _float_tw and _float_tw.is_valid():
		_float_tw.kill()
		position.y = _float_home_y
	if _crown:
		_crown.modulate.a = 1.0


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

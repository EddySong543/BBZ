extends Control

## 英雄图鉴 v4（2026-06-27 重做：「暖深底 + 鎏金浮雕 + 宝石点缀」奇幻 B+C·朝 ref12）。
## 左 = 24 卡六列网格落在凹陷展板上（卡=hero_card.tscn 共用件·与 BP 同源）；点卡=选中（金框）。
## 右 = 常驻详情板：放大 idle 动画（占满展板）+ 名牌 + No./❤章 + 主/被动印 + 技能名 + 描述盒。
## ←/→ 环绕换人（↑/↓ = ±一行），ESC / 返回钮 → 波幕转场回主菜单。
## 设计要点（见 design/ui-design-system.md）：
##   ① 暗背景 → 深酒红书页(连续径向渐变·暖米白字) → 更深凹陷展板(承载卡)，靠亮鎏金浮雕框分隔
##      （ref12 法：暗底深面板 + 亮金边 = 跳出·高对比·"富"非"脏"）。
##   ② 面板质感走连续渐变(GradientTexture2D 径向)而非离散噪点；金边等距铆钉 + 宝石点缀。
##   ③ 网格红心徽在图鉴里隐藏（HP 在详情板·24 红心=噪声）。HPBadge 属共用件不删、仅隐。
## ⚠ 装饰节点必须 mouse_filter=IGNORE——否则吞点击（返回失效·v1 踩过坑）。

const HERO_CARD_SCENE := preload("res://src/ui/components/hero_card.tscn")
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")
const HEART_SHEET := preload("res://assets/ui/icons/heart_idle.png")

const HERO_DATA_DIR := "res://assets/data/heroes/"
const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 左侧牌库网格（24 卡 0.846 缩放=110×134·六列固定网格 6×4）──
const CARD_SCALE := 0.846
const POOL := Rect2(60, 140, 1032, 900)
const COLS := 6
const STEP_X := 121.0
const ROW_H := 142.0
const X0 := 218.0
const ROW_Y0 := 186.0

# ── 右侧详情板 ──
const PANEL := Rect2(1132, 140, 728, 900)

# ── 配色 v4「暖深底 + 鎏金浮雕 + 宝石点缀」(2026-06-27·奇幻 B+C·朝 ref12) ──
# 暗暖背景 → 深酒红书页(径向渐变·暖米白字) → 更深凹陷展板(承载卡) → 亮鎏金浮雕框分隔。
const EDGE_OUTER := Color(0.09, 0.055, 0.035)  # 框外轮廓=近黑暖（暗底上勾边）
const GOLD_HI := Color(0.96, 0.80, 0.44)       # 亮金（浮雕高光/内缘镀线）
const GOLD_MID := Color(0.80, 0.58, 0.28)      # 金主带
const GOLD_LO := Color(0.46, 0.31, 0.14)       # 内暗金线
const RIVET := Color(0.58, 0.41, 0.18)         # 装饰铆钉=暗金
const GOLD_TEXT := Color("#f0c860")            # 泥金（标题/英雄名·配深描边）

const PAGE_FILL := Color(0.31, 0.125, 0.095)   # 书页中心（深酒红·渐变亮端）
const PAGE_EDGE := Color(0.17, 0.075, 0.060)   # 书页边缘（渐变暗端·连续暗角）
const BOARD_FILL := Color(0.205, 0.090, 0.072) # 凹陷展板中心（更深·承载卡）
const BOARD_EDGE := Color(0.085, 0.045, 0.035) # 展板凹陷投影边

const IVORY := Color(0.95, 0.90, 0.78)         # 暖米白正文（暗底上）
const IVORY_DIM := Color(0.74, 0.66, 0.52)     # 次级暖米白
const INK_LINE := Color(0.55, 0.40, 0.20)      # 分隔线=暗金（暗底上用暖金线）

const PLATE := Color(0.13, 0.075, 0.050)       # 名牌=深铜铭牌（金名在其上跳）
const PLATE_INSET := Color(0.245, 0.105, 0.085) # 凹格填充（章/描述盒·略亮深红）
const GEM_RED := Color(0.86, 0.24, 0.18)       # 红宝石点缀
const GEM_AMBER := Color(1.0, 0.64, 0.26)      # 琥珀珠点缀
const ACTIVE_TAG := Color(0.78, 0.26, 0.19)    # 主动=朱砂印
const PASSIVE_TAG := Color(0.30, 0.45, 0.63)   # 被动=靛蓝印

# 顶带「鎏金牌匾」落位
const PLAQUE := Rect2(800, 26, 320, 64)

var all_heroes: Array[HeroData] = []
var card_cards: Array[HeroCard] = []
var _sel_idx: int = -1

# 详情板部件（_build_detail_panel 一次建好）
var _d_anim: AnimatedSprite2D
var _d_fallback: TextureRect      # 无 idle 资源时的静态头像兜底
var _d_name: Label
var _d_hp_num: Label
var _d_tag: Label
var _d_tag_bg: ColorRect
var _d_tag_edge: ColorRect
var _d_skill_name: Label
var _d_detail: Label
var _d_glow: TextureRect          # 立绘背后柔光
var _d_chip1_edge: ColorRect      # 编号章（No.XX）
var _d_chip1_fill: ColorRect
var _d_chip1_lbl: Label
var _d_chip2_edge: ColorRect      # 生命章（❤+数字）
var _d_chip2_fill: ColorRect
var _d_hp_heart: TextureRect
var _row_glow: ColorRect          # 左网格选中行微亮条

@onready var pool_area: Control = $PoolArea
@onready var detail_area: Control = $DetailArea
@onready var back_btn: Button = $TopBand/BackButton
@onready var title_lbl: Label = $TopBand/Title


func _ready() -> void:
	all_heroes = HeroData.create_launch_pool(HERO_DATA_DIR)   # 首发 24（h01-h24）
	_setup_top()
	_build_pool()
	_build_detail_panel()
	_select(0)
	_play_intro()


func _setup_top() -> void:
	_build_plaque()
	_build_collect_badge()

	FontManager.apply_btn(back_btn, 24)
	back_btn.add_theme_color_override("font_color", IVORY)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		back_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var edge := ColorRect.new()
	edge.color = Color(GOLD_MID, 0.85)
	edge.show_behind_parent = true
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.offset_left = -2
	edge.offset_top = -2
	edge.offset_right = 2
	edge.offset_bottom = 2
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击（返回失效 bug）
	back_btn.add_child(edge)
	var backing := ColorRect.new()
	backing.color = Color(PLATE, 0.96)
	backing.show_behind_parent = true
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_btn.add_child(backing)
	back_btn.pressed.connect(_back_to_menu)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	back_btn.add_child(bj)


## 顶带「鎏金牌匾」：标题装进横幅像素框 + 左右卷轴端头饰线 + 两端红宝石。
func _build_plaque() -> void:
	var band := $TopBand as Control
	var backing := _band_rect(band, PLAQUE, EDGE_OUTER)
	backing.name = "PlaqueBacking"
	var fill := _band_rect(band,
		Rect2(PLAQUE.position + Vector2(3, 3), PLAQUE.size - Vector2(6, 6)),
		Color(PLATE, 0.97))
	fill.name = "PlaqueFill"
	var frame := _band_rect(band, PLAQUE, Color.WHITE)
	frame.name = "PlaqueFrame"
	frame.material = _make_frame_mat(PLAQUE.size)
	# 标题挪进匾内。y-4：Ark 像素汉字无下伸部·Label 居中视觉偏下补正。
	title_lbl.position = PLAQUE.position + Vector2(0, -4)
	title_lbl.size = PLAQUE.size
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.z_index = 1
	FontManager.apply(title_lbl, 36)
	title_lbl.add_theme_color_override("font_color", GOLD_TEXT)
	title_lbl.add_theme_constant_override("outline_size", 2)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))
	# 左右卷轴端头饰线（端头方块 + 细线·与匾垂直居中对齐）
	var line_y := PLAQUE.position.y + PLAQUE.size.y * 0.5 - 1.0
	for side: Array in [
			[Rect2(612, line_y, 168, 2), Rect2(604, line_y - 3, 8, 8)],
			[Rect2(PLAQUE.end.x + 20, line_y, 168, 2), Rect2(PLAQUE.end.x + 188, line_y - 3, 8, 8)]]:
		_band_rect(band, side[0], Color(GOLD_MID, 0.6))
		_band_rect(band, side[1], Color(GOLD_MID, 0.8))
	# 牌匾两端红宝石点缀（嵌金）
	_gem(band, Vector2(PLAQUE.position.x + 16, PLAQUE.position.y + PLAQUE.size.y * 0.5), GEM_RED)
	_gem(band, Vector2(PLAQUE.end.x - 16, PLAQUE.position.y + PLAQUE.size.y * 0.5), GEM_RED)


## 右上「收集度徽章」：英雄 icon + N / N + 进度条（现=满条）。
func _build_collect_badge() -> void:
	var band := $TopBand as Control
	var plate := Rect2(1620, 30, 240, 50)
	var edge := _band_rect(band, plate, Color(GOLD_MID, 0.8))
	edge.name = "BadgeEdge"
	var fill := _band_rect(band,
		Rect2(plate.position + Vector2(2, 2), plate.size - Vector2(4, 4)),
		Color(PLATE, 0.96))
	fill.name = "BadgeFill"
	var icon := TextureRect.new()
	icon.name = "BadgeIcon"
	icon.texture = PixelGlyphs.icon_texture("hero")
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = Vector2(1634, 39)
	icon.size = Vector2(32, 32)
	icon.modulate = GOLD_TEXT
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(icon)
	var count := $TopBand/CountLabel as Label
	count.position = Vector2(1676, 35)
	count.size = Vector2(164, 24)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.z_index = 1
	FontManager.apply(count, 20)
	count.add_theme_color_override("font_color", IVORY)
	count.text = "%d / %d" % [all_heroes.size(), all_heroes.size()]
	var ratio := 1.0
	_band_rect(band, Rect2(1676, 63, 164, 6), Color(EDGE_OUTER, 0.55))
	_band_rect(band, Rect2(1676, 63, 164.0 * ratio, 6), Color(GOLD_MID, 0.95))


func _band_rect(parent: Control, r: Rect2, col: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = col
	rect.position = r.position
	rect.size = r.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## 连续径向渐变面板（中心亮·边缘暗→连续暗角·非离散点）。用作书页底/展板底。
func _panel_fill(parent: Control, r: Rect2, center_col: Color, edge_col: Color) -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, center_col)
	grad.set_color(1, edge_col)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


## 沿矩形四边等距放装饰铆钉（暗金小钉·ref12 元素·规则有意非随机噪点）。
func _add_rivets(parent: Control, r: Rect2, inset: float) -> void:
	var n_long := maxi(2, int(r.size.x / 170.0))
	var n_short := maxi(2, int(r.size.y / 170.0))
	for i in n_long:
		var t := (i + 0.5) / float(n_long)
		var x := lerpf(r.position.x + inset, r.end.x - inset, t)
		_rivet(parent, Vector2(x, r.position.y + inset))
		_rivet(parent, Vector2(x, r.end.y - inset))
	for i in n_short:
		var t := (i + 0.5) / float(n_short)
		var y := lerpf(r.position.y + inset, r.end.y - inset, t)
		_rivet(parent, Vector2(r.position.x + inset, y))
		_rivet(parent, Vector2(r.end.x - inset, y))


func _rivet(parent: Control, center: Vector2) -> void:
	var base := _band_rect(parent, Rect2(center - Vector2(3, 3), Vector2(6, 6)), RIVET)
	base.z_index = 2
	var hi := _band_rect(parent, Rect2(center - Vector2(2, 2), Vector2(2, 2)), Color(GOLD_HI, 0.8))
	hi.z_index = 2


## 嵌金宝石点缀（金座 + 宝石芯 + 高光点）。
func _gem(parent: Control, center: Vector2, col: Color) -> void:
	_band_rect(parent, Rect2(center - Vector2(6, 6), Vector2(12, 12)), Color(EDGE_OUTER, 0.9)).z_index = 2
	_band_rect(parent, Rect2(center - Vector2(5, 5), Vector2(10, 10)), GOLD_MID).z_index = 2
	_band_rect(parent, Rect2(center - Vector2(3, 3), Vector2(6, 6)), col).z_index = 2
	_band_rect(parent, Rect2(center - Vector2(2, 2), Vector2(2, 2)), Color(1, 1, 1, 0.7)).z_index = 2


## 像素框材质（鎏金浮雕·大板按尺寸折算 ≈6px/格）。
func _make_frame_mat(sz: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", GOLD_MID)
	m.set_shader_parameter("edge_inner", GOLD_LO)
	m.set_shader_parameter("pixel_grid", sz.x / 6.0)
	m.set_shader_parameter("border_px", 2.0)
	m.set_shader_parameter("noise_amt", 0.035)
	m.set_shader_parameter("light_amount", 0.35)
	m.set_shader_parameter("accent_strength", 0.5)
	m.set_shader_parameter("accent_color", GOLD_HI)
	m.set_shader_parameter("aspect", sz.x / sz.y)
	return m


## 左侧牌库（六列网格落在凹陷展板上）。
func _build_pool() -> void:
	_build_codex_page(pool_area, POOL)   # 左书页（深酒红渐变页 + 鎏金框 + 内嵌展板）
	_build_spine(pool_area)              # 中缝书脊（装订带）
	# 行亮条（先建=画在卡下层·键盘导航行定位）
	_row_glow = ColorRect.new()
	_row_glow.color = Color(1.0, 0.80, 0.45, 0.16)   # 展板上选中行暖金光条
	_row_glow.position = Vector2(108, ROW_Y0 - 6)
	_row_glow.size = Vector2(836, 142)
	_row_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool_area.add_child(_row_glow)
	for i in all_heroes.size():
		var h := all_heroes[i]
		var card := HERO_CARD_SCENE.instantiate() as HeroCard
		card.hero_id = h.hero_id
		card.hero_name = h.hero_name
		card.max_hp = h.max_hp
		card.portrait_path = h.portrait_path
		card.scale = Vector2(CARD_SCALE, CARD_SCALE)
		card.position = Vector2(X0 + (i % COLS) * STEP_X, ROW_Y0 + floorf(i / float(COLS)) * ROW_H)
		card.pressed.connect(_select.bind(i))
		pool_area.add_child(card)
		card.compensate_name_scale(CARD_SCALE)   # 名字整数像素渲染（防糊）
		# 图鉴里隐藏 HP 红心徽（HP 在详情板·24 红心=网格噪声·HPBadge 属共用件仅隐不删）
		var hb := card.get_node_or_null("HPBadge") as CanvasItem
		if hb:
			hb.visible = false
		var bj := card.get_node_or_null("ButtonJuice") as ButtonJuice
		if bj:
			bj.base_scale = CARD_SCALE
		card_cards.append(card)
	pool_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 「书页」：深酒红渐变页(backing+渐变 fill+鎏金 frame+铆钉) + 内嵌凹陷展板(承载内容)。
## 左(网格)页 / 右(详情)页 同框 + 中缝书脊 = 一本翻开的图鉴。
func _build_codex_page(parent: Control, r: Rect2) -> void:
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = r.position
	backing.size = r.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backing)
	_panel_fill(parent, Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), PAGE_FILL, PAGE_EDGE)
	var frame := ColorRect.new()
	frame.material = _make_frame_mat(r.size)
	frame.position = r.position
	frame.size = r.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	_add_rivets(parent, r, 11.0)
	# 内嵌凹陷展板（grid 落在其上·更深底让暗英雄/亮名字跳出）
	_build_board(parent, Rect2(r.position + Vector2(26, 34), r.size - Vector2(52, 62)))


## 凹陷展板：深酒红渐变底 + 上/左深投影边(recessed) + 下/右金高光线 → 嵌入页面的展示槽。
func _build_board(parent: Control, r: Rect2) -> void:
	var shade := ColorRect.new()
	shade.color = BOARD_EDGE
	shade.position = r.position - Vector2(2, 2)
	shade.size = r.size + Vector2(4, 4)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
	_panel_fill(parent, r, BOARD_FILL, BOARD_EDGE)
	# 上/左 1px 深线（凹陷投影）
	for er: Rect2 in [
			Rect2(r.position, Vector2(r.size.x, 1)),
			Rect2(r.position, Vector2(1, r.size.y))]:
		_band_rect(parent, er, Color(BOARD_EDGE, 0.8))
	# 下/右 1px 暗金高光线（凹陷立体感）
	for er: Rect2 in [
			Rect2(Vector2(r.position.x, r.end.y - 1), Vector2(r.size.x, 1)),
			Rect2(Vector2(r.end.x - 1, r.position.y), Vector2(1, r.size.y))]:
		_band_rect(parent, er, Color(GOLD_LO, 0.5))


## 中缝书脊：左右两页间的装订带（暗芯 + 金棱 + 装订线缝点）。
func _build_spine(parent: Control) -> void:
	var gx: float = (POOL.end.x + PANEL.position.x) * 0.5
	var top: float = POOL.position.y
	var h: float = POOL.size.y
	var core := ColorRect.new()
	core.color = Color(0.07, 0.045, 0.03, 1.0)   # 装订暗芯
	core.position = Vector2(gx - 13.0, top)
	core.size = Vector2(26.0, h)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(core)
	for off: float in [-13.0, 11.0]:   # 两侧金棱
		var rail := ColorRect.new()
		rail.color = Color(GOLD_MID, 0.7)
		rail.position = Vector2(gx + off, top)
		rail.size = Vector2(2.0, h)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(rail)
	# 装订线缝点（沿书脊等距金点·book 感）
	var n := 9
	for i in n:
		var yy := top + h * (i + 0.5) / float(n)
		var st := ColorRect.new()
		st.color = Color(GOLD_MID, 0.6)
		st.position = Vector2(gx - 2.0, yy - 6.0)
		st.size = Vector2(4.0, 12.0)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(st)


## 右侧常驻详情板：上=idle 动画舞台（展板）·下=名牌 + 数据 + 技能。
func _build_detail_panel() -> void:
	var px := PANEL.position.x
	var py := PANEL.position.y
	# 页框（深酒红渐变 + 鎏金框 + 铆钉）
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = PANEL.position
	backing.size = PANEL.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(backing)
	_panel_fill(detail_area, Rect2(PANEL.position + Vector2(3, 3), PANEL.size - Vector2(6, 6)), PAGE_FILL, PAGE_EDGE)
	var frame := ColorRect.new()
	frame.material = _make_frame_mat(PANEL.size)
	frame.position = PANEL.position
	frame.size = PANEL.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(frame)
	_add_rivets(detail_area, PANEL, 11.0)

	# ── ① 舞台展板：凹陷板 + 柔光 + 台座投影 + 放大 idle ──
	var stage := Rect2(px + 80, py + 50, PANEL.size.x - 160, 408)   # 568×408
	_build_board(detail_area, stage)

	# 主题柔光（白→透明径向·立绘背后一圈暖光·把角色从展板上托起）
	_d_glow = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.86, 0.55, 0.28))
	grad.set_color(1, Color(1.0, 0.86, 0.55, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 256
	gtex.height = 256
	_d_glow.texture = gtex
	_d_glow.position = stage.position + stage.size * 0.5 - Vector2(190, 190)
	_d_glow.size = Vector2(380, 380)
	_d_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_glow)

	# 台座投影（黑→透明径向椭圆·立绘脚下）
	var shadow := TextureRect.new()
	var sgrad := Gradient.new()
	sgrad.set_color(0, Color(0, 0, 0, 0.50))
	sgrad.set_color(1, Color(0, 0, 0, 0.0))
	var stex := GradientTexture2D.new()
	stex.gradient = sgrad
	stex.fill = GradientTexture2D.FILL_RADIAL
	stex.fill_from = Vector2(0.5, 0.5)
	stex.fill_to = Vector2(0.5, 0.0)
	stex.width = 256
	stex.height = 64
	shadow.texture = stex
	shadow.position = stage.position + Vector2(stage.size.x * 0.5 - 150, stage.size.y - 70)
	shadow.size = Vector2(300, 48)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(shadow)

	_d_anim = AnimatedSprite2D.new()
	_d_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_anim.position = stage.position + stage.size * 0.5 + Vector2(0, 28)
	_d_anim.scale = Vector2(1.85, 1.85)   # 256px 帧 → ≈474px（占满展板）
	detail_area.add_child(_d_anim)
	_d_fallback = TextureRect.new()
	_d_fallback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_fallback.position = stage.position + Vector2(80, 60)
	_d_fallback.size = stage.size - Vector2(160, 150)
	_d_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_fallback.visible = false
	detail_area.add_child(_d_fallback)

	# ── 名牌横带：紧贴舞台底沿（深铜铭牌·金名在其上跳）──
	var band_r := Rect2(stage.position.x, stage.end.y + 2, stage.size.x, 60)
	_band_rect(detail_area, Rect2(band_r.position - Vector2(2, 0), band_r.size + Vector2(4, 2)), EDGE_OUTER)
	var band_fill := _band_rect(detail_area, band_r, PLATE)
	band_fill.name = "NamePlate"
	_band_rect(detail_area, Rect2(band_r.position, Vector2(band_r.size.x, 2)), Color(GOLD_MID, 0.8))
	_d_name = _make_label(band_r.position + Vector2(0, 12), Vector2(band_r.size.x, 36), 32, GOLD_TEXT)
	_d_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_name.add_theme_constant_override("outline_size", 1)
	_d_name.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))

	# ── ② 数据段：编号章 + 生命章（两枚药丸章成组居中·深红凹格·暖米白字）──
	_d_chip1_edge = _chip_rect(Color(GOLD_MID, 0.7))
	_d_chip1_fill = _chip_rect(PLATE_INSET)
	_d_chip1_lbl = _make_label(Vector2.ZERO, Vector2(120, 34), 16, IVORY)
	_d_chip1_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_chip1_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_chip2_edge = _chip_rect(Color(GOLD_MID, 0.7))
	_d_chip2_fill = _chip_rect(PLATE_INSET)
	_d_hp_heart = TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = HEART_SHEET
	atlas.region = Rect2(0, 0, HEART_SHEET.get_width() / 4.0, HEART_SHEET.get_height())
	_d_hp_heart.texture = atlas
	_d_hp_heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_hp_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_hp_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_hp_heart.size = Vector2(26, 26)
	_d_hp_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_hp_heart)
	_d_hp_num = _make_label(Vector2.ZERO, Vector2(60, 34), 20, Color("#ff8a72"))   # 暖红（生命数·暗底上提亮）
	_d_hp_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 段间分隔线
	var sep := ColorRect.new()
	sep.color = Color(INK_LINE, 0.45)
	sep.position = Vector2(px + 120, py + 626)
	sep.size = Vector2(PANEL.size.x - 240, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(sep)

	# ── ③ 技能段：标签印 + 技能名（一行居中组）+ 描述盒 ──
	_d_tag_edge = ColorRect.new()
	_d_tag_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_tag_edge)
	_d_tag_bg = ColorRect.new()
	_d_tag_bg.size = Vector2(64, 30)
	_d_tag_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_tag_bg)
	_d_tag = _make_label(Vector2.ZERO, Vector2(64, 24), 16, IVORY)
	_d_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_skill_name = _make_label(Vector2.ZERO, Vector2(300, 30), 24, IVORY)
	_d_skill_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_make_desc_box(detail_area, Rect2(px + 64, py + 700, PANEL.size.x - 128, 150))
	_d_detail = _make_label(Vector2(px + 84, py + 714), Vector2(PANEL.size.x - 168, 122), 16, IVORY)
	_d_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_d_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var hint := _make_label(Vector2(px, py + PANEL.size.y - 38), Vector2(PANEL.size.x, 24), 14, Color(IVORY_DIM, 0.85))
	hint.text = "← → 切换英雄 · ESC 返回"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _chip_rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(r)
	return r


## 选中英雄：左侧卡换金框 + 右板填充（idle 动画 / 无资源退头像）。
func _select(idx: int) -> void:
	if idx == _sel_idx:
		return
	if _sel_idx >= 0:
		card_cards[_sel_idx].card_state = HeroCard.CardState.NORMAL
	_sel_idx = idx
	card_cards[idx].card_state = HeroCard.CardState.SELECTED

	var h := all_heroes[idx]
	if h.sprite_frames_path != "" and ResourceLoader.exists(h.sprite_frames_path):
		_d_anim.sprite_frames = load(h.sprite_frames_path)
		_d_anim.play("idle")
		_d_anim.visible = true
		_d_fallback.visible = false
	else:
		_d_anim.visible = false
		_d_fallback.texture = load(h.portrait_path) if ResourceLoader.exists(h.portrait_path) else null
		_d_fallback.visible = true
	_d_name.text = h.hero_name
	_d_chip1_lbl.text = "No.%02d" % (idx + 1)
	_d_hp_num.text = "%d" % h.max_hp
	var is_passive := h.skill_type == HeroData.SkillType.PASSIVE
	_d_tag.text = "被动" if is_passive else "主动"
	_d_tag_bg.color = PASSIVE_TAG if is_passive else ACTIVE_TAG
	_d_skill_name.text = h.skill_description
	_d_detail.text = h.skill_detail if h.skill_detail != "" else h.skill_description
	_layout_data_chips()
	_layout_skill_row()
	# 选中行亮条滑到所在行
	var row_y := ROW_Y0 - 6 + floorf(idx / float(COLS)) * ROW_H
	create_tween().tween_property(_row_glow, "position:y", row_y, 0.18)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 编号章+生命章作为一组在板内水平居中（编号/血量宽度可变 → 每次按内容重排）。
func _layout_data_chips() -> void:
	var y0: float = PANEL.position.y + 576
	var f: Font = _d_chip1_lbl.get_theme_font("font")
	var w1: float = f.get_string_size(_d_chip1_lbl.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _d_chip1_lbl.get_theme_font_size("font_size")).x + 28.0
	var num_w: float = f.get_string_size(_d_hp_num.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _d_hp_num.get_theme_font_size("font_size")).x
	var w2: float = 12.0 + 26.0 + 8.0 + num_w + 14.0
	var total: float = w1 + 16.0 + w2
	var x0: float = PANEL.position.x + (PANEL.size.x - total) * 0.5
	_d_chip1_edge.position = Vector2(x0, y0)
	_d_chip1_edge.size = Vector2(w1, 34)
	_d_chip1_fill.position = Vector2(x0 + 1, y0 + 1)
	_d_chip1_fill.size = Vector2(w1 - 2, 32)
	_d_chip1_lbl.position = Vector2(x0, y0)
	_d_chip1_lbl.size = Vector2(w1, 34)
	var x2: float = x0 + w1 + 16.0
	_d_chip2_edge.position = Vector2(x2, y0)
	_d_chip2_edge.size = Vector2(w2, 34)
	_d_chip2_fill.position = Vector2(x2 + 1, y0 + 1)
	_d_chip2_fill.size = Vector2(w2 - 2, 32)
	_d_hp_heart.position = Vector2(x2 + 12.0, y0 + 4.0)
	_d_hp_num.position = Vector2(x2 + 12.0 + 26.0 + 8.0, y0)
	_d_hp_num.size = Vector2(num_w + 4.0, 34)


## 标签印+技能名作为一组在板内水平居中（技能名长短不一 → 每次按内容重排）。
func _layout_skill_row() -> void:
	var f: Font = _d_skill_name.get_theme_font("font")
	var fs: int = _d_skill_name.get_theme_font_size("font_size")
	var name_w: float = f.get_string_size(_d_skill_name.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total: float = 64.0 + 14.0 + name_w
	var x0: float = PANEL.position.x + (PANEL.size.x - total) * 0.5
	var y0: float = PANEL.position.y + 648
	_d_tag_edge.position = Vector2(x0 - 2, y0 - 2)
	_d_tag_edge.size = Vector2(68, 34)
	_d_tag_edge.color = Color(EDGE_OUTER, 0.85)
	_d_tag_bg.position = Vector2(x0, y0)
	_d_tag_bg.size = Vector2(64, 30)
	_d_tag.position = Vector2(x0, y0 + 2)
	_d_tag.size = Vector2(64, 26)
	_d_skill_name.position = Vector2(x0 + 78, y0)
	_d_skill_name.size = Vector2(name_w + 8, 30)


## ←/→ 环绕换人，↑/↓ ±一行；ESC 回主菜单。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_to_menu()
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event.is_action_pressed("ui_left"):
		step = -1
	elif event.is_action_pressed("ui_right"):
		step = 1
	elif event.is_action_pressed("ui_up"):
		step = -COLS
	elif event.is_action_pressed("ui_down"):
		step = COLS
	if step != 0 and _sel_idx >= 0:
		_select(wrapi(_sel_idx + step, 0, all_heroes.size()))
		get_viewport().set_input_as_handled()


func _back_to_menu() -> void:
	TransitionManager.transition_to(MENU_SCENE)


## 入场：顶带滑入 + 左侧牌按行翻开扫过 + 右板淡入。
func _play_intro() -> void:
	var band := $TopBand as Control
	var band_home := band.position
	band.position.y -= 130.0
	create_tween().tween_property(band, "position", band_home, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in card_cards.size():
		var card := card_cards[i]
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.001, CARD_SCALE)
		card.modulate.a = 0.0
		var delay := 0.1 + floorf(i / float(COLS)) * 0.1 + (i % COLS) * 0.03
		var ta := create_tween()
		ta.tween_interval(delay)
		ta.tween_property(card, "modulate:a", 1.0, 0.1)
		var tp := create_tween()
		tp.tween_interval(delay)
		tp.tween_property(card, "scale:x", CARD_SCALE, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	detail_area.modulate.a = 0.0
	var td := create_tween()
	td.tween_interval(0.25)
	td.tween_property(detail_area, "modulate:a", 1.0, 0.35)


# ============================================================
# 自绘部件
# ============================================================

func _make_label(pos: Vector2, sz: Vector2, font_px: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.size = sz
	FontManager.apply(lbl, font_px)
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(lbl)
	return lbl


## 纸面描述盒：暗金细边 + 深红凹底（暖米白字在其上读得清）。
func _make_desc_box(parent: Control, r: Rect2) -> void:
	var border := ColorRect.new()
	border.color = Color(GOLD_LO, 0.7)
	border.position = r.position
	border.size = r.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(border)
	var fill := ColorRect.new()
	fill.color = PLATE_INSET
	fill.position = r.position + Vector2(2, 2)
	fill.size = r.size - Vector2(4, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)

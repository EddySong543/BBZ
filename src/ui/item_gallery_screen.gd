extends Control

## 道具图鉴（2026-06-26）。镜像英雄图鉴的「列表左 / 详情右常驻」骨架，材质走典籍朱印暖骨。
## 左 = 当前阶的道具网格（六列·维度色 jelly 小卡=icon+名）；点卡=选中（金框）。
## 右 = 常驻详情板（像素框）：放大图标 + 名 + 阶章 + 维度章 + 一句话描述。
## 顶带 = 标题牌匾 + 三阶标签页（普通/稀有/传说）+ 当前阶计数。
## ←/→ 环绕换道具（↑/↓ = ±一行）·普通/稀有/传说标签页切阶·ESC/返回钮 → 波幕转场回主菜单。
## ⚠ 装饰 ColorRect 必须 mouse_filter=IGNORE（否则吞点击=返回/切阶失效·英雄图鉴踩过坑）。

const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 配色「明亮泥金手抄本」(2026-06-27 重做·与英雄图鉴同源)：近黑→亮羊皮纸·墨字·青铜金框 ──
# ⚠ DARK_WARM / PARCHMENT_HI 名沿用但【值已翻转】= 浅羊皮 / 墨字（详见 hero_gallery_screen.gd 注）。
const EDGE_OUTER := Color(0.24, 0.16, 0.09)    # 框外轮廓=深褐
const EDGE_MID := Color(0.62, 0.46, 0.24)      # 框主带=青铜金
const EDGE_INNER := Color(0.44, 0.31, 0.16)    # 框内线=深金褐
const GOLD_TEXT := Color("#caa033")            # 泥金（标题·配深描边）
const TIN_DIM := Color(0.46, 0.37, 0.26)       # 页面次级文字=淡墨
const DARK_WARM := Color(0.88, 0.81, 0.64)     # 羊皮纸（大面·原近黑→浅·名沿用）
const PAGE_INSET := Color(0.79, 0.71, 0.53)    # 凹格/插图板/铭牌/描述盒（略深羊皮）
const INK_LINE := Color(0.40, 0.30, 0.17)      # 墨线
const PARCHMENT_HI := Color(0.22, 0.15, 0.09)  # 页面主文字=墨（名沿用）

# 维度 → 语义色（与 ItemDraftPopup / ItemSlotRow / 动作按钮同源色板·扩展中立/博弈/趣味）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"), "中立": Color("8a8f98"),
	"博弈": Color("3f9a8f"), "趣味": Color("c86f8a"),
}
const DIM_FALLBACK := Color(0.42, 0.42, 0.47)

# 阶 → 暖系稀有度斜坡（守典籍朱印暖调·不碰冷钢）+ 标签。
const TIER_COLOR := {1: Color("4a7bc0"), 2: Color("8a4fc4"), 3: Color("dca12e")}   # 稀有度色(普通蓝/稀有紫/传说金)·与框/卡同源
const TIER_LABEL := {1: "普通", 2: "稀有", 3: "传说"}

# ── 左侧网格（六列·当前阶最多 24 件=6×4·POOL 高 900 容得下）──
const POOL := Rect2(60, 140, 1032, 900)
const COLS := 6
const BOX := 140.0       # 道具方框（正方·icon 居中其内）
const NAME_H := 40.0      # 框【外】下方名字带高（名字不在框内）
const CARD_W := BOX       # 卡宽 = 方框宽（名字在框外·不撑宽卡）
const CARD_H := BOX + NAME_H   # 方框 + 框外名字带
const STEP_X := 166.0
const ROW_H := 194.0
const X0 := 91.0        # 6 框在 POOL(60..1092) 内水平居中（整数取位保像素硬边）
const ROW_Y0 := 190.0

# ── 右侧详情板 ──
const PANEL := Rect2(1132, 140, 728, 900)
const PLAQUE := Rect2(800, 26, 320, 64)

var _tier: int = 1
var _items: Array[ItemData] = []
var _cards: Array[Button] = []
var _sel_idx: int = -1

# 顶带阶标签页
var _tab_btns: Array[Button] = []

# 详情板部件（_build_detail_panel 一次建好）
var _d_icon: TextureRect
var _d_icon_fallback: Label   # 无图兜底（理论上 61 件全有图）
var _d_glow: TextureRect
var _d_name: Label
var _d_watermark: Label
var _d_tier_edge: ColorRect
var _d_tier_fill: ColorRect
var _d_tier_lbl: Label
var _d_dim_edge: ColorRect
var _d_dim_fill: ColorRect
var _d_dim_lbl: Label
var _d_desc: Label
var _row_glow: ColorRect

@onready var pool_area: Control = $PoolArea
@onready var detail_area: Control = $DetailArea
@onready var back_btn: Button = $TopBand/BackButton
@onready var title_lbl: Label = $TopBand/Title
@onready var count_lbl: Label = $TopBand/CountLabel


func _ready() -> void:
	_setup_top()
	_build_detail_panel()
	_select_tier(1)
	_play_intro()


# ============================================================
# 顶带：牌匾标题 + 阶标签页 + 计数
# ============================================================

func _setup_top() -> void:
	_build_plaque()
	_build_tier_tabs()
	_style_back_button()
	FontManager.apply(count_lbl, 20)
	count_lbl.add_theme_color_override("font_color", Color(TIN_DIM, 0.95))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## 顶带「典籍牌匾」：标题装进横幅像素框（英雄图鉴同语言）。
func _build_plaque() -> void:
	var band := $TopBand as Control
	_band_rect(band, PLAQUE, EDGE_OUTER)
	_band_rect(band,
		Rect2(PLAQUE.position + Vector2(3, 3), PLAQUE.size - Vector2(6, 6)),
		Color(DARK_WARM, 0.97))
	var frame := _band_rect(band, PLAQUE, Color.WHITE)
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", EDGE_MID)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	m.set_shader_parameter("pixel_grid", PLAQUE.size.x / 6.0)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("light_amount", 0.13)
	m.set_shader_parameter("aspect", PLAQUE.size.x / PLAQUE.size.y)
	frame.material = m
	title_lbl.text = "道具图鉴"
	title_lbl.position = PLAQUE.position + Vector2(0, -4)   # y-4：Ark 像素汉字视觉偏下补正
	title_lbl.size = PLAQUE.size
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.z_index = 1
	FontManager.apply(title_lbl, 36)
	title_lbl.add_theme_color_override("font_color", GOLD_TEXT)
	title_lbl.add_theme_constant_override("outline_size", 2)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))
	# 左右卷轴端头饰线（与英雄图鉴匾同款·端头方块 + 细线）
	var line_y := PLAQUE.position.y + PLAQUE.size.y * 0.5 - 1.0
	for side: Array in [
			[Rect2(612, line_y, 168, 2), Rect2(604, line_y - 3, 8, 8)],
			[Rect2(PLAQUE.end.x + 20, line_y, 168, 2), Rect2(PLAQUE.end.x + 188, line_y - 3, 8, 8)]]:
		_band_rect(band, side[0], Color(EDGE_MID, 0.45))
		_band_rect(band, side[1], Color(EDGE_MID, 0.7))


## 三阶标签页（普通/稀有/传说）：选中=金框暖底，未选=暗底压字。点击切阶。
func _build_tier_tabs() -> void:
	var band := $TopBand as Control
	var tab_w := 132.0
	var gap := 12.0
	var total := 3.0 * tab_w + 2.0 * gap
	var x0 := 1310.0   # 牌匾右侧、计数左侧之间的留白带
	for i in 3:
		var t := i + 1
		var btn := Button.new()
		btn.name = "TierTab%d" % t
		btn.position = Vector2(x0 + i * (tab_w + gap), 30.0)
		btn.size = Vector2(tab_w, 50.0)
		btn.focus_mode = Control.FOCUS_NONE
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		FontManager.apply_btn(btn, 24)
		btn.text = TIER_LABEL[t]
		# 两层衬底（边 + 填充）·稍后按选中态刷色
		var edge := ColorRect.new()
		edge.name = "Edge"
		edge.show_behind_parent = true
		edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		edge.offset_left = -2
		edge.offset_top = -2
		edge.offset_right = 2
		edge.offset_bottom = 2
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(edge)
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.show_behind_parent = true
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(fill)
		btn.pressed.connect(_select_tier.bind(t))
		var bj := ButtonJuice.new()
		bj.name = "ButtonJuice"
		btn.add_child(bj)
		band.add_child(btn)
		_tab_btns.append(btn)


## 刷新阶标签页选中态外观。
func _refresh_tabs() -> void:
	for i in _tab_btns.size():
		var btn := _tab_btns[i]
		var sel := (i + 1) == _tier
		var edge := btn.get_node("Edge") as ColorRect
		var fill := btn.get_node("Fill") as ColorRect
		edge.color = Color(GOLD_TEXT, 0.85) if sel else Color(EDGE_INNER, 0.55)
		fill.color = Color(0.18, 0.14, 0.08, 0.96) if sel else Color(DARK_WARM, 0.85)
		btn.add_theme_color_override("font_color", GOLD_TEXT if sel else Color(TIN_DIM, 0.85))


func _style_back_button() -> void:
	FontManager.apply_btn(back_btn, 24)
	back_btn.add_theme_color_override("font_color", PARCHMENT_HI)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		back_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var edge := ColorRect.new()
	edge.color = Color(EDGE_INNER, 0.6)
	edge.show_behind_parent = true
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.offset_left = -2
	edge.offset_top = -2
	edge.offset_right = 2
	edge.offset_bottom = 2
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击（返回失效）
	back_btn.add_child(edge)
	var backing := ColorRect.new()
	backing.color = Color(DARK_WARM, 0.92)
	backing.show_behind_parent = true
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_btn.add_child(backing)
	back_btn.pressed.connect(_back_to_menu)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	back_btn.add_child(bj)


func _band_rect(parent: Control, r: Rect2, col: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = col
	rect.position = r.position
	rect.size = r.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


# ============================================================
# 左侧网格：按阶重建
# ============================================================

## 切换到某一阶：刷标签页 + 重建网格 + 选中第 0 件。
func _select_tier(t: int) -> void:
	_tier = t
	_refresh_tabs()
	_items = ItemCatalog.all_for_tier(t)
	_sel_idx = -1
	_build_pool()
	count_lbl.text = "%d 件" % _items.size()
	if not _items.is_empty():
		_select(0)


func _build_pool() -> void:
	for c in pool_area.get_children():
		c.queue_free()
	_cards.clear()
	_build_codex_page(pool_area, POOL)   # 左书页（暖金框页·与右详情页对称=翻开的图典）
	_build_spine(pool_area)              # 中缝书脊（装订带）
	# 行亮条（先建=画在卡下层·键盘导航行定位）
	_row_glow = ColorRect.new()
	_row_glow.color = Color(EDGE_MID, 0.16)   # 选中行微亮条：浅页上用淡铜金（白在浅页隐形）
	_row_glow.position = Vector2(X0 - 6, ROW_Y0 - 6)
	_row_glow.size = Vector2(COLS * STEP_X - (STEP_X - CARD_W) + 12, CARD_H + 12)
	_row_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool_area.add_child(_row_glow)
	for i in _items.size():
		var card := _make_item_card(_items[i], i)
		card.position = Vector2(X0 + (i % COLS) * STEP_X, ROW_Y0 + floorf(i / float(COLS)) * ROW_H)
		pool_area.add_child(card)
		_cards.append(card)
	pool_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 「书页」：与右侧详情板同材质的暖金像素框页（backing+fill+frame）+ 内墨边。
## 左(网格)页 / 右(详情)页 同框 + 中缝书脊 = 一本翻开的命运图典（道具图鉴原本无托板·卡浮在背景上）。
func _build_codex_page(parent: Control, r: Rect2) -> void:
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = r.position
	backing.size = r.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backing)
	var fill := ColorRect.new()
	fill.color = Color(DARK_WARM, 0.97)   # 近黑暖暗底（页面暗·衬金字/图标）
	fill.position = r.position + Vector2(3, 3)
	fill.size = r.size - Vector2(6, 6)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	var frame := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", EDGE_MID)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	m.set_shader_parameter("pixel_grid", r.size.x / 6.0)   # 大页按尺寸折算 ≈6px/格
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("light_amount", 0.13)
	m.set_shader_parameter("aspect", r.size.x / r.size.y)
	frame.material = m
	frame.position = r.position
	frame.size = r.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	# 内墨边（细墨线内嵌框·页边留白感·极淡）
	var inset := r.grow(-18.0)
	for er: Rect2 in [
			Rect2(inset.position, Vector2(inset.size.x, 1)),
			Rect2(Vector2(inset.position.x, inset.end.y - 1), Vector2(inset.size.x, 1)),
			Rect2(inset.position, Vector2(1, inset.size.y)),
			Rect2(Vector2(inset.end.x - 1, inset.position.y), Vector2(1, inset.size.y))]:
		var ln := ColorRect.new()
		ln.color = Color(INK_LINE, 0.22)
		ln.position = er.position
		ln.size = er.size
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(ln)


## 中缝书脊：左右两页之间的装订带（暗芯 + 金心线 + 上下端头方块，呼应匾额卷轴端头）。
func _build_spine(parent: Control) -> void:
	var gx: float = (POOL.end.x + PANEL.position.x) * 0.5   # 中缝中心 x
	var top: float = POOL.position.y
	var h: float = POOL.size.y
	var core := ColorRect.new()
	core.color = Color(0.20, 0.14, 0.09, 0.92)   # 装订暗芯（深褐书脊）
	core.position = Vector2(gx - 9.0, top)
	core.size = Vector2(18.0, h)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(core)
	var line := ColorRect.new()
	line.color = Color(EDGE_MID, 0.5)   # 金心线
	line.position = Vector2(gx - 1.0, top)
	line.size = Vector2(2.0, h)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	for yy: float in [top - 4.0, top + h - 4.0]:
		var cap := ColorRect.new()
		cap.color = Color(EDGE_MID, 0.7)
		cap.position = Vector2(gx - 5.0, yy)
		cap.size = Vector2(10.0, 8.0)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(cap)


## 单件道具卡（稀有度色 jelly 方框·icon + 框外名）。选中态金框由 _select 刷。
func _make_item_card(item: ItemData, idx: int) -> Button:
	var box_col: Color = ItemCatalog.rarity_color(item.tier)   # 框背景按稀有度(普通蓝/稀有紫/传说金)
	var card := Button.new()
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.size = Vector2(CARD_W, CARD_H)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	# 选中金框（先建·常态隐藏·_select 切显隐）
	var sel_edge := ColorRect.new()
	sel_edge.name = "SelEdge"
	sel_edge.color = GOLD_TEXT
	sel_edge.show_behind_parent = true
	sel_edge.position = Vector2(-3, -3)        # 只包【方框】（不含框外名字）
	sel_edge.size = Vector2(BOX + 6, BOX + 6)
	sel_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_edge.visible = false
	card.add_child(sel_edge)
	# jelly 方框（正方·稀有度色·与抽卡/道具栏同 shader）
	var jelly := ColorRect.new()
	jelly.color = Color.WHITE   # jelly shader 乘 COLOR，须白
	jelly.position = Vector2.ZERO
	jelly.size = Vector2(BOX, BOX)
	jelly.material = _make_card_jelly(box_col)
	jelly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(jelly)
	# 图标（居中于正方框）
	var tex: Texture2D = ItemCatalog.load_icon(item.item_id)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		var isz := 108.0
		icon.position = Vector2((BOX - isz) * 0.5, (BOX - isz) * 0.5)
		icon.size = Vector2(isz, isz)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
	# 名字（移到方框【外】下方·描边压蓝波背景保可读·暖米白）
	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.position = Vector2(-12.0, BOX + 2.0)
	name_lbl.size = Vector2(BOX + 24.0, NAME_H)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FontManager.apply(name_lbl, 16)
	name_lbl.add_theme_color_override("font_color", PARCHMENT_HI)   # 墨字（名沿用·现为深墨）
	name_lbl.add_theme_color_override("font_outline_color", Color(0.90, 0.83, 0.66, 0.85))   # 浅羊皮描边（墨字在浅页上的细halo·替原深描边）
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)
	card.pressed.connect(_select.bind(idx))
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	card.add_child(bj)
	return card


func _make_card_jelly(dim: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = JELLY_SHADER
	m.set_shader_parameter("fill_top", dim.lightened(0.12))
	m.set_shader_parameter("fill_bottom", dim.darkened(0.32))
	m.set_shader_parameter("edge_inner", dim.lightened(0.38))
	m.set_shader_parameter("edge_outer", Color(0.10, 0.09, 0.11))
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 42.0)
	m.set_shader_parameter("corner", 0.09)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("aspect", 1.0)   # 正方框
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("wear", 0.18)
	return m


# ============================================================
# 右侧常驻详情板
# ============================================================

func _build_detail_panel() -> void:
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = PANEL.position
	backing.size = PANEL.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(backing)
	var fill := ColorRect.new()
	fill.color = Color(DARK_WARM, 0.97)
	fill.position = PANEL.position + Vector2(3, 3)
	fill.size = PANEL.size - Vector2(6, 6)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(fill)
	var frame := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", EDGE_MID)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	m.set_shader_parameter("pixel_grid", PANEL.size.x / 6.0)   # 大板按尺寸折算 ≈6px/格
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("light_amount", 0.13)
	m.set_shader_parameter("aspect", PANEL.size.x / PANEL.size.y)
	frame.material = m
	frame.position = PANEL.position
	frame.size = PANEL.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(frame)

	# ── ① 舞台段：暗井 + 大编号水印 + 维度衬光 + 台座投影 + 放大图标 ──
	var stage := ColorRect.new()
	stage.color = Color(PAGE_INSET, 1.0)   # 插图板=略深羊皮（recessed·彩色道具图标在浅板上跳得出）
	stage.position = PANEL.position + Vector2(144, 60)
	stage.size = Vector2(440, 440)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(stage)
	for line_r: Rect2 in [
			Rect2(stage.position, Vector2(stage.size.x, 2)),
			Rect2(stage.position + Vector2(0, stage.size.y - 2), Vector2(stage.size.x, 2)),
			Rect2(stage.position, Vector2(2, stage.size.y)),
			Rect2(stage.position + Vector2(stage.size.x - 2, 0), Vector2(2, stage.size.y))]:
		var ln := ColorRect.new()
		ln.color = Color(EDGE_INNER, 0.6)
		ln.position = line_r.position
		ln.size = line_r.size
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_area.add_child(ln)

	_d_watermark = _make_label(stage.position, stage.size, 192, Color(PARCHMENT_HI, 0.06))
	_d_watermark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_watermark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 维度色径向衬光（白→透明纹理 + modulate 维度色）
	_d_glow = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.86, 0.52, 0.10))   # 图标背后柔暖泥金光晕（浅板上极淡）
	grad.set_color(1, Color(1.0, 0.86, 0.52, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 256
	gtex.height = 256
	_d_glow.texture = gtex
	_d_glow.position = stage.position + Vector2(50, 50)
	_d_glow.size = Vector2(340, 340)
	_d_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_glow)

	# 台座投影
	var shadow := TextureRect.new()
	var sgrad := Gradient.new()
	sgrad.set_color(0, Color(0, 0, 0, 0.40))
	sgrad.set_color(1, Color(0, 0, 0, 0.0))
	var stex := GradientTexture2D.new()
	stex.gradient = sgrad
	stex.fill = GradientTexture2D.FILL_RADIAL
	stex.fill_from = Vector2(0.5, 0.5)
	stex.fill_to = Vector2(0.5, 0.0)
	stex.width = 256
	stex.height = 64
	shadow.texture = stex
	shadow.position = stage.position + Vector2(80, 360)
	shadow.size = Vector2(280, 60)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(shadow)

	# 放大图标（128px 源 → ×2.5 = 320·NEAREST 像素清晰·居中略上）
	_d_icon = TextureRect.new()
	_d_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_icon.size = Vector2(320, 320)
	_d_icon.position = stage.position + (stage.size - _d_icon.size) * 0.5 + Vector2(0, -10)
	_d_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_icon)
	_d_icon_fallback = _make_label(stage.position, stage.size, 48, Color(1, 1, 1, 0.5))
	_d_icon_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_icon_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_icon_fallback.visible = false

	# 名牌横带：紧贴舞台底沿（名字"长"在舞台上）
	var band_r := Rect2(stage.position.x, stage.position.y + stage.size.y, stage.size.x, 64)
	var band_fill := ColorRect.new()
	band_fill.color = Color(0.20, 0.14, 0.09, 0.95)   # 名牌=深黑铜铭牌（泥金道具名在其上跳）
	band_fill.position = band_r.position
	band_fill.size = band_r.size
	band_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(band_fill)
	var band_sep := ColorRect.new()
	band_sep.color = Color(EDGE_MID, 0.5)
	band_sep.position = band_r.position
	band_sep.size = Vector2(band_r.size.x, 2)
	band_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(band_sep)
	_d_name = _make_label(band_r.position + Vector2(0, 14), Vector2(band_r.size.x, 36), 32, GOLD_TEXT)
	_d_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_name.add_theme_constant_override("outline_size", 1)
	_d_name.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))

	# ── ② 数据段：阶章 + 维度章（两枚药丸章成组居中·_layout_chips 按内容重排）──
	_d_tier_edge = _chip_rect(Color(EDGE_INNER, 0.55))
	_d_tier_fill = _chip_rect(Color(PAGE_INSET, 0.95))
	_d_tier_lbl = _make_label(Vector2.ZERO, Vector2(120, 34), 18, PARCHMENT_HI)
	_d_tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_dim_edge = _chip_rect(Color(EDGE_INNER, 0.55))
	_d_dim_fill = _chip_rect(Color(PAGE_INSET, 0.95))
	_d_dim_lbl = _make_label(Vector2.ZERO, Vector2(120, 34), 18, PARCHMENT_HI)
	_d_dim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_dim_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 段间分隔线
	var sep := ColorRect.new()
	sep.color = Color(INK_LINE, 0.35)
	sep.position = Vector2(PANEL.position.x + 120, PANEL.position.y + 690)
	sep.size = Vector2(PANEL.size.x - 240, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(sep)

	# ── ③ 描述段：霜玻璃描述盒 + 一句话描述 ──
	_make_frosted(detail_area, Rect2(PANEL.position.x + 70, PANEL.position.y + 716, PANEL.size.x - 140, 110))
	_d_desc = _make_label(
		Vector2(PANEL.position.x + 90, PANEL.position.y + 732),
		Vector2(PANEL.size.x - 180, 84), 18, PARCHMENT_HI)
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var hint := _make_label(
		Vector2(PANEL.position.x, PANEL.position.y + PANEL.size.y - 40),
		Vector2(PANEL.size.x, 24), 14, Color(TIN_DIM, 0.55))
	hint.text = "← → 切换道具 · 普通/稀有/传说 切阶 · ESC 返回"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _chip_rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(r)
	return r


## 选中某件道具：左卡换金框 + 右板填充（放大图标 / 阶·维度章 / 描述）。
func _select(idx: int) -> void:
	if idx < 0 or idx >= _items.size():
		return
	if _sel_idx == idx:
		return
	if _sel_idx >= 0 and _sel_idx < _cards.size():
		(_cards[_sel_idx].get_node("SelEdge") as ColorRect).visible = false
	_sel_idx = idx
	(_cards[idx].get_node("SelEdge") as ColorRect).visible = true

	var it := _items[idx]
	var dim_col: Color = DIM_COLOR.get(it.dimension, DIM_FALLBACK)
	var tex: Texture2D = ItemCatalog.load_icon(it.item_id)
	if tex != null:
		_d_icon.texture = tex
		_d_icon.visible = true
		_d_icon_fallback.visible = false
	else:
		_d_icon.visible = false
		_d_icon_fallback.text = it.item_name
		_d_icon_fallback.visible = true
	_d_glow.modulate = Color.WHITE   # 衬光保持暖泥金原色（浅底上不再按维度色染·维度由彩色章表达）
	_d_name.text = it.item_name
	_d_watermark.text = "%02d" % (idx + 1)
	_d_tier_lbl.text = TIER_LABEL[it.tier]
	_d_tier_fill.color = Color(TIER_COLOR[it.tier], 0.30)
	_d_dim_lbl.text = it.dimension
	_d_dim_fill.color = Color(dim_col, 0.42)
	_d_desc.text = it.description
	_layout_chips()
	# 选中行亮条滑到所在行
	var row_y := ROW_Y0 - 6 + floorf(idx / float(COLS)) * ROW_H
	create_tween().tween_property(_row_glow, "position:y", row_y, 0.18)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 阶章 + 维度章作为一组在板内水平居中（章宽随文字 → 每次按内容重排）。
func _layout_chips() -> void:
	var y0: float = PANEL.position.y + 600
	var f: Font = _d_tier_lbl.get_theme_font("font")
	var fs: int = _d_tier_lbl.get_theme_font_size("font_size")
	var w1: float = f.get_string_size(_d_tier_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0
	var w2: float = f.get_string_size(_d_dim_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0
	var total: float = w1 + 16.0 + w2
	var x0: float = PANEL.position.x + (PANEL.size.x - total) * 0.5
	_d_tier_edge.position = Vector2(x0, y0)
	_d_tier_edge.size = Vector2(w1, 36)
	_d_tier_fill.position = Vector2(x0 + 1, y0 + 1)
	_d_tier_fill.size = Vector2(w1 - 2, 34)
	_d_tier_lbl.position = Vector2(x0, y0)
	_d_tier_lbl.size = Vector2(w1, 36)
	var x2: float = x0 + w1 + 16.0
	_d_dim_edge.position = Vector2(x2, y0)
	_d_dim_edge.size = Vector2(w2, 36)
	_d_dim_fill.position = Vector2(x2 + 1, y0 + 1)
	_d_dim_fill.size = Vector2(w2 - 2, 34)
	_d_dim_lbl.position = Vector2(x2, y0)
	_d_dim_lbl.size = Vector2(w2, 36)


# ============================================================
# 输入 / 转场 / 入场
# ============================================================

## ←/→ 环绕换道具，↑/↓ ±一行；ESC 回主菜单。
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
	if step != 0 and _sel_idx >= 0 and not _items.is_empty():
		_select(wrapi(_sel_idx + step, 0, _items.size()))
		get_viewport().set_input_as_handled()


func _back_to_menu() -> void:
	TransitionManager.transition_to(MENU_SCENE)


## 入场：顶带滑入 + 左侧卡按行翻开扫过 + 右板淡入（英雄图鉴同语言）。
func _play_intro() -> void:
	var band := $TopBand as Control
	var band_home := band.position
	band.position.y -= 130.0
	create_tween().tween_property(band, "position", band_home, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in _cards.size():
		var card := _cards[i]
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.001, 1.0)
		card.modulate.a = 0.0
		var delay := 0.1 + floorf(i / float(COLS)) * 0.1 + (i % COLS) * 0.03
		var ta := create_tween()
		ta.tween_interval(delay)
		ta.tween_property(card, "modulate:a", 1.0, 0.1)
		var tp := create_tween()
		tp.tween_interval(delay)
		tp.tween_property(card, "scale:x", 1.0, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	detail_area.modulate.a = 0.0
	var td := create_tween()
	td.tween_interval(0.25)
	td.tween_property(detail_area, "modulate:a", 1.0, 0.35)


# ============================================================
# 自绘部件（英雄图鉴同源）
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


## 典籍暗格（墨线细边 + 近黑暖暗底）。
func _make_frosted(parent: Control, r: Rect2) -> void:
	var border := ColorRect.new()
	border.color = Color(INK_LINE, 0.55)
	border.position = r.position
	border.size = r.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(border)
	var fill := ColorRect.new()
	fill.color = Color(PAGE_INSET, 0.92)   # 描述盒=略深羊皮（recessed）
	fill.position = r.position + Vector2(2, 2)
	fill.size = r.size - Vector2(4, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)

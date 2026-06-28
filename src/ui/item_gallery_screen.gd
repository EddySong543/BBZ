extends Control

## 道具图鉴 v3（2026-06-27 重做·与英雄图鉴同源「暗桌 + 亮羊皮页 + 中调展板」三层图底）。
## 左 = 当前阶道具网格落在中调展板上；卡 = 像素框 + 中性暗格 + 图标（与英雄卡同语言·不再糖果 jelly）。
##      稀有度走【框色 + 角宝石】，不整块涂满（解决"传说金贴金底隐形"）。点卡=选中（金框）。
## 右 = 常驻详情板：放大图标（占满展板）+ 名牌 + 阶章 + 维度章 + 一句话描述。
## 顶带 = 标题牌匾 + 三阶标签页（普通/稀有/传说）+ 当前阶计数。
## ⚠ 装饰 ColorRect 必须 mouse_filter=IGNORE（否则吞点击=返回/切阶失效·英雄图鉴踩过坑）。

const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")
const CELL_BG_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")   # 格底：圆角+稀有度底+传说云纹
const ROUND_MASK_SHADER := preload("res://assets/shaders/canvas_ui_round_mask.gdshader")  # 选中金框圆角
const LEGENDARY_BG := preload("res://assets/ui/gold_bottom.png")                          # 传说道具金云纹背景(Eddy 美术)
const LEGENDARY_BG_TINT := Color(1.0, 1.0, 1.0, 1.0)                                       # 原图亮度·不做暗处理(Eddy 2026-06-27)
const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 配色 v3「深框亮页典籍」(2026-06-27·与英雄图鉴同源) ──
const EDGE_OUTER := Color(0.16, 0.10, 0.06)    # 框外轮廓=深咖
const EDGE_MID := Color(0.78, 0.58, 0.30)      # 框主带=青铜金
const EDGE_INNER := Color(0.47, 0.34, 0.18)    # 框内线=深金褐
const GOLD_TEXT := Color("#e8bb52")            # 泥金（标题/名）

const PAPER := Color(0.91, 0.85, 0.70)         # 亮羊皮（页面纸底）
const PAPER_TEXT := Color(0.22, 0.15, 0.09)    # 纸面主文字=墨
const PAPER_DIM := Color(0.45, 0.35, 0.23)     # 纸面次级文字=淡墨
const PAPER_INSET := Color(0.84, 0.77, 0.60)   # 纸面凹格（描述盒/章填充）

const BOARD := Color(0.40, 0.33, 0.24)         # 凹陷展板（承载卡/图标）
const BOARD_EDGE := Color(0.13, 0.09, 0.05)    # 展板凹陷投影边
const BOARD_TEXT := Color(0.95, 0.90, 0.78)    # 展板上文字=浅羊皮

const CELL := Color(0.11, 0.095, 0.085)        # 卡内中性暗格（彩色图标在其上跳·与英雄卡暗底同语言）
const INK_LINE := Color(0.34, 0.25, 0.14)      # 墨线分隔
const PLATE := Color(0.14, 0.10, 0.06)         # 名牌=深铜铭牌

# 维度 → 语义色（与战斗动作按钮/抽卡同源·详情维度章用）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"), "中立": Color("8a8f98"),
	"博弈": Color("3f9a8f"), "趣味": Color("c86f8a"),
}
const DIM_FALLBACK := Color(0.42, 0.42, 0.47)

# 阶 → 稀有度色（普通蓝/稀有紫/传说金·Eddy 定·走框色+角宝石+详情章·不整块涂满）+ 标签。
const TIER_COLOR := {1: Color("4a7bc0"), 2: Color("8a4fc4"), 3: Color("dca12e")}
const TIER_LABEL := {1: "普通", 2: "稀有", 3: "传说"}

# ── 左侧网格（六列·当前阶最多 24 件=6×4）──
const POOL := Rect2(60, 140, 1032, 900)
const COLS := 6
const BOX := 138.0       # 道具方框（正方·icon 居中其内）
const NAME_H := 38.0     # 框【外】下方名字带高
const CARD_W := BOX
const CARD_H := BOX + NAME_H
const STEP_X := 162.0
const ROW_H := 190.0
const X0 := 108.0
const ROW_Y0 := 188.0

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
var _d_icon_fallback: Label
var _d_glow: TextureRect
var _d_name: Label
var _d_tier_edge: ColorRect
var _d_tier_fill: ColorRect
var _d_tier_lbl: Label
var _d_dim_edge: ColorRect
var _d_dim_fill: ColorRect
var _d_dim_lbl: Label
var _d_desc: Label
var _d_flavor: Label
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
	count_lbl.add_theme_color_override("font_color", PAPER_DIM)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## 像素框材质（大板按尺寸折算 ≈6px/格）。
func _make_frame_mat(sz: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", EDGE_MID)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	m.set_shader_parameter("pixel_grid", sz.x / 6.0)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.05)
	m.set_shader_parameter("light_amount", 0.16)
	m.set_shader_parameter("aspect", sz.x / sz.y)
	return m


## 顶带「典籍牌匾」：标题装进横幅像素框 + 左右卷轴端头饰线（英雄图鉴同款）。
func _build_plaque() -> void:
	var band := $TopBand as Control
	_band_rect(band, PLAQUE, EDGE_OUTER)
	_band_rect(band,
		Rect2(PLAQUE.position + Vector2(3, 3), PLAQUE.size - Vector2(6, 6)),
		Color(PLATE, 0.97))
	var frame := _band_rect(band, PLAQUE, Color.WHITE)
	frame.material = _make_frame_mat(PLAQUE.size)
	title_lbl.text = "道具图鉴"
	title_lbl.position = PLAQUE.position + Vector2(0, -4)
	title_lbl.size = PLAQUE.size
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.z_index = 1
	FontManager.apply(title_lbl, 36)
	title_lbl.add_theme_color_override("font_color", GOLD_TEXT)
	title_lbl.add_theme_constant_override("outline_size", 2)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))
	var line_y := PLAQUE.position.y + PLAQUE.size.y * 0.5 - 1.0
	for side: Array in [
			[Rect2(612, line_y, 168, 2), Rect2(604, line_y - 3, 8, 8)],
			[Rect2(PLAQUE.end.x + 20, line_y, 168, 2), Rect2(PLAQUE.end.x + 188, line_y - 3, 8, 8)]]:
		_band_rect(band, side[0], Color(EDGE_MID, 0.5))
		_band_rect(band, side[1], Color(EDGE_MID, 0.75))


## 三阶标签页（普通/稀有/传说）：选中=深铜底+金框金字，未选=羊皮底压字。点击切阶。
func _build_tier_tabs() -> void:
	var band := $TopBand as Control
	var tab_w := 132.0
	var gap := 12.0
	var x0 := 1310.0
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
		var rc: Color = TIER_COLOR[i + 1]
		var edge := btn.get_node("Edge") as ColorRect
		var fill := btn.get_node("Fill") as ColorRect
		edge.color = Color(GOLD_TEXT, 0.9) if sel else Color(EDGE_MID, 0.5)
		fill.color = PLATE if sel else Color(PAPER, 0.9)
		btn.add_theme_color_override("font_color", GOLD_TEXT if sel else Color(PAPER_DIM, 0.95))
		# 选中阶在标签下缘点一条稀有度色带（不靠涂满整框也能读出在哪一阶）
		var bar := btn.get_node_or_null("RarBar") as ColorRect
		if bar == null:
			bar = ColorRect.new()
			bar.name = "RarBar"
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.position = Vector2(8, 42)
			bar.size = Vector2(116, 4)
			btn.add_child(bar)
		bar.color = rc if sel else Color(rc, 0.0)


func _style_back_button() -> void:
	FontManager.apply_btn(back_btn, 24)
	back_btn.add_theme_color_override("font_color", PAPER_TEXT)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		back_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var edge := ColorRect.new()
	edge.color = Color(EDGE_MID, 0.7)
	edge.show_behind_parent = true
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.offset_left = -2
	edge.offset_top = -2
	edge.offset_right = 2
	edge.offset_bottom = 2
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击（返回失效）
	back_btn.add_child(edge)
	var backing := ColorRect.new()
	backing.color = Color(PAPER, 0.95)
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
	_build_codex_page(pool_area, POOL)   # 左书页（亮羊皮框页 + 内嵌展板）
	_build_spine(pool_area)              # 中缝书脊（装订带）
	_row_glow = ColorRect.new()
	_row_glow.color = Color(1.0, 0.88, 0.58, 0.10)   # 展板上选中行暖光条
	_row_glow.position = Vector2(X0 - 12, ROW_Y0 - 10)
	_row_glow.size = Vector2(COLS * STEP_X - (STEP_X - CARD_W) + 24, CARD_H + 16)
	_row_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool_area.add_child(_row_glow)
	for i in _items.size():
		var card := _make_item_card(_items[i], i)
		card.position = Vector2(X0 + (i % COLS) * STEP_X, ROW_Y0 + floorf(i / float(COLS)) * ROW_H)
		pool_area.add_child(card)
		_cards.append(card)
	pool_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 「书页」：亮羊皮像素框页 + 内嵌中调凹陷展板（英雄图鉴同款）。
func _build_codex_page(parent: Control, r: Rect2) -> void:
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = r.position
	backing.size = r.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backing)
	var fill := ColorRect.new()
	fill.color = PAPER
	fill.position = r.position + Vector2(3, 3)
	fill.size = r.size - Vector2(6, 6)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	var frame := ColorRect.new()
	frame.material = _make_frame_mat(r.size)
	frame.position = r.position
	frame.size = r.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	_build_board(parent, Rect2(r.position + Vector2(26, 34), r.size - Vector2(52, 62)))


## 凹陷展板：深中调底 + 上/左深投影边（recessed）。
func _build_board(parent: Control, r: Rect2) -> void:
	var shade := ColorRect.new()
	shade.color = BOARD_EDGE
	shade.position = r.position - Vector2(2, 2)
	shade.size = r.size + Vector2(4, 4)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
	var board := ColorRect.new()
	board.color = BOARD
	board.position = r.position
	board.size = r.size
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(board)
	for er: Rect2 in [
			Rect2(r.position, Vector2(r.size.x, 1)),
			Rect2(r.position, Vector2(1, r.size.y))]:
		var ln := ColorRect.new()
		ln.color = Color(BOARD_EDGE, 0.7)
		ln.position = er.position
		ln.size = er.size
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(ln)


## 中缝书脊：左右两页间的装订带（暗芯 + 两侧金棱 + 等距线缝点）。
func _build_spine(parent: Control) -> void:
	var gx: float = (POOL.end.x + PANEL.position.x) * 0.5
	var top: float = POOL.position.y
	var h: float = POOL.size.y
	var core := ColorRect.new()
	core.color = Color(0.10, 0.07, 0.04, 1.0)
	core.position = Vector2(gx - 13.0, top)
	core.size = Vector2(26.0, h)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(core)
	for off: float in [-13.0, 11.0]:
		var rail := ColorRect.new()
		rail.color = Color(EDGE_MID, 0.6)
		rail.position = Vector2(gx + off, top)
		rail.size = Vector2(2.0, h)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(rail)
	var n := 9
	for i in n:
		var yy := top + h * (i + 0.5) / float(n)
		var st := ColorRect.new()
		st.color = Color(EDGE_MID, 0.55)
		st.position = Vector2(gx - 2.0, yy - 6.0)
		st.size = Vector2(4.0, 12.0)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(st)


## 单件道具卡（像素框 + 中性暗格 + 图标 + 框外名）。稀有度=框色+角宝石。选中=金框由 _select 刷。
func _make_item_card(item: ItemData, idx: int) -> Button:
	var rc: Color = ItemCatalog.rarity_color(item.tier)   # 稀有度色（蓝/紫/金）
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
	sel_edge.position = Vector2(-3, -3)
	sel_edge.size = Vector2(BOX + 6, BOX + 6)
	sel_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_edge.visible = false
	var sm := ShaderMaterial.new()   # 选中金框也圆角（不露方角）
	sm.shader = ROUND_MASK_SHADER
	sm.set_shader_parameter("corner_radius", 0.2)
	sm.set_shader_parameter("pixel_grid", (BOX + 6) / 6.0)
	sel_edge.material = sm
	card.add_child(sel_edge)
	# 格底：圆角 + 稀有度深底（=外框同色调）+ 传说铺满云纹（统一 shader·云纹随圆角裁切·在道具美术之下）
	var cell := ColorRect.new()
	cell.color = Color.WHITE
	cell.position = Vector2.ZERO
	cell.size = Vector2(BOX, BOX)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ShaderMaterial.new()
	cm.shader = CELL_BG_SHADER
	# 内外渐变（2026-06-28 Eddy：参传说 gold_bottom 实测内外区分·中心亮/四角深）：从稀有度色算 fill(四角深·V0.85更饱和) + inner(中心亮·V0.97略浅)。
	cm.set_shader_parameter("fill_color", Color.from_hsv(rc.h, minf(rc.s * 1.05, 1.0), 0.76))
	cm.set_shader_parameter("inner_color", Color.from_hsv(rc.h, rc.s * 0.85, 0.89))
	cm.set_shader_parameter("center_glow", 1.0)              # 1=完整内外渐变（传说由 use_tex 自动排除）
	cm.set_shader_parameter("corner_radius", 0.18)
	cm.set_shader_parameter("pixel_grid", BOX / 6.0)
	# 传说：外部美术图 gold_bottom 当格底（替代程序云纹）——采进格底 shader，随同一套 corner_round_alpha
	# 圆角裁切被**约束到格内**（避开 round_mask 对 TextureRect 不可靠的坑）；压暗去饱和与暗格协调；在道具美术之下。
	if item.tier == 3:
		cm.set_shader_parameter("use_tex", 1.0)
		cm.set_shader_parameter("bg_tex", LEGENDARY_BG)
		cm.set_shader_parameter("tex_tint", LEGENDARY_BG_TINT)
	cm.set_shader_parameter("cloud_on", 0.0)
	cell.material = cm
	card.add_child(cell)
	# 像素框（边=稀有度色·与英雄卡同 shader·圆角）
	var frame := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", rc)
	m.set_shader_parameter("edge_inner", rc.darkened(0.45))
	m.set_shader_parameter("pixel_grid", BOX / 6.0)
	m.set_shader_parameter("border_px", 2.0)
	m.set_shader_parameter("noise_amt", 0.05)
	m.set_shader_parameter("light_amount", 0.18)
	m.set_shader_parameter("aspect", 1.0)
	m.set_shader_parameter("corner_radius", 0.18)   # 圆角（与格底一致·全圆角无方角·Eddy 2026-06-27）
	frame.material = m
	frame.position = Vector2.ZERO
	frame.size = Vector2(BOX, BOX)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	# 图标（居中于暗格）
	var tex: Texture2D = ItemCatalog.load_icon(item.item_id)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		var isz := 104.0
		icon.position = Vector2((BOX - isz) * 0.5, (BOX - isz) * 0.5)
		icon.size = Vector2(isz, isz)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
	# 名字（框外下方·展板上浅羊皮字 + 深描边）
	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.position = Vector2(-12.0, BOX + 2.0)
	name_lbl.size = Vector2(BOX + 24.0, NAME_H)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FontManager.apply(name_lbl, 16)
	name_lbl.add_theme_color_override("font_color", BOARD_TEXT)
	name_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)
	card.pressed.connect(_select.bind(idx))
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	card.add_child(bj)
	return card


# ============================================================
# 右侧常驻详情板
# ============================================================

func _build_detail_panel() -> void:
	var px := PANEL.position.x
	var py := PANEL.position.y
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = PANEL.position
	backing.size = PANEL.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(backing)
	var fill := ColorRect.new()
	fill.color = PAPER
	fill.position = PANEL.position + Vector2(3, 3)
	fill.size = PANEL.size - Vector2(6, 6)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(fill)
	var frame := ColorRect.new()
	frame.material = _make_frame_mat(PANEL.size)
	frame.position = PANEL.position
	frame.size = PANEL.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(frame)

	# ── ① 舞台展板：中调凹陷板 + 柔光 + 台座投影 + 放大图标 ──
	var stage := Rect2(px + 80, py + 50, PANEL.size.x - 160, 408)
	_build_board(detail_area, stage)

	_d_glow = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.90, 0.62, 0.22))
	grad.set_color(1, Color(1.0, 0.90, 0.62, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 256
	gtex.height = 256
	_d_glow.texture = gtex
	_d_glow.position = stage.position + stage.size * 0.5 - Vector2(180, 180)
	_d_glow.size = Vector2(360, 360)
	_d_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_glow)

	var shadow := TextureRect.new()
	var sgrad := Gradient.new()
	sgrad.set_color(0, Color(0, 0, 0, 0.45))
	sgrad.set_color(1, Color(0, 0, 0, 0.0))
	var stex := GradientTexture2D.new()
	stex.gradient = sgrad
	stex.fill = GradientTexture2D.FILL_RADIAL
	stex.fill_from = Vector2(0.5, 0.5)
	stex.fill_to = Vector2(0.5, 0.0)
	stex.width = 256
	stex.height = 64
	shadow.texture = stex
	shadow.position = stage.position + Vector2(stage.size.x * 0.5 - 150, stage.size.y - 64)
	shadow.size = Vector2(300, 44)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(shadow)

	# 放大图标（128px 源 → ×2.7 ≈ 346·NEAREST 像素清晰·占满展板）
	_d_icon = TextureRect.new()
	_d_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_icon.size = Vector2(346, 346)
	_d_icon.position = stage.position + (stage.size - _d_icon.size) * 0.5 + Vector2(0, -6)
	_d_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_icon)
	_d_icon_fallback = _make_label(stage.position, stage.size, 48, Color(BOARD_TEXT, 0.6))
	_d_icon_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_icon_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_icon_fallback.visible = false

	# ── 名牌横带：紧贴舞台底沿（深铜铭牌·金道具名在其上跳）──
	var band_r := Rect2(stage.position.x, stage.end.y + 2, stage.size.x, 60)
	_band_rect(detail_area, Rect2(band_r.position - Vector2(2, 0), band_r.size + Vector2(4, 2)), EDGE_OUTER)
	_band_rect(detail_area, band_r, PLATE)
	_band_rect(detail_area, Rect2(band_r.position, Vector2(band_r.size.x, 2)), Color(EDGE_MID, 0.7))
	_d_name = _make_label(band_r.position + Vector2(0, 12), Vector2(band_r.size.x, 36), 32, GOLD_TEXT)
	_d_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_name.add_theme_constant_override("outline_size", 1)
	_d_name.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))

	# ── ② 数据段：阶章 + 维度章（两枚药丸章成组居中）──
	_d_tier_edge = _chip_rect(Color(EDGE_MID, 0.65))
	_d_tier_fill = _chip_rect(PAPER_INSET)
	_d_tier_lbl = _make_label(Vector2.ZERO, Vector2(120, 36), 18, Color.WHITE)
	_d_tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chip_text_outline(_d_tier_lbl)
	_d_dim_edge = _chip_rect(Color(EDGE_MID, 0.65))
	_d_dim_fill = _chip_rect(PAPER_INSET)
	_d_dim_lbl = _make_label(Vector2.ZERO, Vector2(120, 36), 18, Color.WHITE)
	_d_dim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_dim_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chip_text_outline(_d_dim_lbl)

	var sep := ColorRect.new()
	sep.color = Color(INK_LINE, 0.40)
	sep.position = Vector2(px + 120, py + 626)
	sep.size = Vector2(PANEL.size.x - 240, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(sep)

	# ── ③ 描述段：纸面描述盒 + 机制描述（上）+ 风味文字（下·淡墨）──
	_make_desc_box(detail_area, Rect2(px + 64, py + 670, PANEL.size.x - 128, 170))
	_d_desc = _make_label(
		Vector2(px + 90, py + 680),
		Vector2(PANEL.size.x - 180, 78), 18, PAPER_TEXT)
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 风味文字（机制下方·淡墨·区别于机制·空则不显）
	_d_flavor = _make_label(
		Vector2(px + 90, py + 760),
		Vector2(PANEL.size.x - 180, 72), 16, Color(PAPER_DIM, 0.95))
	_d_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_flavor.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_d_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var hint := _make_label(
		Vector2(px, py + PANEL.size.y - 38),
		Vector2(PANEL.size.x, 24), 14, Color(PAPER_DIM, 0.75))
	hint.text = "← → 切换道具 · 普通/稀有/传说 切阶 · ESC 返回"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _chip_rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(r)
	return r


## 章内白字补深描边 → 在金/蓝/红/绿任何饱和底色上都读得清（传说金底白字曾偏弱）。
func _chip_text_outline(lbl: Label) -> void:
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))


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
	var rc: Color = TIER_COLOR[it.tier]
	var tex: Texture2D = ItemCatalog.load_icon(it.item_id)
	if tex != null:
		_d_icon.texture = tex
		_d_icon.visible = true
		_d_icon_fallback.visible = false
	else:
		_d_icon.visible = false
		_d_icon_fallback.text = it.item_name
		_d_icon_fallback.visible = true
	_d_name.text = it.item_name
	_d_tier_lbl.text = TIER_LABEL[it.tier]
	_d_tier_fill.color = rc
	_d_dim_lbl.text = it.dimension
	_d_dim_fill.color = dim_col
	_d_desc.text = it.description
	_d_flavor.text = it.flavor
	_layout_chips()
	var row_y := ROW_Y0 - 10 + floorf(idx / float(COLS)) * ROW_H
	create_tween().tween_property(_row_glow, "position:y", row_y, 0.18)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 阶章 + 维度章作为一组在板内水平居中（章宽随文字 → 每次按内容重排）。
func _layout_chips() -> void:
	var y0: float = PANEL.position.y + 580
	var f: Font = _d_tier_lbl.get_theme_font("font")
	var fs: int = _d_tier_lbl.get_theme_font_size("font_size")
	var w1: float = f.get_string_size(_d_tier_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 40.0
	var w2: float = f.get_string_size(_d_dim_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 40.0
	var total: float = w1 + 16.0 + w2
	var x0: float = PANEL.position.x + (PANEL.size.x - total) * 0.5
	_d_tier_edge.position = Vector2(x0, y0)
	_d_tier_edge.size = Vector2(w1, 38)
	_d_tier_fill.position = Vector2(x0 + 1, y0 + 1)
	_d_tier_fill.size = Vector2(w1 - 2, 36)
	_d_tier_lbl.position = Vector2(x0, y0)
	_d_tier_lbl.size = Vector2(w1, 38)
	var x2: float = x0 + w1 + 16.0
	_d_dim_edge.position = Vector2(x2, y0)
	_d_dim_edge.size = Vector2(w2, 38)
	_d_dim_fill.position = Vector2(x2 + 1, y0 + 1)
	_d_dim_fill.size = Vector2(w2 - 2, 36)
	_d_dim_lbl.position = Vector2(x2, y0)
	_d_dim_lbl.size = Vector2(w2, 38)


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


## 纸面描述盒：墨线细边 + 略深羊皮凹底。
func _make_desc_box(parent: Control, r: Rect2) -> void:
	var border := ColorRect.new()
	border.color = Color(INK_LINE, 0.55)
	border.position = r.position
	border.size = r.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(border)
	var fill := ColorRect.new()
	fill.color = PAPER_INSET
	fill.position = r.position + Vector2(2, 2)
	fill.size = r.size - Vector2(4, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)

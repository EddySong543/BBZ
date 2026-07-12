extends Control

## 道具图鉴 v5「实体典籍」（2026-07-04 Eddy 定向重做：跳出旧框架·书本外框入画）。
## 参考锚 = ref15（暗格衬亮页·图标弹跳）/ ref17（书=悬浮实体·页签书签化·悬挂牌匾）/ ref18（详情=钉在页上的卡片+划线手记）。
## 抓感觉不照抄：
##   · 书是一个「物件」浮在深靛夜色上（封皮包住页块·页厚台阶可见·金属护角）——不再是全屏铺满的"墙纸"。
##   · 三阶页签 = 从书右缘伸出的实体书签（选中抽出更长更亮）——不再是顶栏胶囊按钮。
##   · 标题 = 悬挂在书顶的牌匾；返回 = 夜色上的浮动羊皮芯片；顶栏整条删除。
##   · 左页 = 深炭格衬亮羊皮（彩色图标自己会跳）；右页 = 稀有度横幅 + 图标卡 + 划线手记。
## ⛔ 配色禁区（Eddy 2026-07-04）：暗红/棕全抛；夜色=深靛（与游戏夜空同源）。
## ⚠ 装饰 ColorRect 必须 mouse_filter=IGNORE（否则吞点击=返回/切阶失效·踩过坑）。

const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")
const PAPER_SHADER := preload("res://assets/shaders/canvas_ui_paper.gdshader")           # 纸/皮质感（v5.2·治纯色扁平）
const CELL_BG_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")   # 格底：圆角+渐变（v5 中性深炭）
const ROUND_MASK_SHADER := preload("res://assets/shaders/canvas_ui_round_mask.gdshader")  # 选中金框圆角
const LEGENDARY_BG := preload("res://assets/ui/gold_bottom.png")                          # 传说道具金云纹格底(Eddy 美术)
const LEGENDARY_BG_TINT := Color(1.0, 1.0, 1.0, 1.0)                                       # 原图亮度·不做暗处理(Eddy 2026-06-27)
const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 配色 v5「实体典籍」(2026-07-04·⛔暗红/棕禁区) ──
const GOLD_MID := Color(0.85, 0.65, 0.33)      # 鎏金（护角/牌匾框/金轨）
const GOLD_TEXT := Color("#e8bb52")            # 泥金（标题/道具名）
const IVORY := Color(0.95, 0.90, 0.78)         # 暖米白（夜色/深底上文字）

const NIGHT_TOP := Color(0.115, 0.125, 0.24)   # 夜色衬底=深靛（与战斗夜空同源·非红非棕）
const NIGHT_BOTTOM := Color(0.06, 0.065, 0.14)
const NIGHT_CORNER := Color(0.04, 0.045, 0.10)

const COVER := Color(0.89, 0.86, 0.76)         # 封皮=象牙（ref17：亮封皮浮在深底上）
const COVER_RIM := Color(0.22, 0.19, 0.13)     # 封皮描边=深墨
const PAGE := Color(0.92, 0.86, 0.67)          # 书页=暖亮羊皮（压掉"发白"·仍亮）
const PAGE_STACK_A := Color(0.85, 0.80, 0.63)  # 页块台阶（页厚）亮层
const PAGE_STACK_B := Color(0.76, 0.71, 0.55)  # 页块台阶 暗层

const INK := Color(0.24, 0.19, 0.12)           # 墨（亮页主文字）
const INK_DIM := Color(0.48, 0.41, 0.28)       # 淡墨（次级/划线/注记）
const CELL_DARK_FILL := Color(0.135, 0.125, 0.155)  # 深炭格四角（ref15：暗格衬亮页）
const CELL_DARK_INNER := Color(0.205, 0.19, 0.23)   # 深炭格中心（微亮·冷调）
const BANNER_PLATE := Color(0.145, 0.16, 0.28) # 牌匾底=深靛（金字在其上跳）

# 维度 → 语义色（与战斗动作按钮/抽卡同源·详情维度章用）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"), "中立": Color("8a8f98"),
	"博弈": Color("3f9a8f"), "趣味": Color("c86f8a"),
}
const DIM_FALLBACK := Color(0.42, 0.42, 0.47)

# 阶 → 稀有度色（普通蓝/稀有紫/传说金·Eddy 定）+ 标签。
const TIER_COLOR := {1: Color("4a7bc0"), 2: Color("8a4fc4"), 3: Color("dca12e")}
const TIER_LABEL := {1: "普通", 2: "稀有", 3: "传说"}

# ── 书本几何（书=居中实体·封皮包页块·夜色留边）──
const BOOK := Rect2(210, 96, 1500, 906)        # 封皮外框
const PAGE_L := Rect2(240, 128, 712, 842)      # 左页（网格）
const PAGE_R := Rect2(968, 128, 712, 842)      # 右页（详情）
const BANNER := Rect2(806, 46, 308, 78)        # 悬挂牌匾（压住书顶缘）
const TAB_W := 130.0                            # 书签页签（右缘伸出）
const TAB_H := 86.0
const TAB_X := 1684.0                           # 收起时 x（压住封皮缘）
const TAB_PULL := 18.0                          # 选中抽出量
const TAB_Y0 := 236.0
const TAB_GAP := 112.0

# ── 左页网格（六列·当前阶最多 24 件=6×4）──
const COLS := 6
const BOX := 92.0        # 道具方框（正方·icon 居中其内）
const NAME_H := 34.0     # 框【外】下方名字带高
const CARD_W := BOX
const CARD_H := BOX + NAME_H
const STEP_X := 108.0
const ROW_H := 150.0
const X0 := 282.0
const ROW_Y0 := 236.0

var _tier: int = 1
var _items: Array[ItemData] = []
var _cards: Array[Button] = []
var _sel_idx: int = -1

var _book_layer: Control          # 书本实体（一次建好·不随切阶重建）
var _tab_btns: Array[Button] = []

# 详情板部件（_build_detail_panel 一次建好）
var _d_icon: TextureRect
var _d_icon_fallback: Label
var _d_glow: TextureRect
var _d_name: Label
var _d_name_band: ColorRect
var _d_name_band_edge: ColorRect
var _d_tier_edge: ColorRect
var _d_tier_fill: ColorRect
var _d_tier_lbl: Label
var _d_desc: Label
var _d_flavor: Label

@onready var pool_area: Control = $PoolArea
@onready var detail_area: Control = $DetailArea
@onready var back_btn: Button = $TopBand/BackButton
@onready var title_lbl: Label = $TopBand/Title
@onready var count_lbl: Label = $TopBand/CountLabel


func _ready() -> void:
	_retint_background()
	_build_book()
	_setup_top()
	_build_detail_panel()
	_select_tier(1)
	_play_intro()


## 夜色衬底=深靛：duplicate 共享 codex 材质做本地覆盖
## （⚠ 不改 gallery_background.tscn 本体——英雄图鉴共用·且资源缓存会串场景污染）。
func _retint_background() -> void:
	var codex := get_node_or_null("Background/Codex") as ColorRect
	if codex == null or codex.material == null:
		return
	var mat := (codex.material as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter("top_color", NIGHT_TOP)
	mat.set_shader_parameter("bottom_color", NIGHT_BOTTOM)
	mat.set_shader_parameter("corner_color", NIGHT_CORNER)
	codex.material = mat


# ============================================================
# 书本实体（封皮 + 页块台阶 + 双页 + 中缝 + 护角 + 书签页签）
# ============================================================

func _build_book() -> void:
	_book_layer = Control.new()
	_book_layer.name = "BookLayer"
	_book_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_book_layer)
	move_child(_book_layer, 1)   # 压在 Background 之上、网格/详情之下

	# 封皮投影（书浮在夜色上·右下柔影）
	_rect(_book_layer, Rect2(BOOK.position + Vector2(10, 14), BOOK.size), Color(0.0, 0.0, 0.05, 0.35))
	# 封皮：深墨描边 + 象牙皮面（粗颗粒+边缘沉降=皮革感）
	_rect(_book_layer, Rect2(BOOK.position - Vector2(3, 3), BOOK.size + Vector2(6, 6)), COVER_RIM)
	var cover := _rect(_book_layer, BOOK, Color.WHITE)
	cover.material = _paper_mat(BOOK.size, COVER, Color(0.72, 0.68, 0.56), 0.022, 0.45, 0.68)
	# 页块台阶（页厚·底缘 + 左右外缘各两层）
	var pb := Rect2(PAGE_L.position, Vector2(PAGE_R.end.x - PAGE_L.position.x, PAGE_L.size.y))
	_rect(_book_layer, Rect2(pb.position + Vector2(-10, pb.size.y), Vector2(pb.size.x + 20, 7)), PAGE_STACK_A)
	_rect(_book_layer, Rect2(pb.position + Vector2(-5, pb.size.y + 7), Vector2(pb.size.x + 10, 5)), PAGE_STACK_B)
	for side_x: float in [pb.position.x - 10.0, pb.end.x + 4.0]:
		_rect(_book_layer, Rect2(Vector2(side_x, pb.position.y + 8), Vector2(6, pb.size.y - 4)), PAGE_STACK_A)
	# 双页（纸纹：细颗粒+边缘微沉·中心亮）
	var page_deep := Color(0.76, 0.69, 0.51)
	var pl := _rect(_book_layer, PAGE_L, Color.WHITE)
	pl.material = _paper_mat(PAGE_L.size, PAGE, page_deep, 0.016, 0.40, 0.55)
	var pr := _rect(_book_layer, PAGE_R, Color.WHITE)
	pr.material = _paper_mat(PAGE_R.size, PAGE, page_deep, 0.016, 0.40, 0.55)
	# 章名大字水印（ref18 的褪色大字·填空间不抢戏·随切阶换字见 _build_pool）
	# 中缝（装订谷·两页间垂直阴影带·由外向内加深）
	_rect(_book_layer, Rect2(Vector2(PAGE_L.end.x, PAGE_L.position.y), Vector2(PAGE_R.position.x - PAGE_L.end.x, PAGE_L.size.y)), PAGE)
	_rect(_book_layer, Rect2(Vector2(934, PAGE_L.position.y), Vector2(26, PAGE_L.size.y)), Color(0.70, 0.63, 0.47, 0.22))
	_rect(_book_layer, Rect2(Vector2(948, PAGE_L.position.y), Vector2(20, PAGE_L.size.y)), Color(0.62, 0.55, 0.40, 0.40))
	_rect(_book_layer, Rect2(Vector2(956, PAGE_L.position.y), Vector2(8, PAGE_L.size.y)), Color(0.46, 0.39, 0.27, 0.55))
	_rect(_book_layer, Rect2(Vector2(964, PAGE_L.position.y), Vector2(22, PAGE_L.size.y)), Color(0.70, 0.63, 0.47, 0.20))
	# 金属护角 ×4（封皮角·金面深边）
	for corner: Vector2 in [BOOK.position, Vector2(BOOK.end.x - 30, BOOK.position.y),
			Vector2(BOOK.position.x, BOOK.end.y - 30), BOOK.end - Vector2(30, 30)]:
		_rect(_book_layer, Rect2(corner - Vector2(2, 2), Vector2(34, 34)), COVER_RIM)
		_rect(_book_layer, Rect2(corner, Vector2(30, 30)), GOLD_MID)
		_rect(_book_layer, Rect2(corner + Vector2(7, 7), Vector2(16, 16)), Color(0.68, 0.50, 0.22))
	# 三阶书签页签（书右缘伸出·实体附件）
	_build_bookmark_tabs()


## 三阶页签=实体书签：羊皮身 + 稀有度色端带 + 墨描边；选中=抽出更长+金边+墨字。
func _build_bookmark_tabs() -> void:
	for i in 3:
		var t := i + 1
		var btn := Button.new()
		btn.name = "BookmarkTab%d" % t
		btn.position = Vector2(TAB_X, TAB_Y0 + i * TAB_GAP)
		btn.size = Vector2(TAB_W, TAB_H)
		btn.focus_mode = Control.FOCUS_NONE
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		FontManager.apply_btn(btn, 24)
		btn.text = tr(String(TIER_LABEL[t]))
		var edge := ColorRect.new()          # 墨描边
		edge.name = "Edge"
		edge.show_behind_parent = true
		edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		edge.offset_left = -2
		edge.offset_top = -2
		edge.offset_right = 2
		edge.offset_bottom = 2
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(edge)
		var fill := ColorRect.new()          # 书签身（纸纹·选中态换色走 shader 参数）
		fill.name = "Fill"
		fill.show_behind_parent = true
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.material = _paper_mat(Vector2(TAB_W, TAB_H), Color(0.84, 0.80, 0.68), Color(0.70, 0.66, 0.54), 0.02, 0.30)
		btn.add_child(fill)
		var band := ColorRect.new()          # 稀有度色端带（书签外端·一眼分阶）
		band.name = "Band"
		band.position = Vector2(TAB_W - 18, 0)
		band.size = Vector2(18, TAB_H)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.color = TIER_COLOR[t]
		btn.add_child(band)
		btn.pressed.connect(_select_tier.bind(t))
		var bj := ButtonJuice.new()
		bj.name = "ButtonJuice"
		btn.add_child(bj)
		_book_layer.add_child(btn)
		_tab_btns.append(btn)


## 刷新书签选中态：选中=抽出（x 左移）+象牙亮身+金边+墨字；未选=收进封皮下+淡墨。
func _refresh_tabs() -> void:
	for i in _tab_btns.size():
		var btn := _tab_btns[i]
		var sel := (i + 1) == _tier
		var edge := btn.get_node("Edge") as ColorRect
		var fill := btn.get_node("Fill") as ColorRect
		edge.color = Color("#f2e08a") if sel else Color(COVER_RIM, 0.9)
		var body := Color(0.97, 0.94, 0.83) if sel else Color(0.84, 0.80, 0.68)
		var fm := fill.material as ShaderMaterial
		fm.set_shader_parameter("base_color", body)
		fm.set_shader_parameter("deep_color", body.darkened(0.16))
		btn.add_theme_color_override("font_color", INK if sel else Color(INK, 0.55))
		var tx := TAB_X + (TAB_PULL if sel else 0.0)
		create_tween().tween_property(btn, "position:x", tx, 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================
# 顶部浮动件：悬挂牌匾 + 返回芯片 + 计数注记
# ============================================================

func _setup_top() -> void:
	_build_banner()
	_style_back_button()
	# 计数=左页章头行右端的墨水注记（与章头同行·像书页页眉）
	FontManager.apply(count_lbl, 18)
	count_lbl.add_theme_color_override("font_color", Color(INK_DIM, 0.9))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.position = Vector2(714, 164)
	count_lbl.size = Vector2(200, 26)


## 像素框材质（大板按尺寸折算 ≈6px/格）。
func _make_frame_mat(sz: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", COVER_RIM)
	m.set_shader_parameter("edge_mid", GOLD_MID)
	m.set_shader_parameter("edge_inner", Color(0.52, 0.38, 0.19))
	m.set_shader_parameter("pixel_grid", sz.x / 6.0)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.05)
	m.set_shader_parameter("light_amount", 0.16)
	m.set_shader_parameter("aspect", sz.x / sz.y)
	return m


## 悬挂牌匾：深靛底金框金字·压住书顶缘（ref17 的挂牌感）。
func _build_banner() -> void:
	var band := $TopBand as Control
	_rect(band, Rect2(BANNER.position + Vector2(6, 8), BANNER.size), Color(0.0, 0.0, 0.05, 0.35))
	_rect(band, Rect2(BANNER.position - Vector2(3, 3), BANNER.size + Vector2(6, 6)), COVER_RIM)
	var plate := _rect(band, BANNER, Color.WHITE)
	plate.material = _paper_mat(BANNER.size, Color(BANNER_PLATE, 0.98), Color(0.09, 0.10, 0.19), 0.03, 0.40, 0.55)
	var frame := _rect(band, BANNER, Color.WHITE)
	frame.material = _make_frame_mat(BANNER.size)
	title_lbl.text = tr("道具图鉴")
	title_lbl.position = BANNER.position + Vector2(0, -4)
	title_lbl.size = BANNER.size
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.z_index = 1
	FontManager.apply(title_lbl, 36)
	title_lbl.add_theme_color_override("font_color", GOLD_TEXT)
	title_lbl.add_theme_constant_override("outline_size", 2)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06, 0.95))


func _style_back_button() -> void:
	FontManager.apply_btn(back_btn, 24)
	back_btn.add_theme_color_override("font_color", INK)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		back_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var edge := ColorRect.new()
	edge.color = COVER_RIM
	edge.show_behind_parent = true
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.offset_left = -2
	edge.offset_top = -2
	edge.offset_right = 2
	edge.offset_bottom = 2
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击（返回失效）
	back_btn.add_child(edge)
	var backing := ColorRect.new()
	backing.color = Color(1, 1, 1, 0.98)   # 羊皮浮动芯片（夜色上亮块·与书同皮面纸纹）
	backing.show_behind_parent = true
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.material = _paper_mat(back_btn.size, COVER, Color(0.72, 0.68, 0.56), 0.02, 0.35)
	back_btn.add_child(backing)
	back_btn.pressed.connect(_back_to_menu)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	back_btn.add_child(bj)


func _rect(parent: Control, r: Rect2, col: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = col
	rect.position = r.position
	rect.size = r.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## 纸/皮质感材质（粗格颗粒+内渐变+色阶量化·颗粒粒径≈4px 时 cells=宽/4）。
func _paper_mat(sz: Vector2, base: Color, deep: Color, grain: float, shade: float, shade_start: float = 0.55) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAPER_SHADER
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("deep_color", deep)
	m.set_shader_parameter("cells_x", sz.x / 4.0)
	m.set_shader_parameter("aspect", sz.x / sz.y)
	m.set_shader_parameter("grain_amt", grain)
	m.set_shader_parameter("shade_amt", shade)
	m.set_shader_parameter("shade_start", shade_start)
	return m


# ============================================================
# 左页网格：按阶重建
# ============================================================

## 切换到某一阶：刷书签 + 重建网格 + 选中第 0 件。
func _select_tier(t: int) -> void:
	_tier = t
	_refresh_tabs()
	_items = ItemCatalog.all_for_tier(t)
	_sel_idx = -1
	_build_pool()
	count_lbl.text = tr("本页 %d 件") % _items.size()
	if not _items.is_empty():
		_select(0)


func _build_pool() -> void:
	for c in pool_area.get_children():
		c.queue_free()
	_cards.clear()
	# 章名大字水印（ref18 的褪色大字·压在左页下部空区）
	var wm := Label.new()
	wm.text = tr(String(TIER_LABEL[_tier]))
	wm.position = Vector2(PAGE_L.position.x + 120, PAGE_L.end.y - 400)
	wm.size = Vector2(480, 360)
	wm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	FontManager.apply(wm, 192)
	wm.add_theme_color_override("font_color", Color(INK, 0.055))
	wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool_area.add_child(wm)
	# 章头（ref15 的页首题字感）：阶名墨字 + 细墨线（计数注记在同行右端·见 _setup_top）
	var chapter := Label.new()
	chapter.text = tr(String(TIER_LABEL[_tier]))
	chapter.position = Vector2(X0, 150)
	chapter.size = Vector2(300, 40)
	FontManager.apply(chapter, 26)
	chapter.add_theme_color_override("font_color", INK)
	chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool_area.add_child(chapter)
	var rule := ColorRect.new()
	rule.color = Color(INK, 0.30)
	rule.position = Vector2(X0, 198)
	rule.size = Vector2(632, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool_area.add_child(rule)
	for i in _items.size():
		var card := _make_item_card(_items[i], i)
		card.position = Vector2(X0 + (i % COLS) * STEP_X, ROW_Y0 + floorf(i / float(COLS)) * ROW_H)
		pool_area.add_child(card)
		_cards.append(card)
	pool_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 单件道具卡（深炭格衬亮页·稀有度框·图标自己跳）。选中=金框由 _select 刷。
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
	# 格底：深炭中性格（ref15——亮页上的暗格·彩色图标自己跳）；传说铺金云纹美术。
	var cell := ColorRect.new()
	cell.color = Color.WHITE
	cell.position = Vector2.ZERO
	cell.size = Vector2(BOX, BOX)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ShaderMaterial.new()
	cm.shader = CELL_BG_SHADER
	cm.set_shader_parameter("fill_color", CELL_DARK_FILL)
	cm.set_shader_parameter("inner_color", CELL_DARK_INNER)
	cm.set_shader_parameter("center_glow", 1.0)
	cm.set_shader_parameter("corner_radius", 0.18)
	cm.set_shader_parameter("pixel_grid", BOX / 6.0)
	if item.tier == 3:
		cm.set_shader_parameter("use_tex", 1.0)
		cm.set_shader_parameter("bg_tex", LEGENDARY_BG)
		cm.set_shader_parameter("tex_tint", LEGENDARY_BG_TINT)
	cm.set_shader_parameter("cloud_on", 0.0)
	cell.material = cm
	card.add_child(cell)
	# 像素框（边=稀有度色·圆角）
	var frame := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", COVER_RIM)
	m.set_shader_parameter("edge_mid", rc)
	m.set_shader_parameter("edge_inner", rc.darkened(0.45))
	m.set_shader_parameter("pixel_grid", BOX / 6.0)
	m.set_shader_parameter("border_px", 2.0)
	m.set_shader_parameter("noise_amt", 0.05)
	m.set_shader_parameter("light_amount", 0.18)
	m.set_shader_parameter("aspect", 1.0)
	m.set_shader_parameter("corner_radius", 0.18)
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
		var isz := 70.0
		icon.position = Vector2((BOX - isz) * 0.5, (BOX - isz) * 0.5)
		icon.size = Vector2(isz, isz)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
	# 名字（框外下方·亮页墨字直读）
	var name_lbl := Label.new()
	name_lbl.text = tr(item.item_name)
	name_lbl.position = Vector2(-12.0, BOX + 2.0)
	name_lbl.size = Vector2(BOX + 24.0, NAME_H)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FontManager.apply(name_lbl, 16)
	name_lbl.add_theme_color_override("font_color", INK)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)
	card.pressed.connect(_select.bind(idx))
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	card.add_child(bj)
	return card


# ============================================================
# 右页：稀有度横幅 + 图标卡 + 划线手记（ref18 感觉）
# ============================================================

func _build_detail_panel() -> void:
	var px := PAGE_R.position.x
	var py := PAGE_R.position.y
	# 页内细饰框（ref15 右页的仪式感·细墨线不抢戏）
	var inset := Rect2(px + 26, py + 26, PAGE_R.size.x - 52, PAGE_R.size.y - 52)
	for er: Rect2 in [
			Rect2(inset.position, Vector2(inset.size.x, 1)),
			Rect2(Vector2(inset.position.x, inset.end.y), Vector2(inset.size.x, 1)),
			Rect2(inset.position, Vector2(1, inset.size.y)),
			Rect2(Vector2(inset.end.x, inset.position.y), Vector2(1, inset.size.y))]:
		_rect(detail_area, er, Color(INK, 0.28))

	# ── ① 稀有度横幅（道具名·白字深边·随稀有度换色）──
	_d_name_band_edge = _rect(detail_area, Rect2(px + 54, py + 62, PAGE_R.size.x - 108, 64), COVER_RIM)
	_d_name_band = _rect(detail_area, Rect2(px + 57, py + 65, PAGE_R.size.x - 114, 58), TIER_COLOR[1])
	_d_name = _make_label(Vector2(px + 57, py + 65), Vector2(PAGE_R.size.x - 114, 58), 32, Color.WHITE)
	_d_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_name.add_theme_constant_override("outline_size", 4)
	_d_name.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))

	# ── ② 图标卡：钉在页上的层叠卡（偏移投影+墨线框）+ 暖辉光 + 放大图标 ──
	var card := Rect2(px + (PAGE_R.size.x - 380) * 0.5, py + 170, 380, 380)
	_rect(detail_area, Rect2(card.position + Vector2(8, 10), card.size), Color(0.30, 0.26, 0.16, 0.35))  # 卡投影
	_rect(detail_area, Rect2(card.position - Vector2(2, 2), card.size + Vector2(4, 4)), Color(INK, 0.75)) # 墨线框
	var card_face := _rect(detail_area, card, Color.WHITE)                                                # 卡面（比页更亮一档·细纸纹）
	card_face.material = _paper_mat(card.size, Color(0.97, 0.94, 0.82), Color(0.87, 0.83, 0.67), 0.012, 0.30)

	_d_glow = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.90, 0.55, 0.38))
	grad.set_color(1, Color(1.0, 0.90, 0.55, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 256
	gtex.height = 256
	_d_glow.texture = gtex
	_d_glow.position = card.position + card.size * 0.5 - Vector2(170, 170)
	_d_glow.size = Vector2(340, 340)
	_d_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_glow)

	# 放大图标（128px 源 → NEAREST 像素清晰）
	_d_icon = TextureRect.new()
	_d_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_icon.size = Vector2(300, 300)
	_d_icon.position = card.position + (card.size - _d_icon.size) * 0.5
	_d_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_icon)
	_d_icon_fallback = _make_label(card.position, card.size, 48, Color(INK, 0.6))
	_d_icon_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_icon_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_icon_fallback.visible = false

	# ── ③ 阶章（居中药丸）──
	_d_tier_edge = _chip_rect(Color(INK, 0.75))
	_d_tier_fill = _chip_rect(TIER_COLOR[1])
	_d_tier_lbl = _make_label(Vector2.ZERO, Vector2(120, 36), 18, Color.WHITE)
	_d_tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chip_text_outline(_d_tier_lbl)

	# ── ④ 手记段：描述写在划线上（ref18 的手记感）+ 风味淡墨 ──
	for i in 3:
		_rect(detail_area, Rect2(px + 90, py + 686 + i * 36, PAGE_R.size.x - 180, 1), Color(INK, 0.20))
	_d_desc = _make_label(
		Vector2(px + 96, py + 636),
		Vector2(PAGE_R.size.x - 192, 108), 18, INK)
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_d_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_flavor = _make_label(
		Vector2(px + 96, py + 756),
		Vector2(PAGE_R.size.x - 192, 60), 16, Color(INK_DIM, 0.95))
	_d_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_flavor.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_d_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 快捷键提示：夜色上·书外底部（不占书页）
	var hint := _make_label(Vector2(0, 1038), Vector2(1920, 24), 14, Color(IVORY, 0.5))
	hint.text = tr("← → 切换道具 · 普通/稀有/传说 切阶 · ESC 返回")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _chip_rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(r)
	return r


## 章内白字补深描边 → 在金/蓝/紫任何饱和底色上都读得清。
func _chip_text_outline(lbl: Label) -> void:
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))


## 选中某件道具：左卡换金框 + 右页填充（横幅换稀有度色 / 图标 / 阶章 / 手记）。
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
	var rc: Color = TIER_COLOR[it.tier]
	var tex: Texture2D = ItemCatalog.load_icon(it.item_id)
	if tex != null:
		_d_icon.texture = tex
		_d_icon.visible = true
		_d_icon_fallback.visible = false
	else:
		_d_icon.visible = false
		_d_icon_fallback.text = tr(it.item_name)
		_d_icon_fallback.visible = true
	_d_name.text = tr(it.item_name)
	_d_name_band.color = rc
	_d_tier_lbl.text = tr(String(TIER_LABEL[it.tier]))
	_d_tier_fill.color = rc
	_d_desc.text = tr(it.description)
	_d_flavor.text = tr(it.flavor)
	_layout_chips()


## 阶章在页内水平居中（章宽随文字 → 每次按内容重排）。
## 维度章不对玩家展示（内部设计分类·含设计术语·Eddy 2026-06-30）。
func _layout_chips() -> void:
	var y0: float = PAGE_R.position.y + 578
	var f: Font = _d_tier_lbl.get_theme_font("font")
	var fs: int = _d_tier_lbl.get_theme_font_size("font_size")
	var w1: float = f.get_string_size(_d_tier_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 40.0
	var x0: float = PAGE_R.position.x + (PAGE_R.size.x - w1) * 0.5
	_d_tier_edge.position = Vector2(x0, y0)
	_d_tier_edge.size = Vector2(w1, 38)
	_d_tier_fill.position = Vector2(x0 + 1, y0 + 1)
	_d_tier_fill.size = Vector2(w1 - 2, 36)
	_d_tier_lbl.position = Vector2(x0, y0)
	_d_tier_lbl.size = Vector2(w1, 38)


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


## 战斗内嵌模式（battle_codex_overlay 注入）：有效时「返回/ESC」改走关闭浮层，不切场景。
var embedded_close: Callable = Callable()


func _back_to_menu() -> void:
	if embedded_close.is_valid():
		embedded_close.call()
		return
	TransitionManager.transition_to(MENU_SCENE)


## 入场：牌匾/返回滑入 + 书轻微上浮 + 左页卡按行翻开扫过 + 右页淡入。
func _play_intro() -> void:
	var band := $TopBand as Control
	var band_home := band.position
	band.position.y -= 130.0
	create_tween().tween_property(band, "position", band_home, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_book_layer.position.y += 26.0
	_book_layer.modulate.a = 0.0
	var tb := create_tween()
	tb.set_parallel(true)
	tb.tween_property(_book_layer, "position:y", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tb.tween_property(_book_layer, "modulate:a", 1.0, 0.25)
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

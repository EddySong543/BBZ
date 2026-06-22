extends Control

## 英雄图鉴 v2（2026-06-12 Eddy 改版：列表左 / 详情右常驻，弃中央浮窗）。
## 左 = 15 卡六列网格（BP 牌库同缩放 0.846·同语言霜玻璃）；点卡=选中（金框）。
## 右 = 常驻详情板（像素框）：**idle 动画实时播放**（sprite_frames 同战斗资源）+
##      名字 / 主题归属 / ❤生命 + 主(红)/被(蓝)标签 + 技能名 + 技能详述。
## ←/→ 环绕换人（↑/↓ = ±一行），ESC / 返回钮 → 波幕转场回主菜单。
## ⚠ 返回钮的装饰 ColorRect 必须 mouse_filter=IGNORE——v1 的描边矩形默认 STOP
##   吞掉了点击导致"返回失效"（2026-06-12 修）。

const HERO_CARD_SCENE := preload("res://src/ui/components/hero_card.tscn")
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")
const HEART_SHEET := preload("res://assets/ui/icons/heart_idle.png")

const HERO_DATA_DIR := "res://assets/data/heroes/"
const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 左侧牌库网格（15 卡 0.846 缩放=110×134·六列固定网格 6+6+3）──
const CARD_SCALE := 0.846
const POOL := Rect2(60, 140, 1032, 900)
const COLS := 6   # 6 列固定网格（后续加英雄按行增长，不随张数改列）；首发 15 = 6+6+3 三行
const STEP_X := 121.0
const ROW_H := 142.0
const X0 := 218.0   # 6 卡在 POOL(60..1092) 内水平居中（整数取位保像素硬边）
const ROW_Y0 := 186.0

# ── 右侧详情板 ──
const PANEL := Rect2(1132, 140, 728, 900)

# 配色（典籍朱印·暖羊皮+墨线+金箔+朱印）
# 暗底上的中性框 = 暖骨边（outer/mid/inner 三层·替代旧板岩银灰）
const EDGE_OUTER := Color(0.05, 0.045, 0.04)
const EDGE_MID := Color(0.70, 0.64, 0.52)
const EDGE_INNER := Color(0.42, 0.36, 0.26)
const GOLD_TEXT := Color("#f4c84b")
const TIN_DIM := Color(0.80, 0.74, 0.60)   # 压暗底次级文字=暖米白次级（替代旧冷锡灰 #aab4c4）
const ACTIVE_TAG := Color(0.74, 0.24, 0.18)    # 主动=朱砂（进攻）
const PASSIVE_TAG := Color(0.40, 0.50, 0.62)   # 被动=去饱和冷蓝（恒常）

# 典籍朱印补充令牌
const DARK_WARM := Color(0.09, 0.085, 0.075)   # 近黑暖暗底（详情板底/牌匾/徽章衬底大暗面）
const INK_LINE := Color(0.18, 0.12, 0.07)      # 墨线
const PARCHMENT_HI := Color(0.95, 0.91, 0.80)  # 暖米白（压暗底主文字）

# 顶带「典籍牌匾」落位
const PLAQUE := Rect2(800, 26, 320, 64)

var all_heroes: Array[HeroData] = []
var card_cards: Array[HeroCard] = []
var _sel_idx: int = -1

# 详情板部件（_build_detail_panel 一次建好）
var _d_anim: AnimatedSprite2D
var _d_fallback: TextureRect      # 无 idle 资源时的静态头像兜底
var _d_name: Label
var _d_theme: Label
var _d_hp_num: Label
var _d_tag: Label
var _d_tag_bg: ColorRect
var _d_skill_name: Label
var _d_detail: Label
var _d_watermark: Label           # 舞台大编号水印（格斗选人语言·极淡）
var _d_glow: TextureRect          # 立绘背后主题色径向衬光（modulate=三系色）
var _d_chip1_edge: ColorRect      # 编号章（No.XX）
var _d_chip1_fill: ColorRect
var _d_chip1_lbl: Label
var _d_chip2_edge: ColorRect      # 生命章（❤+数字）
var _d_chip2_fill: ColorRect
var _d_hp_heart: TextureRect
var _row_glow: ColorRect          # 左网格选中行微亮条（键盘导航定位）

@onready var pool_area: Control = $PoolArea
@onready var detail_area: Control = $DetailArea
@onready var back_btn: Button = $TopBand/BackButton
@onready var title_lbl: Label = $TopBand/Title


func _ready() -> void:
	all_heroes = HeroData.create_launch_pool(HERO_DATA_DIR)   # 首发 15（12 生肖 + 黑暗子鼠/丑牛/寅虎）
	_setup_top()
	_build_pool()
	_build_detail_panel()
	_select(0)
	_play_intro()


func _setup_top() -> void:
	_build_plaque()
	_build_collect_badge()

	FontManager.apply_btn(back_btn, 24)
	back_btn.add_theme_color_override("font_color", PARCHMENT_HI)   # 暖米白（压暗底）
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
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击（返回失效 bug）
	back_btn.add_child(edge)
	var backing := ColorRect.new()
	backing.color = Color(DARK_WARM, 0.92)   # 近黑暖暗底
	backing.show_behind_parent = true
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_btn.add_child(backing)
	back_btn.pressed.connect(_back_to_menu)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	back_btn.add_child(bj)


## 顶带「典籍牌匾」：标题装进横幅像素框（mode_card 名牌带同语言）+ 左右卷轴端头
## 饰线 + 匾顶小王冠图记——图鉴的"书脊标签"（书感取其形不取其皮，材质仍走牌桌语言）。
func _build_plaque() -> void:
	var band := $TopBand as Control
	# 牌匾三层：黑衬底 → 深色填充 → 像素框
	var backing := _band_rect(band, PLAQUE, EDGE_OUTER)
	backing.name = "PlaqueBacking"
	var fill := _band_rect(band,
		Rect2(PLAQUE.position + Vector2(3, 3), PLAQUE.size - Vector2(6, 6)),
		Color(DARK_WARM, 0.97))   # 近黑暖暗底
	fill.name = "PlaqueFill"
	var frame := _band_rect(band, PLAQUE, Color.WHITE)
	frame.name = "PlaqueFrame"
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", EDGE_MID)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	m.set_shader_parameter("pixel_grid", PLAQUE.size.x / 6.0)   # 大板折算 ≈6px/格
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("light_amount", 0.13)
	m.set_shader_parameter("aspect", PLAQUE.size.x / PLAQUE.size.y)
	frame.material = m
	# 标题挪进匾内（tscn 落位被代码接管·牌匾整体随顶带滑入）。
	# y-4：Ark 像素汉字无下伸部但 Label 居中按全字体度量 → 视觉偏下，上提补正（实测定值）。
	title_lbl.position = PLAQUE.position + Vector2(0, -4)
	title_lbl.size = PLAQUE.size
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.z_index = 1   # 压住后建的牌匾层
	FontManager.apply(title_lbl, 36)
	title_lbl.add_theme_color_override("font_color", GOLD_TEXT)
	title_lbl.add_theme_constant_override("outline_size", 2)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))   # 暖近黑描边（衬金字）
	# 匾顶小王冠已移除（2026-06-13 Eddy：王冠只用于标题/logo，不做通用 UI 装饰）。
	# 左右卷轴端头饰线（端头方块 + 细线·与匾垂直居中对齐）
	var line_y := PLAQUE.position.y + PLAQUE.size.y * 0.5 - 1.0
	for side: Array in [
			[Rect2(612, line_y, 168, 2), Rect2(604, line_y - 3, 8, 8)],
			[Rect2(PLAQUE.end.x + 20, line_y, 168, 2), Rect2(PLAQUE.end.x + 188, line_y - 3, 8, 8)]]:
		_band_rect(band, side[0], Color(EDGE_MID, 0.45))
		_band_rect(band, side[1], Color(EDGE_MID, 0.7))


## 右上「收集度徽章」：英雄 icon + N / N + 细进度条——为后期图鉴解锁/收集留语义
## （现在全解锁=满条），替代裸文本"共 46 名英雄"。
func _build_collect_badge() -> void:
	var band := $TopBand as Control
	var plate := Rect2(1620, 30, 240, 50)
	var edge := _band_rect(band, plate, Color(EDGE_INNER, 0.6))
	edge.name = "BadgeEdge"
	var fill := _band_rect(band,
		Rect2(plate.position + Vector2(2, 2), plate.size - Vector2(4, 4)),
		Color(DARK_WARM, 0.94))   # 近黑暖暗底
	fill.name = "BadgeFill"
	var icon := TextureRect.new()
	icon.name = "BadgeIcon"
	icon.texture = PixelGlyphs.icon_texture("hero")
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = Vector2(1634, 39)
	icon.size = Vector2(32, 32)
	icon.modulate = PARCHMENT_HI   # 暖米白（压暗底 icon）
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(icon)
	# 计数标签（tscn 节点挪进徽章内）
	var count := $TopBand/CountLabel as Label
	count.position = Vector2(1676, 35)
	count.size = Vector2(164, 24)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.z_index = 1
	FontManager.apply(count, 20)
	count.add_theme_color_override("font_color", Color(TIN_DIM, 0.95))
	count.text = "%d / %d" % [all_heroes.size(), all_heroes.size()]
	# 收集进度条（现=满）
	var ratio := 1.0
	_band_rect(band, Rect2(1676, 63, 164, 6), Color(1, 1, 1, 0.10))
	_band_rect(band, Rect2(1676, 63, 164.0 * ratio, 6), Color(GOLD_TEXT, 0.8))


func _band_rect(parent: Control, r: Rect2, col: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = col
	rect.position = r.position
	rect.size = r.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## 左侧牌库（bp 同源霜玻璃 + 0.846 六列网格）。
## 2026-06-13 Eddy：去除三系图例带 + 每卡顶主题色细线（早期生肖/阿卡那/星座标记已全部移除）。
## 保留选中行微亮条（键盘导航行定位）。
func _build_pool() -> void:
	_make_frosted(pool_area, POOL)
	# 行亮条（先建=画在卡下层）
	_row_glow = ColorRect.new()
	_row_glow.color = Color(1, 1, 1, 0.045)
	_row_glow.position = Vector2(85, ROW_Y0 - 3)
	_row_glow.size = Vector2(982, 140)
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
		# 主题色顶线已移除（2026-06-13 Eddy：三系标记待"另一套标记"替代）。
		var bj := card.get_node_or_null("ButtonJuice") as ButtonJuice
		if bj:
			bj.base_scale = CARD_SCALE
		card_cards.append(card)
	pool_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 右侧常驻详情板（像素框）：上=idle 动画舞台，下=文字属性。
func _build_detail_panel() -> void:
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = PANEL.position
	backing.size = PANEL.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(backing)
	var fill := ColorRect.new()
	fill.color = Color(DARK_WARM, 0.97)   # 近黑暖暗底（详情板大暗面保留为暗）
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
	# pixel_grid=横向格数：大板必须按尺寸折算（≈6px/格·mode_card 同法），
	# 直接抄卡片的 23 会把格子放大到 32px → 边框糊成厚条
	m.set_shader_parameter("pixel_grid", PANEL.size.x / 6.0)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	m.set_shader_parameter("light_amount", 0.13)
	frame.material = m
	frame.position = PANEL.position
	frame.size = PANEL.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(frame)

	# ── ① 舞台段：暗井衬底 + 大编号水印 + 主题色衬光 + 台座投影 + idle 动画 ──
	var stage := ColorRect.new()
	stage.color = Color(0.04, 0.035, 0.03, 0.85)   # 近黑暖·舞台暗井（去旧冷蓝、保留为暗）
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

	# 大编号水印（格斗选人语言·α 极淡压在暗井上）。192=16 基底 ×12 整数倍（防糊）
	_d_watermark = _make_label(stage.position, stage.size, 192, Color(1, 1, 1, 0.05))
	_d_watermark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_watermark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 主题色径向衬光（白→透明纹理 + modulate 上三系色·立绘背后一圈柔光）
	_d_glow = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.16))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 256
	gtex.height = 256
	_d_glow.texture = gtex
	_d_glow.position = stage.position + Vector2(30, 50)   # 中心≈立绘中心
	_d_glow.size = Vector2(380, 380)
	_d_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_glow)

	# 台座投影（黑→透明径向椭圆·立绘脚下）
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
	shadow.position = stage.position + Vector2(80, 414)   # 脚位 y≈436（中心 y436）
	shadow.size = Vector2(280, 44)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(shadow)

	_d_anim = AnimatedSprite2D.new()
	_d_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_anim.position = stage.position + stage.size * 0.5 + Vector2(0, 24)
	_d_anim.scale = Vector2(1.5, 1.5)   # 256px 帧 → 384px
	detail_area.add_child(_d_anim)
	_d_fallback = TextureRect.new()
	_d_fallback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_fallback.position = stage.position + Vector2(70, 70)
	_d_fallback.size = stage.size - Vector2(140, 140)
	_d_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_fallback.visible = false
	detail_area.add_child(_d_fallback)

	var px := PANEL.position.x
	var py := PANEL.position.y

	# 名牌横带：紧贴舞台底沿（台座名牌·mode_card 名牌带同语言）——名字"长"在舞台上
	var band_r := Rect2(stage.position.x, stage.position.y + stage.size.y, stage.size.x, 64)
	var band_fill := ColorRect.new()
	band_fill.color = Color(0, 0, 0, 0.45)
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
	# 32=f16×2 整数倍（34 非整倍数→回退 f12 放大=虚细，2026-06-13 Eddy"太细太小"根修）。
	_d_name = _make_label(band_r.position + Vector2(0, 4), Vector2(band_r.size.x, 36), 32, GOLD_TEXT)
	_d_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_name.add_theme_constant_override("outline_size", 1)
	_d_name.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))   # 暖近黑描边（衬金字）
	_d_theme = _make_label(band_r.position + Vector2(0, 40), Vector2(band_r.size.x, 20), 14, Color(TIN_DIM, 0.85))
	_d_theme.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_theme.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# ── ② 数据段：编号章 + 生命章（两枚药丸章成组居中·_layout_data_chips 按内容重排）──
	_d_chip1_edge = _chip_rect(Color(EDGE_INNER, 0.55))
	_d_chip1_fill = _chip_rect(Color(0, 0, 0, 0.35))
	_d_chip1_lbl = _make_label(Vector2.ZERO, Vector2(120, 34), 16, PARCHMENT_HI)   # 暖米白（压暗底 chip）
	_d_chip1_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_chip1_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_chip2_edge = _chip_rect(Color(EDGE_INNER, 0.55))
	_d_chip2_fill = _chip_rect(Color(0, 0, 0, 0.35))
	_d_hp_heart = TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = HEART_SHEET
	atlas.region = Rect2(0, 0, HEART_SHEET.get_width() / 4.0, HEART_SHEET.get_height())
	_d_hp_heart.texture = atlas
	_d_hp_heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_hp_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # ⚠ 缺这行=被帧原尺寸顶大掉出章外
	_d_hp_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_hp_heart.size = Vector2(26, 26)
	_d_hp_heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_hp_heart)
	_d_hp_num = _make_label(Vector2.ZERO, Vector2(60, 34), 20, Color("#e0584a"))   # 暖朱红（生命数·朱砂系亮调）
	_d_hp_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 段间分隔线
	var sep := ColorRect.new()
	sep.color = Color(EDGE_MID, 0.22)
	sep.position = Vector2(px + 120, py + 634)
	sep.size = Vector2(PANEL.size.x - 240, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(sep)

	# ── ③ 技能段：标签印 + 技能名（一行居中组）+ 霜玻璃详述盒 ──
	_d_tag_bg = ColorRect.new()
	_d_tag_bg.size = Vector2(64, 30)
	_d_tag_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_tag_bg)
	_d_tag = _make_label(Vector2.ZERO, Vector2(64, 24), 16, Color.WHITE)
	_d_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_skill_name = _make_label(Vector2.ZERO, Vector2(300, 30), 24, PARCHMENT_HI)   # 暖米白（压暗底）
	_make_frosted(detail_area, Rect2(px + 70, py + 696, PANEL.size.x - 140, 130))
	_d_detail = _make_label(Vector2(px + 86, py + 710), Vector2(PANEL.size.x - 172, 104), 16, TIN_DIM)   # 暖米白次级（压详述盒暗底）
	_d_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_d_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var hint := _make_label(Vector2(px, py + PANEL.size.y - 40), Vector2(PANEL.size.x, 24), 14, Color(TIN_DIM, 0.55))
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
	_d_theme.text = ""   # 三系归属已移除（2026-06-13 Eddy：待"另一套标记"替代）
	_d_watermark.text = "%02d" % (idx + 1)
	_d_glow.modulate = Color(0.92, 0.84, 0.62)   # 暖金中性衬光（典籍朱印·替代旧冷调）
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
	var row_y := ROW_Y0 - 3 + floorf(idx / float(COLS)) * ROW_H
	create_tween().tween_property(_row_glow, "position:y", row_y, 0.18)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 编号章+生命章作为一组在板内水平居中（编号/血量宽度可变 → 每次按内容重排）。
func _layout_data_chips() -> void:
	var y0: float = PANEL.position.y + 584
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


## 标签+技能名作为一组在板内水平居中（技能名长短不一 → 每次按内容重排）。
func _layout_skill_row() -> void:
	var f: Font = _d_skill_name.get_theme_font("font")
	var fs: int = _d_skill_name.get_theme_font_size("font_size")
	var name_w: float = f.get_string_size(_d_skill_name.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total: float = 64.0 + 12.0 + name_w
	var x0: float = PANEL.position.x + (PANEL.size.x - total) * 0.5
	var y0: float = PANEL.position.y + 652
	_d_tag_bg.position = Vector2(x0, y0)
	_d_tag.position = Vector2(x0, y0 + 3)
	_d_skill_name.position = Vector2(x0 + 76, y0)
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


## 入场：顶带滑入 + 左侧牌按行翻开扫过（bp C1 同语言）+ 右板淡入。
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
# 自绘部件（bp 同源）
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


## 典籍暗格（原霜玻璃桌面）：墨线细边 + 近黑暖暗底（替代旧月光青+冷暗底）。
func _make_frosted(parent: Control, r: Rect2) -> void:
	var border := ColorRect.new()
	border.color = Color(INK_LINE, 0.55)   # 墨线
	border.position = r.position
	border.size = r.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(border)
	var fill := ColorRect.new()
	fill.color = Color(DARK_WARM, 0.55)   # 近黑暖暗底
	fill.position = r.position + Vector2(2, 2)
	fill.size = r.size - Vector2(4, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)

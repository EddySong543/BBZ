extends Control

## 英雄图鉴（2026-07-15 回纹卷轴换装：整屏套用道具图鉴模板——任务B）。
## 模板=item_gallery_screen（宣纸山水衬底+墨云带+整屏手卷+牌匾贴形投影+右页单列主轴+金晕选中），
## 英雄内容适配：左页=回纹头像框网格（HeroFrame·道具图鉴同几何）；右页=384 大展示格（头像框资产
## ×3 整数放大·内放 idle 动画）+ No./❤生命/主被动章行 + 技能名 + 描述墨字。
## 旧 v4「暖深底+鎏金浮雕」外壳（酒红书页/凹陷展板/铆钉/宝石/书脊/收集徽章/行亮条）全退役。
## 选中=金晕外环+轻暖提亮（战斗点选/道具图鉴同语言·亮纸深金档）——⛔不用 HeroFrame.is_selected
## （那是战斗换人的冷亮蓝白语言·压在宣纸上打架；组件本体是战斗共用件不动）。
## ⚠ 装饰节点必须 mouse_filter=IGNORE——否则吞点击（返回失效·v1 踩过坑）。

const HERO_FRAME_SCENE := preload("res://src/ui/components/hero_frame.tscn")   # 回纹头像框（网格格子）
const AVATAR_FRAME_TEX := preload("res://assets/ui/hero_avatar_frame.png")     # 右页大展示格框（128px 暖骨回纹·×3 整数放大）
const PLAQUE_TEX := preload("res://assets/ui/ui_plaque.png")                   # 悬挂牌匾（320×62·9-slice·三挂点共用）
const SCROLL_TEX := preload("res://assets/ui/item_codex_scroll.png")           # 整屏手卷（道具图鉴同源·1672×941 拉伸满屏）
const BACKDROP_TEX := preload("res://assets/ui/item_codex_backdrop.png")       # 衬底=宣纸淡墨山水（道具图鉴同源）
const INK_CLOUDS_SHADER := preload("res://assets/shaders/canvas_ui_ink_clouds.gdshader")
const CELL_BG_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")   # 选中金晕外环
const BANNER_TEX := preload("res://assets/ui/ui_banner_scroll.png")            # 英雄名小卷轴横幅（右页）
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")            # 返回钮=导航钮同皮
const NAV_PLATE_MARGIN_X := 22   # v14（main_menu 同值）
const NAV_PLATE_MARGIN_Y := 20
const HEART_SHEET := preload("res://assets/ui/icons/heart_idle.png")

const HERO_DATA_DIR := "res://assets/data/heroes/"
const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 墨字（宣纸亮页·道具图鉴同值）──
const INK := Color(0.24, 0.19, 0.12)
const INK_DIM := Color(0.48, 0.41, 0.28)
const HP_INK := Color("a83a2c")                # 生命数=朱墨（❤旁·纸上深红读得清）
const ACTIVE_TAG := Color(0.78, 0.26, 0.19)    # 主动=朱砂印（章底色·白字深描边）
const PASSIVE_TAG := Color(0.30, 0.45, 0.63)   # 被动=靛蓝印

# ── 选中态（道具图鉴/战斗点选同语言·亮纸档金）──
const GOLD_SEL := Color("dca12e")
const RING_PAD := 6.0
const SEL_TINT := Color(1.18, 1.10, 0.98)

# ── 卷轴几何（道具图鉴同值）──
const PAGE_L := Rect2(240, 128, 712, 842)
const PAGE_R := Rect2(968, 128, 712, 842)
const BANNER := Rect2(806, 46, 308, 78)

# ── 左页网格（道具图鉴同几何：6 列·92 框+34 名字带·24 英雄=6×4）──
const COLS := 6
const BOX := 92.0
const NAME_H := 34.0
const STEP_X := 108.0
const ROW_H := 150.0
const X0 := 282.0
const ROW_Y0 := 236.0

# ── 右页大展示格（128px 头像框资产 ×3=384 整数放大保像素）──
const CELL := 384.0
const CELL_FILL := Color("221c15")     # 格底四角=暖深（比框深·HeroFrame 内衬同族）
const CELL_CENTER := Color("2e2720")   # 格底中心=略浅暖深（层次感·仍暗于框）

var all_heroes: Array[HeroData] = []
var card_cards: Array[Button] = []        # 格子点击壳（入场动画/ButtonJuice 挂这层）
var card_frames: Array[HeroFrame] = []    # 回纹头像框（探针 gallery_click_probe 锁 mouse_filter）
var _sel_idx: int = -1
var _sel_tweens: Array[Tween] = []        # 选中动效 tween（pop+呼吸·换选先 kill 全部）
var _pop_tween: Tween                     # 右页展示落位微弹

var _book_layer: Control                  # 卷轴实体（入场上浮层）

# 详情板部件（_build_detail_panel 一次建好）
var _d_anim: AnimatedSprite2D
var _d_fallback: TextureRect      # 无 idle 资源时的静态头像兜底
var _d_name: Label
var _d_no_lbl: Label
var _d_hp_heart: TextureRect
var _d_hp_num: Label
var _d_tag_edge: ColorRect
var _d_tag_bg: ColorRect
var _d_tag: Label
var _d_skill_name: Label
var _d_skill_icon: TextureRect
var _d_detail: Label

@onready var pool_area: Control = $PoolArea
@onready var detail_area: Control = $DetailArea
@onready var back_btn: Button = $TopBand/BackButton
@onready var title_lbl: Label = $TopBand/Title
@onready var count_lbl: Label = $TopBand/CountLabel


func _ready() -> void:
	all_heroes = HeroData.create_launch_pool(HERO_DATA_DIR)   # 首发 24（h01-h24）
	_build_book()
	_setup_top()
	_build_pool()
	_build_detail_panel()
	_select(0)
	_play_intro()


# ============================================================
# 卷轴实体（道具图鉴同配方：衬底+墨云带+整屏手卷·无三阶页签）
# ============================================================

func _build_book() -> void:
	# 战斗内嵌模式：不带任何背景——卷轴直接悬在浮层暗幕上（与道具图鉴一致）。
	var embedded := embedded_close.is_valid()
	if embedded:
		var bg := get_node_or_null("Background") as Control
		if bg != null:
			bg.visible = false
	else:
		# 衬底=宣纸淡墨山水（独立静态层·不进 _book_layer——入场上浮不带背景飞）。
		var backdrop := TextureRect.new()
		backdrop.name = "Backdrop"
		backdrop.texture = BACKDROP_TEX
		backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 软笔触画面非像素资产
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_SCALE
		backdrop.position = Vector2.ZERO
		backdrop.size = Vector2(1920.0, 1080.0)   # ⚠ 锚点满铺在程序容器下会塌 0，必须显式尺寸
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop)
		move_child(backdrop, 1)   # Background 之上（不透明满屏整层盖住）
		# 像素墨云带（上下环绕·两条横带 quad ⛔全屏 shader·种子互异）
		_add_ink_cloud_band(Rect2(0, 0, 1920, 150), 0.37, 0.0, 0.03, 2)
		_add_ink_cloud_band(Rect2(0, 930, 1920, 150), 0.63, 5.0, -0.025, 3)

	_book_layer = Control.new()
	_book_layer.name = "BookLayer"
	_book_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_book_layer)
	move_child(_book_layer, 1 if embedded else 4)

	var scroll := TextureRect.new()
	scroll.name = "Scroll"
	scroll.texture = SCROLL_TEX
	scroll.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scroll.stretch_mode = TextureRect.STRETCH_SCALE
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(1920.0, 1080.0)   # ⚠ _book_layer 零尺寸 Control——必须显式尺寸
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_layer.add_child(scroll)


## 像素墨云横带（道具图鉴同参：center_frac=垂直中心·seed 上下互异·flow=流速）。
func _add_ink_cloud_band(r: Rect2, center_frac: float, seed_v: float, flow: float, tree_idx: int) -> void:
	var band := ColorRect.new()
	band.name = "InkCloudsTop" if r.position.y < 540.0 else "InkCloudsBottom"
	band.color = Color.WHITE
	band.position = r.position
	band.size = r.size
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = INK_CLOUDS_SHADER
	m.set_shader_parameter("center_frac", center_frac)
	m.set_shader_parameter("seed", seed_v)
	m.set_shader_parameter("flow_speed", flow)
	band.material = m
	add_child(band)
	move_child(band, tree_idx)


# ============================================================
# 顶部浮动件：悬挂牌匾（贴形投影）+ 返回钮（导航皮）+ 页眉计数
# ============================================================

func _setup_top() -> void:
	_build_plaque()
	_style_back_button()
	# 计数=左页章头行右端的墨水注记（与章头同行·像书页页眉）
	FontManager.apply(count_lbl, 18)
	count_lbl.add_theme_color_override("font_color", Color(INK_DIM, 0.9))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.position = Vector2(714, 164)
	count_lbl.size = Vector2(200, 26)
	count_lbl.text = tr("共 %d 位") % all_heroes.size()


## 悬挂牌匾（道具图鉴同配方：贴图剪影投影+9-slice+墨字）。
func _build_plaque() -> void:
	var band := $TopBand as Control
	var shadow := NinePatchRect.new()
	shadow.name = "PlaqueShadow"
	shadow.texture = PLAQUE_TEX
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.patch_margin_left = 50
	shadow.patch_margin_right = 50
	shadow.patch_margin_top = 20
	shadow.patch_margin_bottom = 20
	shadow.position = BANNER.position + Vector2(6, 8)
	shadow.size = BANNER.size
	shadow.modulate = Color(0.10, 0.07, 0.05, 0.38)   # 暖黑剪影（宣纸暖底同温）
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(shadow)
	var plaque := NinePatchRect.new()
	plaque.name = "Plaque"
	plaque.texture = PLAQUE_TEX
	plaque.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaque.patch_margin_left = 50
	plaque.patch_margin_right = 50
	plaque.patch_margin_top = 20
	plaque.patch_margin_bottom = 20
	plaque.position = BANNER.position
	plaque.size = BANNER.size
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(plaque)
	title_lbl.text = tr("英雄图鉴")
	title_lbl.position = BANNER.position + Vector2(0, -4)   # Ark 无下伸部·居中偏下补正
	title_lbl.size = BANNER.size
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.z_index = 1
	FontManager.apply(title_lbl, 36)
	title_lbl.add_theme_color_override("font_color", INK)
	title_lbl.add_theme_constant_override("outline_size", 0)


func _style_back_button() -> void:
	FontManager.apply_btn(back_btn, 24)
	back_btn.add_theme_color_override("font_color", INK)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		back_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var plate := NinePatchRect.new()
	plate.name = "Plate"
	plate.texture = NAV_PLATE_TEX
	plate.patch_margin_left = NAV_PLATE_MARGIN_X
	plate.patch_margin_right = NAV_PLATE_MARGIN_X
	plate.patch_margin_top = NAV_PLATE_MARGIN_Y
	plate.patch_margin_bottom = NAV_PLATE_MARGIN_Y
	plate.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.show_behind_parent = true
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击（返回失效）
	back_btn.add_child(plate)
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


# ============================================================
# 左页网格：章头 + 回纹头像框 6×4（一次建好·英雄无分阶）
# ============================================================

func _build_pool() -> void:
	# 章头（页首题字感）：墨字 + 细墨线（计数注记在同行右端·见 _setup_top）
	var chapter := Label.new()
	chapter.text = tr("英雄名录")
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
	for i in all_heroes.size():
		var h := all_heroes[i]
		var card := Button.new()
		card.flat = true
		card.focus_mode = Control.FOCUS_NONE
		card.size = Vector2(BOX, BOX + NAME_H)
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			card.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		card.position = Vector2(X0 + (i % COLS) * STEP_X, ROW_Y0 + floorf(i / float(COLS)) * ROW_H)
		# 选中金晕外环（道具图鉴同源同参）：衬在头像框后·常态隐藏·_select 切显隐+pop+呼吸。
		var ring := ColorRect.new()
		ring.name = "SelRing"
		ring.color = Color.WHITE
		ring.position = Vector2(-RING_PAD, -RING_PAD)
		ring.size = Vector2(BOX + RING_PAD * 2.0, BOX + RING_PAD * 2.0)
		var rm := ShaderMaterial.new()
		rm.shader = FRAME_SHADER
		rm.set_shader_parameter("edge_outer", GOLD_SEL.darkened(0.1))   # 外露带必须整条是金
		rm.set_shader_parameter("edge_mid", GOLD_SEL)
		rm.set_shader_parameter("edge_inner", GOLD_SEL.darkened(0.5))
		rm.set_shader_parameter("pixel_grid", (BOX + RING_PAD * 2.0) / 6.0)
		rm.set_shader_parameter("border_px", 2.0)
		rm.set_shader_parameter("noise_amt", 0.05)
		rm.set_shader_parameter("light_amount", 0.18)
		rm.set_shader_parameter("aspect", 1.0)
		rm.set_shader_parameter("corner_radius", 0.18)
		ring.material = rm
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.visible = false
		card.add_child(ring)
		# 回纹头像框（HeroFrame 组件·中性暖骨·无阵营语义）
		var frame := HERO_FRAME_SCENE.instantiate() as HeroFrame
		frame.frame_size = Vector2(BOX, BOX)
		frame.portrait_path = h.portrait_path
		card.add_child(frame)
		# 框下名字（亮页墨字直读·泥金+描边退役）
		var name_lbl := Label.new()
		name_lbl.text = tr(h.hero_name)
		name_lbl.position = Vector2(-12.0, BOX + 2.0)
		name_lbl.size = Vector2(BOX + 24.0, NAME_H)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		FontManager.apply(name_lbl, 16)
		name_lbl.add_theme_color_override("font_color", INK)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_lbl)
		card.pressed.connect(_select.bind(i))
		var bj := ButtonJuice.new()
		bj.name = "ButtonJuice"
		card.add_child(bj)
		pool_area.add_child(card)
		# ⚠ 必须在入树【后】设 IGNORE：HeroFrame._ready(入树时才跑)会把 mouse_filter 设回 STOP——
		#   入树前设置会被覆盖 → 框区吞点击（2026-07-13 实修·探针 gallery_click_probe 锁行为）。
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_cards.append(card)
		card_frames.append(frame)
	pool_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ============================================================
# 右页：单列居中主轴（道具图鉴同骨架·英雄内容）
#   ①名字小卷轴 → ②384 大展示格（idle 动画·头像框资产 ×3） → ③No./❤生命/主被动章行
#   → ④一条分隔墨线 → ⑤技能名（+图标） → ⑥描述墨字
# ============================================================

func _build_detail_panel() -> void:
	var px := PAGE_R.position.x
	var py := PAGE_R.position.y

	# ── ① 英雄名横幅=小卷轴（横向 9-slice·竖向原生高）──
	var banner := NinePatchRect.new()
	banner.texture = BANNER_TEX
	banner.patch_margin_left = 96
	banner.patch_margin_right = 96
	banner.patch_margin_top = 0
	banner.patch_margin_bottom = 0
	banner.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner.position = Vector2(px + 54, py + 72)
	banner.size = Vector2(PAGE_R.size.x - 108, 45)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(banner)
	_d_name = _make_label(Vector2(px + 57, py + 72), Vector2(PAGE_R.size.x - 114, 45), 32, INK)
	_d_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# ── ② 大展示格：格底 shader（暖深·比框深一档）+ 暖骨回纹框（128×3=384 整数放大）+ idle 动画 ──
	var cell_r := Rect2(px + (PAGE_R.size.x - CELL) * 0.5, py + 140, CELL, CELL)
	var cell := ColorRect.new()
	cell.color = Color.WHITE
	cell.position = cell_r.position
	cell.size = cell_r.size
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ShaderMaterial.new()
	cm.shader = CELL_BG_SHADER
	cm.set_shader_parameter("fill_color", CELL_FILL)
	cm.set_shader_parameter("inner_color", CELL_CENTER)
	cm.set_shader_parameter("center_glow", 1.0)
	cm.set_shader_parameter("corner_radius", 0.18)
	cm.set_shader_parameter("pixel_grid", CELL / 6.0)   # 像素粒径 6px=与左页格同比
	cm.set_shader_parameter("cloud_on", 0.0)
	cell.material = cm
	detail_area.add_child(cell)
	# idle 动画（先加=画在框之下·踩格底暖深处）。scale=2.0 整数倍（战斗同档·像素完美）：
	# 256 帧含大片透明留白·1.2 倍时人物仅约 120px=格大人小（首轮截图实测）；帧透明区溢出格外无害。
	_d_anim = AnimatedSprite2D.new()
	_d_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_anim.position = cell_r.position + cell_r.size * 0.5 + Vector2(0, 24)
	_d_anim.scale = Vector2(2.0, 2.0)
	detail_area.add_child(_d_anim)
	_d_fallback = TextureRect.new()
	_d_fallback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_fallback.position = cell_r.position + Vector2(48, 48)
	_d_fallback.size = cell_r.size - Vector2(96, 96)
	_d_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_fallback.visible = false
	detail_area.add_child(_d_fallback)
	var frame := TextureRect.new()
	frame.texture = AVATAR_FRAME_TEX
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.position = cell_r.position
	frame.size = cell_r.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(frame)

	# ── ③ 章行：No.（淡墨）+ ❤生命（朱墨）+ 主/被动章（彩底白字）——_layout_data_row 按内容居中 ──
	_d_no_lbl = _make_label(Vector2.ZERO, Vector2(120, 38), 18, Color(INK_DIM, 0.95))
	_d_no_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	_d_hp_num = _make_label(Vector2.ZERO, Vector2(60, 38), 24, HP_INK)
	_d_hp_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_tag_edge = _chip_rect(Color(INK, 0.75))
	_d_tag_bg = _chip_rect(ACTIVE_TAG)
	_d_tag = _make_label(Vector2.ZERO, Vector2(76, 34), 18, Color.WHITE)
	_d_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_tag.add_theme_constant_override("outline_size", 4)
	_d_tag.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))

	# ── ④ 一条分隔墨线 ──
	_rect(detail_area, Rect2(px + (PAGE_R.size.x - 360.0) * 0.5, py + 618, 360, 1), Color(INK, 0.25))

	# ── ⑤ 技能名（+可选图标·_layout_skill_row 按内容居中）+ ⑥ 描述墨字 ──
	_d_skill_icon = TextureRect.new()
	_d_skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_skill_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_skill_icon.visible = false
	detail_area.add_child(_d_skill_icon)
	_d_skill_name = _make_label(Vector2.ZERO, Vector2(300, 32), 24, INK)
	_d_skill_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_detail = _make_label(
		Vector2(px + 76, py + 700),
		Vector2(PAGE_R.size.x - 152, 168), 24, INK)
	_d_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_d_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 快捷键提示：卷轴下方·宣纸衬底留白带上的墨字注记
	var hint := _make_label(Vector2(0, 986), Vector2(1920, 24), 14, Color(INK, 0.62))
	hint.text = tr("← → 切换英雄 · ESC 返回")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _chip_rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(r)
	return r


## 选中英雄：左格金晕外环+框身轻暖提亮（道具图鉴同语言）+ 右页填充。
func _select(idx: int) -> void:
	if idx == _sel_idx:
		return
	for tw: Tween in _sel_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_sel_tweens.clear()
	if _sel_idx >= 0:
		var old := card_cards[_sel_idx]
		var old_ring := old.get_node("SelRing") as ColorRect
		old_ring.visible = false
		old_ring.modulate = Color.WHITE
		card_frames[_sel_idx].modulate = Color.WHITE
	_sel_idx = idx
	_play_select_fx(card_cards[idx], card_frames[idx])

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
	# 展示落位微弹（0.12s·换人时右页也有反馈·快速方向键连按先 kill）
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_d_anim.scale = Vector2(2.12, 2.12)
	_pop_tween = create_tween()
	_pop_tween.tween_property(_d_anim, "scale", Vector2(2.0, 2.0), 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_d_name.text = tr(h.hero_name)
	_d_no_lbl.text = "No.%02d" % (idx + 1)
	_d_hp_num.text = "%d" % h.max_hp
	var is_passive := h.skill_type == HeroData.SkillType.PASSIVE
	_d_tag.text = tr("被动") if is_passive else tr("主动")
	_d_tag_bg.color = PASSIVE_TAG if is_passive else ACTIVE_TAG
	_d_skill_name.text = tr(h.skill_description)
	if h.skill_icon_path != "" and ResourceLoader.exists(h.skill_icon_path):
		_d_skill_icon.texture = load(h.skill_icon_path)
		_d_skill_icon.visible = true
	else:
		_d_skill_icon.visible = false
	_d_detail.text = tr(h.skill_detail) if h.skill_detail != "" else tr(h.skill_description)
	_layout_data_row()
	_layout_skill_row()


## 选中动效（道具图鉴同参）：金晕环收拢 pop（0.14s）→ 安静呼吸（2.6s 循环·图鉴动效拨杆=低）。
func _play_select_fx(card: Button, frame: HeroFrame) -> void:
	var ring := card.get_node("SelRing") as ColorRect
	frame.modulate = SEL_TINT   # 轻暖提亮（乘色不压蓝通道·⛔is_selected 冷蓝白=战斗换人语言）
	var end_pos := Vector2(-RING_PAD, -RING_PAD)
	var end_size := Vector2(BOX + RING_PAD * 2.0, BOX + RING_PAD * 2.0)
	ring.visible = true
	ring.position = end_pos - Vector2(3, 3)
	ring.size = end_size + Vector2(6, 6)
	ring.modulate = Color(1, 1, 1, 0.0)
	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(ring, "position", end_pos, 0.14)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(ring, "size", end_size, 0.14)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(ring, "modulate:a", 1.0, 0.12)
	_sel_tweens.append(pop)
	var breath := create_tween()   # 首步 interval=让过 pop（两条 tween 不同时碰 modulate:a）
	breath.set_loops()
	breath.tween_interval(0.5)
	breath.tween_property(ring, "modulate:a", 0.85, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(ring, "modulate:a", 1.0, 1.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sel_tweens.append(breath)


## 章行（No. + ❤生命 + 主/被动章）作为一组在页内水平居中（宽度随内容 → 每次重排）。
func _layout_data_row() -> void:
	var y0: float = PAGE_R.position.y + 556
	var f: Font = _d_no_lbl.get_theme_font("font")
	var no_w: float = f.get_string_size(_d_no_lbl.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _d_no_lbl.get_theme_font_size("font_size")).x
	var num_w: float = f.get_string_size(_d_hp_num.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _d_hp_num.get_theme_font_size("font_size")).x
	var hp_w: float = 26.0 + 8.0 + num_w                    # ❤ + 间距 + 数字
	var tag_w: float = f.get_string_size(_d_tag.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _d_tag.get_theme_font_size("font_size")).x + 36.0
	var gap := 28.0
	var total: float = no_w + gap + hp_w + gap + tag_w
	var x0: float = PAGE_R.position.x + (PAGE_R.size.x - total) * 0.5
	_d_no_lbl.position = Vector2(x0, y0)
	_d_no_lbl.size = Vector2(no_w + 4.0, 38)
	var x1: float = x0 + no_w + gap
	_d_hp_heart.position = Vector2(x1, y0 + 6.0)
	_d_hp_num.position = Vector2(x1 + 26.0 + 8.0, y0)
	_d_hp_num.size = Vector2(num_w + 4.0, 38)
	var x2: float = x1 + hp_w + gap
	_d_tag_edge.position = Vector2(x2 - 2, y0 + 1)
	_d_tag_edge.size = Vector2(tag_w + 4, 38)
	_d_tag_bg.position = Vector2(x2, y0 + 3)
	_d_tag_bg.size = Vector2(tag_w, 34)
	_d_tag.position = Vector2(x2, y0 + 3)
	_d_tag.size = Vector2(tag_w, 34)


## 技能名（+可选图标）作为一组在页内水平居中（名字长短不一 → 每次重排）。
func _layout_skill_row() -> void:
	var f: Font = _d_skill_name.get_theme_font("font")
	var fs: int = _d_skill_name.get_theme_font_size("font_size")
	var name_w: float = f.get_string_size(_d_skill_name.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var icon_on: bool = _d_skill_icon != null and _d_skill_icon.visible
	var icon_block: float = 40.0 if icon_on else 0.0   # 32 图标 + 8 间距
	var total: float = icon_block + name_w
	var x0: float = PAGE_R.position.x + (PAGE_R.size.x - total) * 0.5
	var y0: float = PAGE_R.position.y + 648
	if icon_on:
		_d_skill_icon.position = Vector2(x0, y0)
		_d_skill_icon.size = Vector2(32, 32)
	_d_skill_name.position = Vector2(x0 + icon_block, y0)
	_d_skill_name.size = Vector2(name_w + 8, 32)


# ============================================================
# 输入 / 转场 / 入场
# ============================================================

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


## 战斗内嵌模式（battle_codex_overlay 注入）：有效时「返回/ESC」改走关闭浮层，不切场景。
var embedded_close: Callable = Callable()


func _back_to_menu() -> void:
	if embedded_close.is_valid():
		embedded_close.call()
		return
	TransitionManager.transition_to(MENU_SCENE)


## 入场：牌匾/返回滑入 + 卷轴轻微上浮 + 左页格按行翻开扫过 + 右页淡入。
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
	for i in card_cards.size():
		var card := card_cards[i]
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

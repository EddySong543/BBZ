extends Control

## 个人资料界面（2026-07-16 地基版·UI 重构 Epic 项⑥）。
## 外壳=图鉴家族模板（hero_gallery 同配方：宣纸山水衬底+墨云带+整屏手卷+牌匾贴形投影+返回导航皮）。
## 左页=身份：384 大展示格（头像英雄 idle·点击→纸卡浮层选 24 英雄换头像）+ 名字/改名 + 段位占位 + 建档。
## 右页=战绩：匹配对战 / 联机对战 / 生涯合计 三块（场次·胜·负·平·胜率）。
## 数据只经 PlayerProfile 静态存档类读写（UI 不自持状态）；主菜单顶左身份带=本屏入口。
## ⚠ 装饰节点必须 mouse_filter=IGNORE——否则吞点击（图鉴家族踩过坑）。

const ProfileStore := preload("res://src/core/player_profile.gd")
const RuntimeFeatures := preload("res://src/core/runtime_features.gd")
const HERO_FRAME_SCENE := preload("res://src/ui/components/hero_frame.tscn")   # 回纹头像框（选头像格）
const AVATAR_FRAME_TEX := preload("res://assets/ui/hero_avatar_frame.png")     # 大展示格框（128px ×3 整数放大）
const PLAQUE_TEX := preload("res://assets/ui/ui_plaque.png")                   # 悬挂牌匾（图鉴/设置同挂点）
const SCROLL_TEX := preload("res://assets/ui/item_codex_scroll.png")           # 整屏手卷（图鉴同源）
const BACKDROP_TEX := preload("res://assets/ui/item_codex_backdrop.png")       # 衬底=宣纸淡墨山水（图鉴同源）
const CARD_TEX := preload("res://assets/ui/item_draft_card.png")               # 纸卡（头像选择浮层面板身·设置同皮）
const INK_CLOUDS_SHADER := preload("res://assets/shaders/canvas_ui_ink_clouds.gdshader")
const CELL_BG_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")   # 当前头像金晕外环
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")            # 返回/改名钮=导航钮同皮
const NAV_PLATE_MARGIN_X := 22   # v14（main_menu 同值）
const NAV_PLATE_MARGIN_Y := 20

const HERO_DATA_DIR := "res://assets/data/heroes/"
const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 墨字（宣纸亮页·图鉴家族同值）──
const INK := Color(0.24, 0.19, 0.12)
const INK_DIM := Color(0.48, 0.41, 0.28)

# ── 家族令牌（图鉴/设置同值）──
const GOLD_SEL := Color("dca12e")                      # 亮纸档选中金（当前头像标记）
const SHADOW_TINT := Color(0.10, 0.07, 0.05, 0.38)     # 贴形投影暖黑

# ── 卷轴几何（图鉴家族同值）──
const PAGE_L := Rect2(240, 128, 712, 842)
const PAGE_R := Rect2(968, 128, 712, 842)
const BANNER := Rect2(806, 46, 308, 78)

# ── 左页大展示格（hero_gallery 右页同配方）──
const CELL := 384.0
const CELL_FILL := Color("221c15")
const CELL_CENTER := Color("2e2720")

# ── 头像选择浮层（设置弹框同纸卡）──
const CARD_SIZE := Vector2(526.0, 710.0)
const PLAQUE_SIZE := Vector2(240.0, 62.0)
const PICK_COLS := 6
const PICK_BOX := 72.0
const PICK_STEP := 80.0
const PICK_RING_PAD := 4.0

## 右页战绩三块（mode=""=生涯合计行·由两模式求和）。
const STAT_BLOCKS: Array = [
	["匹配对战", "match"],
	["联机对战", "net"],
	["生涯合计", ""],
]
const STAT_HEADS: Array[String] = ["场次", "胜", "负", "平", "胜率"]

var all_heroes: Array[HeroData] = []
var _hero_by_id: Dictionary = {}       # hero_id → HeroData（头像换装查询）

var _book_layer: Control               # 卷轴实体（入场上浮层）

# 左页身份部件
var _avatar_anim: AnimatedSprite2D
var _avatar_fallback: TextureRect
var _name_lbl: Label
var _name_edit: LineEdit
var _rename_btn: Button

# 头像选择浮层（懒建·复用）
var _picker: Control
var _picker_card: Control
var _picker_rings: Array[ColorRect] = []
var _picker_frames: Array[HeroFrame] = []

@onready var identity_area: Control = $IdentityArea
@onready var stats_area: Control = $StatsArea
@onready var back_btn: Button = $TopBand/BackButton
@onready var title_lbl: Label = $TopBand/Title


func _ready() -> void:
	all_heroes = HeroData.create_launch_pool(HERO_DATA_DIR)   # 首发 24（h01-h24）
	for h: HeroData in all_heroes:
		_hero_by_id[h.hero_id] = h
	_build_book()
	_setup_top()
	_build_identity_page()
	stats_area.visible = RuntimeFeatures.PVP_ENABLED
	if RuntimeFeatures.PVP_ENABLED:
		_build_stats_page()
	_apply_avatar()
	_play_intro()


# ============================================================
# 卷轴实体（图鉴家族同配方：衬底 + 墨云带 + 整屏手卷）
# ============================================================

func _build_book() -> void:
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
	move_child(_book_layer, 4)

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


## 像素墨云横带（图鉴同参：center_frac=垂直中心·seed 上下互异·flow=流速）。
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
# 顶部浮动件：悬挂牌匾（贴形投影）+ 返回钮（导航皮）
# ============================================================

func _setup_top() -> void:
	var band := $TopBand as Control
	var shadow := _plaque_rect()
	shadow.name = "PlaqueShadow"
	shadow.position = BANNER.position + Vector2(6, 8)
	shadow.size = BANNER.size
	shadow.modulate = SHADOW_TINT
	band.add_child(shadow)
	var plaque := _plaque_rect()
	plaque.name = "Plaque"
	plaque.position = BANNER.position
	plaque.size = BANNER.size
	band.add_child(plaque)
	title_lbl.text = tr("个人资料")
	title_lbl.position = BANNER.position + Vector2(0, -4)   # Ark 无下伸部·居中偏下补正
	title_lbl.size = BANNER.size
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.z_index = 1
	FontManager.apply(title_lbl, 36)
	title_lbl.add_theme_color_override("font_color", INK)
	title_lbl.add_theme_constant_override("outline_size", 0)

	FontManager.apply_btn(back_btn, 24)
	back_btn.add_theme_color_override("font_color", INK)
	_apply_nav_plate(back_btn)
	back_btn.pressed.connect(_back_to_menu)


func _plaque_rect() -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = PLAQUE_TEX
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.patch_margin_left = 26   # 新牌匾（265×63）角钩区实量（图鉴同值）
	p.patch_margin_right = 26
	p.patch_margin_top = 23
	p.patch_margin_bottom = 23
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## 导航钮皮（9-slice·全游戏导航一语言）——返回钮 / 改名钮共用。
func _apply_nav_plate(btn: Button) -> void:
	for s: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
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
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击
	btn.add_child(plate)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	btn.add_child(bj)


# ============================================================
# 左页：身份（大展示格=头像英雄 idle·可点换头像 + 名字/改名 + 段位占位 + 建档）
# ============================================================

func _build_identity_page() -> void:
	_chapter_head(identity_area, tr("身份"), PAGE_L.position.x + 42.0)

	# ── 大展示格：点击壳 Button（视觉件全挂在壳下·hero_gallery 右页同配方）──
	var cell_pos := Vector2(PAGE_L.position.x + (PAGE_L.size.x - CELL) * 0.5, 228.0)
	var btn := Button.new()
	btn.name = "AvatarButton"
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = cell_pos
	btn.size = Vector2(CELL, CELL)
	for s: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var cell := ColorRect.new()
	cell.color = Color.WHITE
	cell.size = Vector2(CELL, CELL)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ShaderMaterial.new()
	cm.shader = CELL_BG_SHADER
	cm.set_shader_parameter("fill_color", CELL_FILL)
	cm.set_shader_parameter("inner_color", CELL_CENTER)
	cm.set_shader_parameter("center_glow", 1.0)
	cm.set_shader_parameter("corner_radius", 0.18)
	cm.set_shader_parameter("pixel_grid", CELL / 6.0)
	cm.set_shader_parameter("cloud_on", 0.0)
	cell.material = cm
	btn.add_child(cell)
	_avatar_anim = AnimatedSprite2D.new()
	_avatar_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_avatar_anim.position = Vector2(CELL * 0.5, CELL * 0.5 + 24.0)
	_avatar_anim.scale = Vector2(2.0, 2.0)   # 整数档（战斗/图鉴同·像素完美）
	btn.add_child(_avatar_anim)
	_avatar_fallback = TextureRect.new()
	_avatar_fallback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_avatar_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar_fallback.position = Vector2(48, 48)
	_avatar_fallback.size = Vector2(CELL - 96.0, CELL - 96.0)
	_avatar_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_fallback.visible = false
	btn.add_child(_avatar_fallback)
	var frame := TextureRect.new()
	frame.texture = AVATAR_FRAME_TEX
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = Vector2(CELL, CELL)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(frame)
	btn.pressed.connect(_open_avatar_picker)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	btn.add_child(bj)
	identity_area.add_child(btn)

	var hint := _make_label(identity_area, Vector2(PAGE_L.position.x, 622), Vector2(PAGE_L.size.x, 22), 14, Color(INK, 0.55))
	hint.text = tr("点击头像可更换")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ── 名字（大墨字）+ 改名（LineEdit 原位替换）──
	_name_lbl = _make_label(identity_area, Vector2(PAGE_L.position.x, 652), Vector2(PAGE_L.size.x, 44), 32, INK)
	_name_lbl.text = ProfileStore.get_player_name()
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(PAGE_L.position.x + (PAGE_L.size.x - 320.0) * 0.5, 652)
	_name_edit.size = Vector2(320, 44)
	_name_edit.max_length = ProfileStore.NAME_MAX_CHARS
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_override("font", FontManager.f12)
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.add_theme_color_override("font_color", INK)
	_name_edit.visible = false
	_name_edit.text_submitted.connect(func(_t: String) -> void: _commit_rename())
	_name_edit.focus_exited.connect(_commit_rename)
	identity_area.add_child(_name_edit)
	_rename_btn = Button.new()
	_rename_btn.name = "RenameButton"
	_rename_btn.text = tr("改名")
	_rename_btn.focus_mode = Control.FOCUS_NONE
	_rename_btn.position = Vector2(PAGE_L.position.x + (PAGE_L.size.x - 116.0) * 0.5, 712)
	_rename_btn.size = Vector2(116, 44)
	FontManager.apply_btn(_rename_btn, 18)
	_rename_btn.add_theme_color_override("font_color", INK)
	_apply_nav_plate(_rename_btn)
	_rename_btn.pressed.connect(_start_rename)
	identity_area.add_child(_rename_btn)

	# ── PvP 开启时显示段位；建档日期始终保留 ──
	if RuntimeFeatures.PVP_ENABLED:
		var rank := _make_label(identity_area, Vector2(PAGE_L.position.x, 786), Vector2(PAGE_L.size.x, 26), 18, INK_DIM)
		rank.text = tr("段位 · 未定级")
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var created := _make_label(identity_area, Vector2(PAGE_L.position.x, 824), Vector2(PAGE_L.size.x, 24), 16, Color(INK_DIM, 0.85))
	created.text = tr("建档 · %s") % ProfileStore.created_text()
	created.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 快捷键提示：卷轴下方·宣纸衬底留白带上的墨字注记（图鉴同位）
	var esc_hint := _make_label(self, Vector2(0, 986), Vector2(1920, 24), 14, Color(INK, 0.62))
	esc_hint.text = tr("ESC 返回")
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 章头（页首题字感·图鉴同手法）：墨字 + 细墨线。
func _chapter_head(parent: Control, text: String, x: float) -> void:
	var chapter := _make_label(parent, Vector2(x, 150), Vector2(300, 40), 26, INK)
	chapter.text = text
	var rule := ColorRect.new()
	rule.color = Color(INK, 0.30)
	rule.position = Vector2(x, 198)
	rule.size = Vector2(632, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)


func _start_rename() -> void:
	_name_edit.text = ProfileStore.get_player_name()
	_name_lbl.visible = false
	_rename_btn.visible = false
	_name_edit.visible = true
	_name_edit.grab_focus()
	_name_edit.caret_column = _name_edit.text.length()


func _commit_rename() -> void:
	if not _name_edit.visible:
		return
	ProfileStore.set_player_name(_name_edit.text)   # 空串/纯空白=保留旧名（存档层守）
	_name_edit.visible = false
	_name_lbl.text = ProfileStore.get_player_name()
	_name_lbl.visible = true
	_rename_btn.visible = true


## 大展示格换装：头像英雄 idle 动画（无帧资源回落静态头像·hero_gallery 同兜底）。
func _apply_avatar() -> void:
	var h: HeroData = _hero_by_id.get(ProfileStore.get_avatar_hero())
	if h == null and not all_heroes.is_empty():
		h = all_heroes[0]
	if h == null:
		return
	if h.sprite_frames_path != "" and ResourceLoader.exists(h.sprite_frames_path):
		_avatar_anim.sprite_frames = load(h.sprite_frames_path)
		_avatar_anim.play("idle")
		_avatar_anim.visible = true
		_avatar_fallback.visible = false
	else:
		_avatar_anim.visible = false
		_avatar_fallback.texture = load(h.portrait_path) if ResourceLoader.exists(h.portrait_path) else null
		_avatar_fallback.visible = true


# ============================================================
# 右页：战绩（匹配 / 联机 / 生涯合计·数据源=PlayerProfile 计数器）
# ============================================================

func _build_stats_page() -> void:
	_chapter_head(stats_area, tr("战绩"), PAGE_R.position.x + 42.0)
	var x0 := PAGE_R.position.x + 42.0
	var block_y: Array[float] = [246.0, 434.0, 622.0]
	for bi in STAT_BLOCKS.size():
		var title: String = STAT_BLOCKS[bi][0]
		var mode: String = STAT_BLOCKS[bi][1]
		var y := block_y[bi]
		var sub := _make_label(stats_area, Vector2(x0, y), Vector2(300, 32), 24, INK)
		sub.text = tr(title)
		var vals := _block_values(mode)
		for ci in STAT_HEADS.size():
			var cx := x0 + ci * 127.0
			var v := _make_label(stats_area, Vector2(cx, y + 52.0), Vector2(120, 36), 32, INK)
			v.text = vals[ci]
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var head := _make_label(stats_area, Vector2(cx, y + 94.0), Vector2(120, 22), 16, INK_DIM)
			head.text = tr(STAT_HEADS[ci])
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 一块战绩的 5 列文本：场次/胜/负/平/胜率。mode=""=生涯合计（两模式求和）。
func _block_values(mode: String) -> Array[String]:
	var win := 0
	var lose := 0
	var draw := 0
	if mode == "":
		for m: String in ProfileStore.MODES:
			win += ProfileStore.get_stat(m, "win")
			lose += ProfileStore.get_stat(m, "lose")
			draw += ProfileStore.get_stat(m, "draw")
	else:
		win = ProfileStore.get_stat(mode, "win")
		lose = ProfileStore.get_stat(mode, "lose")
		draw = ProfileStore.get_stat(mode, "draw")
	var total := win + lose + draw
	var rate := "—" if total <= 0 else "%d%%" % int(roundf(float(win) * 100.0 / float(total)))
	return ["%d" % total, "%d" % win, "%d" % lose, "%d" % draw, rate]


# ============================================================
# 头像选择浮层（设置弹框同纸卡语言·懒建复用）
# ============================================================

func _open_avatar_picker() -> void:
	if _picker == null:
		_build_avatar_picker()
	_refresh_picker_rings()
	_picker.visible = true
	# 入场轻收拢 pop（设置弹框同手感）
	_picker_card.pivot_offset = CARD_SIZE * 0.5
	_picker_card.scale = Vector2(0.96, 0.96)
	_picker.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_picker, "modulate:a", 1.0, 0.12)
	tw.tween_property(_picker_card, "scale", Vector2.ONE, 0.14)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _close_avatar_picker() -> void:
	if _picker != null:
		_picker.visible = false


func _build_avatar_picker() -> void:
	_picker = Control.new()
	_picker.name = "AvatarPicker"
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.visible = false

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_avatar_picker())
	_picker.add_child(dim)

	_picker_card = Control.new()
	_picker_card.name = "Card"
	_picker_card.position = (Vector2(1920, 1080) - CARD_SIZE) * 0.5
	_picker_card.size = CARD_SIZE
	_picker.add_child(_picker_card)

	# 贴形投影 + 纸卡身（设置弹框同配方）
	var shadow := _card_tex_rect()
	shadow.position = Vector2(6, 8)
	shadow.modulate = SHADOW_TINT
	_picker_card.add_child(shadow)
	var body := _card_tex_rect()
	body.mouse_filter = Control.MOUSE_FILTER_STOP   # 面板身吞点击（防漏到遮罩关闭）
	_picker_card.add_child(body)

	# 牌匾标题（骑缝悬挂·贴形投影）
	var px := (CARD_SIZE.x - PLAQUE_SIZE.x) * 0.5
	var py := -PLAQUE_SIZE.y * 0.5
	var pshadow := _plaque_rect()
	pshadow.position = Vector2(px + 6.0, py + 8.0)
	pshadow.size = PLAQUE_SIZE
	pshadow.modulate = SHADOW_TINT
	_picker_card.add_child(pshadow)
	var plaque := _plaque_rect()
	plaque.position = Vector2(px, py)
	plaque.size = PLAQUE_SIZE
	_picker_card.add_child(plaque)
	var ptitle := _make_label(_picker_card, Vector2(px, py - 4.0), PLAQUE_SIZE, 24, INK)
	ptitle.text = tr("更换头像")
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ptitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 24 英雄网格（6×4·72px 回纹头像框·当前头像=金晕外环）
	var x0 := (CARD_SIZE.x - (PICK_STEP * (PICK_COLS - 1) + PICK_BOX)) * 0.5
	var y0 := (CARD_SIZE.y - (PICK_STEP * 3.0 + PICK_BOX)) * 0.5 + 14.0
	_picker_rings.clear()
	_picker_frames.clear()
	for i in all_heroes.size():
		var h := all_heroes[i]
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = Vector2(x0 + (i % PICK_COLS) * PICK_STEP, y0 + floorf(i / float(PICK_COLS)) * PICK_STEP)
		btn.size = Vector2(PICK_BOX, PICK_BOX)
		for s: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		var ring := ColorRect.new()
		ring.name = "SelRing"
		ring.color = Color.WHITE
		ring.position = Vector2(-PICK_RING_PAD, -PICK_RING_PAD)
		ring.size = Vector2(PICK_BOX + PICK_RING_PAD * 2.0, PICK_BOX + PICK_RING_PAD * 2.0)
		var rm := ShaderMaterial.new()
		rm.shader = FRAME_SHADER
		rm.set_shader_parameter("edge_outer", GOLD_SEL.darkened(0.1))   # 外露带必须整条是金
		rm.set_shader_parameter("edge_mid", GOLD_SEL)
		rm.set_shader_parameter("edge_inner", GOLD_SEL.darkened(0.5))
		rm.set_shader_parameter("pixel_grid", (PICK_BOX + PICK_RING_PAD * 2.0) / 6.0)
		rm.set_shader_parameter("border_px", 2.0)
		rm.set_shader_parameter("noise_amt", 0.05)
		rm.set_shader_parameter("light_amount", 0.18)
		rm.set_shader_parameter("aspect", 1.0)
		rm.set_shader_parameter("corner_radius", 0.18)
		ring.material = rm
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.visible = false
		btn.add_child(ring)
		var frame := HERO_FRAME_SCENE.instantiate() as HeroFrame
		frame.frame_size = Vector2(PICK_BOX, PICK_BOX)
		frame.portrait_path = h.portrait_path
		btn.add_child(frame)
		btn.pressed.connect(_pick_avatar.bind(h.hero_id))
		var bj := ButtonJuice.new()
		bj.name = "ButtonJuice"
		btn.add_child(bj)
		_picker_card.add_child(btn)
		_picker_rings.append(ring)
		_picker_frames.append(frame)

	add_child(_picker)   # 最后入树=盖在全屏最上层
	# ⚠ 必须在入树【后】设 IGNORE：HeroFrame._ready 会把 mouse_filter 设回 STOP（家族踩过坑）。
	for f: HeroFrame in _picker_frames:
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _card_tex_rect() -> TextureRect:
	var t := TextureRect.new()
	t.texture = CARD_TEX
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = CARD_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## 金晕外环=当前头像标记（点选家族语言·亮纸档金）。
func _refresh_picker_rings() -> void:
	var cur := ProfileStore.get_avatar_hero()
	for i in all_heroes.size():
		_picker_rings[i].visible = all_heroes[i].hero_id == cur


func _pick_avatar(hero_id: String) -> void:
	ProfileStore.set_avatar_hero(hero_id)
	_apply_avatar()
	_close_avatar_picker()


# ============================================================
# 输入 / 转场 / 入场
# ============================================================

## ESC：浮层开着先关浮层，否则返回主菜单。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _picker != null and _picker.visible:
			_close_avatar_picker()
		else:
			_back_to_menu()
		get_viewport().set_input_as_handled()


func _back_to_menu() -> void:
	TransitionManager.transition_to(MENU_SCENE)


## 入场：牌匾/返回滑入 + 卷轴轻微上浮 + 双页淡入（图鉴家族同手感）。
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
	for area: Control in [identity_area, stats_area]:
		area.modulate.a = 0.0
		var ta := create_tween()
		ta.tween_interval(0.2)
		ta.tween_property(area, "modulate:a", 1.0, 0.35)


# ============================================================
# 自绘部件
# ============================================================

func _make_label(parent: Control, pos: Vector2, sz: Vector2, font_px: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.size = sz
	FontManager.apply(lbl, font_px)
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl

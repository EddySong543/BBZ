extends Control

## 英雄图鉴（2026-08-06 二维羊皮纸书改版）。
## 视觉：正式书页素材 + 左名录/右详情双页布局 + 角色背后的透明蓝灰笔刷。
## 行为：点击、方向键、ESC/返回、战斗内嵌关闭与英雄数据读取全部沿用成熟逻辑。
## ⚠ 装饰节点必须 mouse_filter=IGNORE，避免遮挡头像与返回按钮。

const ITEM_FRAME_TEX := preload("res://assets/ui/item_frame.png")              # 英雄图鉴统一使用新版简约几何框
const CELL_BG_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")
const FRAME_PALETTE_SHADER := preload("res://assets/shaders/canvas_ui_item_frame_palette.gdshader")
const SELECTION_MARKER_SCRIPT := preload("res://src/ui/components/hero_gallery_selection_marker.gd")

const HERO_DATA_DIR := "res://assets/data/heroes/"
const MENU_SCENE := "res://src/ui/main_menu.tscn"

# ── 羊皮纸书色板 ──
const BOOK_EDGE := Color("6B4A32")
const PAPER_SOFT := Color("EAD9BA")
const BONE_LINE := Color("B59A72")
const INK := Color("2E2922")
const INK_DIM := Color("706655")
const HP_INK := Color("B63A32")
# ── 选中态：真实框材质转金 + 单色书页棕三角箭头 ──
const GOLD_SEL := Color("C99032")
const SELECTED_NAME_INK := Color("9A6828")
const POINTER_COLOR := Color("7B5E3E")
const POINTER_SIZE := Vector2(20.0, 36.0)

# ── 1920×1080 双栏几何 ──
const PAGE_L := Rect2(50, 158, 886, 836)
const PAGE_R := Rect2(952, 158, 918, 836)

# ── 左页网格：每页 4 列 × 3 行 ──
const COLS := 4
const CARDS_PER_PAGE := 12
const BOX := 104.0
const NAME_H := 36.0
const STEP_X := 170.0
const ROW_H := 196.0

# ── 头像框：暖褐中性，不与蓝灰笔刷争色 ──
const CELL_FILL := Color("71685D")
const CELL_CENTER := Color("8C7C68")
const FRAME_SHADOW := Color("49372B")
const FRAME_MID := Color("8B765D")
const FRAME_HIGHLIGHT := Color("D7BD91")
const FRAME_SELECTED_SHADOW := Color("704A1E")
const FRAME_SELECTED_MID := Color("C99032")
const FRAME_SELECTED_HIGHLIGHT := Color("F2D28B")
const FRAME_ART_SCALE := 87.25 / 68.0
const FRAME_OFFSET_RATIO := Vector2(-9.6 / 68.0, -10.0 / 68.0)
const CELL_INSET_RATIO := 5.5 / 68.0

var all_heroes: Array[HeroData] = []
var card_cards: Array[Button] = []        # 格子点击壳（入场动画/ButtonJuice 挂这层）
var card_frames: Array[Control] = []      # 图鉴专用头像根节点（不再实例化旧 HeroFrame）
var card_name_labels: Array[Label] = []
var _sel_idx: int = -1
var _current_page: int = 0
var _sel_tweens: Array[Tween] = []        # 选中书签落位 tween（换选先 kill 全部）
var _pop_tween: Tween                     # 右页展示落位微弹

# 详情板部件（_build_detail_panel 一次建好）
var _d_anim: AnimatedSprite2D
var _d_fallback: TextureRect      # 无 idle 资源时的静态头像兜底
var _d_name: Label
var _d_hp_heart: TextureRect
var _d_hp_num: Label
var _d_tag_group: Control
var _d_tag_mark: Control
var _d_tag: Label
var _d_skill_name: Label
var _d_skill_icon: TextureRect
var _d_detail: Label
var _d_detail_rule: ColorRect
var _d_detail_pin: ColorRect

@onready var pool_area: Control = $PoolArea
@onready var portrait_grid: Control = $PoolArea/PortraitGrid
@onready var detail_area: Control = $DetailArea
@onready var _book_layer: Control = $BookLayer
@onready var back_btn: Button = $TopBand/BackButton
@onready var title_lbl: Label = $TopBand/Title
@onready var count_lbl: Label = $TopBand/CountLabel
@onready var page_navigation: Control = $PoolArea/PageNavigation
@onready var previous_page_btn: Button = $PoolArea/PageNavigation/PreviousPage
@onready var page_indicator: Label = $PoolArea/PageNavigation/PageIndicator
@onready var next_page_btn: Button = $PoolArea/PageNavigation/NextPage


func _ready() -> void:
	all_heroes = HeroData.create_launch_pool(HERO_DATA_DIR)   # 首发 24（h01-h24）
	_build_book()
	_setup_top()
	_build_pool()
	_setup_page_navigation()
	_build_detail_panel()
	_select(0)
	_play_intro()


# ============================================================
# 正式二维羊皮纸书素材
# ============================================================

func _build_book() -> void:
	var bg := get_node_or_null("Background") as Control
	if bg != null:
		bg.visible = false
	_book_layer.position = Vector2.ZERO
	_book_layer.modulate = Color.WHITE
	_book_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup_top() -> void:
	_style_back_button()

	title_lbl.text = ""
	title_lbl.visible = false

	count_lbl.text = ""
	count_lbl.visible = false


func _style_back_button() -> void:
	back_btn.text = tr("<<< 返回")
	back_btn.focus_mode = Control.FOCUS_ALL
	back_btn.pressed.connect(_back_to_menu)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	back_btn.add_child(bj)


func _setup_page_navigation() -> void:
	previous_page_btn.pressed.connect(_turn_page.bind(-1))
	next_page_btn.pressed.connect(_turn_page.bind(1))
	for button: Button in [previous_page_btn, next_page_btn]:
		var juice := ButtonJuice.new()
		juice.name = "ButtonJuice"
		button.add_child(juice)
	_refresh_page_visibility()


func _make_gallery_frame_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FRAME_PALETTE_SHADER
	m.set_shader_parameter("shadow_color", FRAME_SHADOW)
	m.set_shader_parameter("mid_color", FRAME_MID)
	m.set_shader_parameter("highlight_color", FRAME_HIGHLIGHT)
	return m


func _set_gallery_frame_selected(frame: Control, selected: bool) -> void:
	var frame_art := frame.get_node("GalleryItemFrame") as TextureRect
	var material := frame_art.material as ShaderMaterial
	material.set_shader_parameter(
		"shadow_color", FRAME_SELECTED_SHADOW if selected else FRAME_SHADOW)
	material.set_shader_parameter(
		"mid_color", FRAME_SELECTED_MID if selected else FRAME_MID)
	material.set_shader_parameter(
		"highlight_color", FRAME_SELECTED_HIGHLIGHT if selected else FRAME_HIGHLIGHT)


func _grid_float(property_name: StringName, fallback: float) -> float:
	var value: Variant = portrait_grid.get(property_name)
	return float(value) if value != null else fallback


func _grid_columns() -> int:
	return maxi(roundi(_grid_float(&"columns", COLS)), 1)


func _grid_page_size() -> int:
	return maxi(roundi(_grid_float(&"cards_per_page", CARDS_PER_PAGE)), 1)


func _page_count() -> int:
	return maxi(ceili(all_heroes.size() / float(_grid_page_size())), 1)


func _refresh_page_visibility() -> void:
	var page_size := _grid_page_size()
	var first_index := _current_page * page_size
	var last_index := mini(first_index + page_size, card_cards.size())
	for index in card_cards.size():
		var card := card_cards[index]
		card.visible = index >= first_index and index < last_index
		if card.visible:
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
	page_navigation.visible = _page_count() > 1
	page_indicator.text = "%02d / %02d" % [_current_page + 1, _page_count()]
	previous_page_btn.disabled = _current_page <= 0
	next_page_btn.disabled = _current_page >= _page_count() - 1


func _turn_page(direction: int) -> void:
	var target_page := clampi(_current_page + direction, 0, _page_count() - 1)
	if target_page == _current_page:
		return
	var page_size := _grid_page_size()
	var local_slot := _sel_idx % page_size if _sel_idx >= 0 else 0
	var target_index := mini(target_page * page_size + local_slot, all_heroes.size() - 1)
	_select(target_index)


func _grid_card_position(index: int, cols: int, step_x: float, row_height: float) -> Vector2:
	var row := floori(index / float(cols))
	var column := index % cols
	var center_column := (cols - 1) * 0.5
	var normalized_edge := absf(float(column) - center_column) / maxf(center_column, 1.0)
	return Vector2(
		column * step_x + float(row % 2) * _grid_float(&"row_stagger_x", 0.0),
		row * row_height
			+ normalized_edge * normalized_edge * _grid_float(&"page_curve_y", 0.0))


## 单色三角像素箭头：保持明确方向，用书页棕融入场景且不叠描边。
func _make_selection_pointer(box: float) -> Control:
	var pointer := SELECTION_MARKER_SCRIPT.new() as Control
	pointer.name = "SelectionPointer"
	pointer.position = Vector2(-28.0, floorf((box - POINTER_SIZE.y) * 0.5))
	pointer.size = POINTER_SIZE
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.visible = false
	pointer.set("color", POINTER_COLOR)
	pointer.set_meta("home_position", pointer.position)
	return pointer


# ============================================================
# 左页网格：中性几何头像框 4×3，每页 12 位英雄
# ============================================================

func _build_pool() -> void:
	var cols := _grid_columns()
	var box := _grid_float(&"box_size", BOX)
	var step_x := _grid_float(&"step_x", STEP_X)
	var row_height := _grid_float(&"row_height", ROW_H)
	var page_size := _grid_page_size()
	for i in all_heroes.size():
		var h := all_heroes[i]
		var card := Button.new()
		card.flat = true
		card.focus_mode = Control.FOCUS_NONE
		card.size = Vector2(box, box + NAME_H)
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			card.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		card.position = _grid_card_position(i % page_size, cols, step_x, row_height)
		# 选中态：真实框材质转金负责确认，书脊棕侧签负责定位。
		card.add_child(_make_selection_pointer(box))
		# 图鉴专用头像：填充 → 头像 → 新框。完全不实例化旧 HeroFrame，避免旧框层残留。
		var frame := Control.new()
		frame.name = "HeroPortraitFrame"
		frame.size = Vector2(box, box)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
		var cell_inset := box * CELL_INSET_RATIO
		var thumb_cell := ColorRect.new()
		thumb_cell.name = "HeroThumbCell"
		thumb_cell.color = Color.WHITE
		thumb_cell.position = Vector2.ONE * cell_inset
		thumb_cell.size = Vector2(box, box) - Vector2.ONE * cell_inset * 2.0
		thumb_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var thumb_cell_mat := ShaderMaterial.new()
		thumb_cell_mat.shader = CELL_BG_SHADER
		thumb_cell_mat.set_shader_parameter("fill_color", CELL_FILL)
		thumb_cell_mat.set_shader_parameter("inner_color", CELL_CENTER)
		thumb_cell_mat.set_shader_parameter("center_glow", 1.0)
		thumb_cell_mat.set_shader_parameter("corner_radius", 0.0)
		thumb_cell_mat.set_shader_parameter("pixel_grid", box / 6.0)
		thumb_cell_mat.set_shader_parameter("cloud_on", 0.0)
		thumb_cell.material = thumb_cell_mat
		frame.add_child(thumb_cell)
		var portrait := TextureRect.new()
		portrait.name = "HeroPortrait"
		portrait.texture = load(h.portrait_path) if ResourceLoader.exists(h.portrait_path) else null
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.position = thumb_cell.position
		portrait.size = thumb_cell.size
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(portrait)
		var gallery_frame := TextureRect.new()
		gallery_frame.name = "GalleryItemFrame"
		gallery_frame.texture = ITEM_FRAME_TEX
		gallery_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gallery_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gallery_frame.stretch_mode = TextureRect.STRETCH_SCALE
		gallery_frame.position = Vector2(box, box) * FRAME_OFFSET_RATIO
		gallery_frame.size = Vector2(box, box) * FRAME_ART_SCALE
		gallery_frame.material = _make_gallery_frame_material()
		gallery_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(gallery_frame)
		# 框下名字直读，不使用题签、描边或悬挂装饰。
		var name_lbl := Label.new()
		name_lbl.name = "HeroName"
		name_lbl.text = tr(h.hero_name)
		name_lbl.position = Vector2(-16.0, box + 4.0)
		name_lbl.size = Vector2(box + 32.0, NAME_H)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		FontManager.apply(name_lbl, 17)
		name_lbl.add_theme_color_override("font_color", INK)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_lbl)
		card.pressed.connect(_select.bind(i))
		var bj := ButtonJuice.new()
		bj.name = "ButtonJuice"
		card.add_child(bj)
		portrait_grid.add_child(card)
		card_cards.append(card)
		card_frames.append(frame)
		card_name_labels.append(name_lbl)
	pool_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ============================================================
# 右页：英雄名 → 蓝灰笔刷上的角色 → 数据行 → 技能与描述
# ============================================================

func _build_detail_panel() -> void:
	var px := PAGE_R.position.x
	var py := PAGE_R.position.y

	_d_name = _make_label(
		Vector2(px + 150, py + 34), Vector2(PAGE_R.size.x - 300, 48), 32, INK)
	_d_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var wash := $DetailArea/HeroPortraitWash as TextureRect
	wash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_d_anim = AnimatedSprite2D.new()
	_d_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_anim.position = wash.position + wash.size * 0.5 + Vector2(0, 12)
	_d_anim.scale = Vector2(2.0, 2.0)
	detail_area.add_child(_d_anim)
	_d_fallback = TextureRect.new()
	_d_fallback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_fallback.position = wash.position + Vector2(170, 20)
	_d_fallback.size = wash.size - Vector2(340, 40)
	_d_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_fallback.visible = false
	detail_area.add_child(_d_fallback)

	# 血量与技能类型都由场景节点承载，Godot 编辑器预览与 F6 使用同一位置。
	_d_hp_heart = $DetailArea/HPGroup/Heart as TextureRect
	_d_hp_num = $DetailArea/HPGroup/Number as Label
	_d_tag_group = $DetailArea/SkillTypeGroup as Control
	_d_tag_mark = $DetailArea/SkillTypeGroup/TypeMark as Control
	_d_tag = $DetailArea/SkillTypeGroup/TypeLabel as Label

	_d_skill_icon = TextureRect.new()
	_d_skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_skill_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_skill_icon.visible = false
	detail_area.add_child(_d_skill_icon)
	_d_skill_name = _make_label(Vector2.ZERO, Vector2(300, 36), 25, INK)
	_d_skill_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_detail_rule = ColorRect.new()
	_d_detail_rule.name = "DetailRule"
	_d_detail_rule.position = Vector2(px + 86, py + 680)
	_d_detail_rule.size = Vector2(2, 60)
	_d_detail_rule.color = Color(BONE_LINE, 0.82)
	_d_detail_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_detail_rule)
	_d_detail_pin = ColorRect.new()
	_d_detail_pin.name = "DetailPin"
	_d_detail_pin.position = Vector2(px + 84, py + 674)
	_d_detail_pin.size = Vector2(6, 6)
	_d_detail_pin.color = Color(BONE_LINE, 0.92)
	_d_detail_pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_detail_pin)
	_d_detail = _make_label(
		Vector2(px + 112, py + 670),
		Vector2(PAGE_R.size.x - 214, 126), 22, INK)
	_d_detail.name = "SkillDetail"
	_d_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_d_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 选中英雄：真实头像框转金 + 棕色三角指针 + 右页填充。
func _select(idx: int) -> void:
	if idx < 0 or idx >= all_heroes.size():
		return
	var target_page := floori(idx / float(_grid_page_size()))
	if target_page != _current_page:
		_current_page = target_page
		_refresh_page_visibility()
	if idx == _sel_idx:
		return
	for tw: Tween in _sel_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_sel_tweens.clear()
	if _sel_idx >= 0:
		var old := card_cards[_sel_idx]
		var old_pointer := old.get_node("SelectionPointer") as Control
		var old_pointer_home: Vector2 = old_pointer.get_meta("home_position")
		old_pointer.visible = false
		old_pointer.modulate = Color.WHITE
		old_pointer.position = old_pointer_home
		_set_gallery_frame_selected(card_frames[_sel_idx], false)
		card_name_labels[_sel_idx].add_theme_color_override("font_color", INK)
	_sel_idx = idx
	_play_select_fx(card_cards[idx], card_frames[idx])
	card_name_labels[idx].add_theme_color_override("font_color", SELECTED_NAME_INK)

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
	_d_hp_num.text = "%d" % h.max_hp
	var is_passive := h.skill_type == HeroData.SkillType.PASSIVE
	_d_tag.text = tr("被动") if is_passive else tr("主动")
	_d_tag.add_theme_color_override("font_color", Color.WHITE)
	_d_tag_mark.call("set_passive", is_passive)
	_d_skill_name.text = tr(h.skill_description)
	if h.skill_icon_path != "" and ResourceLoader.exists(h.skill_icon_path):
		_d_skill_icon.texture = load(h.skill_icon_path)
		_d_skill_icon.visible = true
	else:
		_d_skill_icon.visible = false
	_d_detail.text = tr(h.skill_detail) if h.skill_detail != "" else tr(h.skill_description)
	_layout_skill_row()


## 选中动效：真实框立即转金，粗像素棕色箭头轻推入；落位后完全静止。
func _play_select_fx(card: Button, frame: Control) -> void:
	var pointer := card.get_node("SelectionPointer") as Control
	_set_gallery_frame_selected(frame, true)
	pointer.visible = true
	var pointer_home: Vector2 = pointer.get_meta("home_position")
	pointer.position = pointer_home - Vector2(6, 0)
	pointer.modulate = Color(1, 1, 1, 0.0)
	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(pointer, "position", pointer_home, 0.16)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(pointer, "modulate:a", 1.0, 0.12)
	_sel_tweens.append(pop)


## 技能图标、技能名与主/被动标签作为一组在页内水平居中。
func _layout_skill_row() -> void:
	var f: Font = _d_skill_name.get_theme_font("font")
	var fs: int = _d_skill_name.get_theme_font_size("font_size")
	var name_w: float = f.get_string_size(_d_skill_name.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var icon_on: bool = _d_skill_icon != null and _d_skill_icon.visible
	var icon_block: float = 40.0 if icon_on else 0.0   # 32 图标 + 8 间距
	var tag_gap := 18.0
	var tag_w := 80.0
	var total: float = icon_block + name_w + tag_gap + tag_w
	var x0: float = PAGE_R.position.x + (PAGE_R.size.x - total) * 0.5
	var y0: float = PAGE_R.position.y + 610
	if icon_on:
		_d_skill_icon.position = Vector2(x0, y0)
		_d_skill_icon.size = Vector2(32, 32)
	_d_skill_name.position = Vector2(x0 + icon_block, y0)
	_d_skill_name.size = Vector2(name_w + 8, 32)
	var tag_x := x0 + icon_block + name_w + tag_gap
	_d_tag_group.position = Vector2(tag_x, y0)


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
	var cols := _grid_columns()
	if event.is_action_pressed("ui_left"):
		step = -1
	elif event.is_action_pressed("ui_right"):
		step = 1
	elif event.is_action_pressed("ui_up"):
		step = -cols
	elif event.is_action_pressed("ui_down"):
		step = cols
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


## 入场：页眉滑入 + 册页轻微上浮 + 左页格按行翻开扫过 + 右页淡入。
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
	var cols := _grid_columns()
	var page_size := _grid_page_size()
	for i in card_cards.size():
		var card := card_cards[i]
		if not card.visible:
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
			continue
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.001, 1.0)
		card.modulate.a = 0.0
		var local_index := i % page_size
		var delay := 0.1 + floorf(local_index / float(cols)) * 0.1 \
			+ (local_index % cols) * 0.03
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

extends Control

signal tier_changed(tier: int)

## 道具图鉴。书本、导航、网格根和详情区均由场景承载，方便在 Godot 中可视化调整。
## 脚本只填入真实道具卡、刷新选中内容与处理交互，不再动态搭建整套页面。
## 第一批统一规则：复用英雄图鉴的羊皮纸书和返回入口；删除总标题、计数与标题装饰线；
## 三档按书页连续浏览；当前道具的稀有度只在右页图案下方展示。

const SELECTION_MARKER_SCRIPT := preload("res://src/ui/components/hero_gallery_selection_marker.gd")
const EffectTextFormatterScript := preload("res://src/ui/effect_text_formatter.gd")
const ITEM_FRAME_TEX := ItemFrameStyle.FRAME_TEXTURE
const TIER_LABEL := {1: "普通", 2: "稀有", 3: "传说"}
const TIER_TAG_COLOR := {
	1: ItemCatalog.RARITY_NORMAL,
	2: ItemCatalog.RARITY_RARE,
	3: ItemCatalog.RARITY_LEGENDARY,
}
const DETAIL_NAME_INK := Color("302820")
const MENU_SCENE := "res://src/ui/main_menu.tscn"

# 道具格恢复与战斗道具栏完全同源的格底 shader 与三阶配色。

# ── 选中态：保留道具自身稀有度框色，仅用书页指针和名称墨色表达选中。──
const POINTER_COLOR := Color("7B5E3E")
const POINTER_SIZE := Vector2(20.0, 36.0)
const SELECTED_NAME_INK := Color("9A6828")

# （2026-07-13 衬底换宣纸山水贴图：深靛 NIGHT_* 三常量与 _retint_background 退役——
#   背景图不透明满屏盖住 Background 节点·gallery_background.tscn 本体不动=英雄图鉴共用。）

const INK := Color(0.24, 0.19, 0.12)           # 墨（亮页主文字）
const INK_DIM := Color(0.48, 0.41, 0.28)       # 淡墨（次级/划线/注记）
# 方案 2：三档高识别上深下亮渐变，外框按母版明暗区映射同色系蓝 / 紫 / 金。
const CELL_FILL := ItemFrameStyle.CELL_TOP
const CELL_CENTER := ItemFrameStyle.CELL_BOTTOM
const FRAME_SHADOW := ItemFrameStyle.FRAME_SHADOW
const FRAME_MID := ItemFrameStyle.FRAME_MID
const FRAME_HIGHLIGHT := ItemFrameStyle.FRAME_HIGHLIGHT
const FRAME_ART_SCALE := ItemFrameStyle.FRAME_ART_SCALE
const FRAME_OFFSET_RATIO := ItemFrameStyle.FRAME_OFFSET_RATIO
# 新框实际内沿约为 5.7/68；用 5.5px 轻微压到框身下，避免放大后顶部露出纸色细缝。
const CELL_INSET_RATIO := ItemFrameStyle.CELL_INSET_RATIO

# 维度 → 语义色（与战斗动作按钮/抽卡同源·详情维度章用）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"), "中立": Color("8a8f98"),
	"博弈": Color("3f9a8f"), "趣味": Color("c86f8a"),
}
const DIM_FALLBACK := Color(0.42, 0.42, 0.47)

# 阶 → 稀有度色（普通蓝/稀有紫/传说金·Eddy 定）。
# ── 书本几何（书=居中实体·封皮包页块·夜色留边）──
const PAGE_R := Rect2(952, 158, 918, 836)

# ── 左页网格：每页 4 列 × 3 行 ──
const COLS := 4
const CARDS_PER_PAGE := 12
const BOX := 104.0       # 道具方框（正方·icon 居中其内）
const NAME_H := 36.0     # 框【外】下方名字带高
const STEP_X := 170.0
const ROW_H := 196.0

var _tier: int = 1
var _items: Array[ItemData] = []
var _item_catalog: Array[ItemData] = []
var _search_query := ""
var _search_active := false
var _cards: Array[Button] = []
var _sel_idx: int = -1
var _current_page: int = 0

# 详情板部件（_build_detail_panel 一次建好）
var _d_icon: TextureRect
var _d_icon_shadow: TextureRect
var _d_icon_fallback: Label
var _d_cell_mat: ShaderMaterial     # 右页大图鉴格底材质（稀有度色/传说金底按选中件重设·2026-07-14）
var _d_frame: TextureRect           # 右页大回纹阶框（128 源 ×2=256 整数放大·2026-07-14）
var _d_frame_mat: ShaderMaterial    # 新 item_frame 明暗母版的蓝 / 紫 / 金阶色映射
var _d_name: Label
var _d_rarity_mark: Control
var _d_rarity_label: Label
var _d_desc: Label
var _d_flavor: Label
var _d_pop_tween: Tween             # 右页图标落位微弹（快速方向键换件时先 kill 再建）
## 统一图鉴外壳会自行提供返回入口与章节切换；嵌入时不重复播放整本书的入场。
@export var embedded_in_codex: bool = false
var _sel_tweens: Array[Tween] = []  # 选中动效 tween（pop+呼吸·换选先 kill 全部）

@onready var item_grid: Control = $PoolArea/ItemGrid
@onready var page_navigation: Control = $PoolArea/PageNavigation
@onready var previous_page_btn: Button = $PoolArea/PageNavigation/PreviousPage
@onready var page_indicator: Label = $PoolArea/PageNavigation/PageIndicator
@onready var next_page_btn: Button = $PoolArea/PageNavigation/NextPage
@onready var detail_area: Control = $DetailArea
@onready var detail_navigation: Control = $DetailArea/DetailNavigation
@onready var previous_detail_btn: Button = $DetailArea/DetailNavigation/PreviousItem
@onready var detail_indicator: Label = $DetailArea/DetailNavigation/ItemIndicator
@onready var next_detail_btn: Button = $DetailArea/DetailNavigation/NextItem
@onready var _book_layer: Control = $BookLayer
@onready var back_btn: Button = $TopBand/BackButton
@onready var title_lbl: Label = $TopBand/Title
@onready var count_lbl: Label = $TopBand/CountLabel


func _ready() -> void:
	for tier: int in range(1, 4):
		_item_catalog.append_array(ItemCatalog.all_for_tier(tier))
	_build_book()
	_setup_top()
	_build_detail_panel()
	_setup_page_navigation()
	_setup_detail_navigation()
	_select_tier(1)
	if not embedded_in_codex:
		_play_intro()


# ============================================================
# 正视二维羊皮纸书素材
# ============================================================

func _build_book() -> void:
	var bg := get_node_or_null("Background") as Control
	if bg != null:
		bg.visible = false
	_book_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ============================================================
# 书页导航：返回、阶级索引与分页
# ============================================================

func _setup_top() -> void:
	var band := $TopBand as Control
	band.position = Vector2.ZERO
	band.size = Vector2(1920, 144)
	_style_back_button()
	title_lbl.visible = false
	count_lbl.visible = false


func _style_back_button() -> void:
	if embedded_in_codex:
		back_btn.visible = false
		back_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	back_btn.text = tr("<<< 返回")
	back_btn.focus_mode = Control.FOCUS_NONE
	FontManager.apply_btn(back_btn, 24)
	back_btn.add_theme_color_override("font_color", Color(0.180392, 0.160784, 0.133333, 0.92))
	back_btn.add_theme_color_override("font_hover_color", Color(0.419608, 0.290196, 0.196078, 1.0))
	back_btn.add_theme_color_override("font_pressed_color", Color(0.419608, 0.290196, 0.196078, 1.0))
	back_btn.add_theme_color_override("font_focus_color", Color(0.419608, 0.290196, 0.196078, 1.0))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		back_btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	back_btn.pressed.connect(_back_to_menu)
	if back_btn.get_node_or_null("ButtonJuice") == null:
		var bj := ButtonJuice.new()
		bj.name = "ButtonJuice"
		back_btn.add_child(bj)


func _setup_page_navigation() -> void:
	previous_page_btn.pressed.connect(_turn_page.bind(-1))
	next_page_btn.pressed.connect(_turn_page.bind(1))
	for button: Button in [previous_page_btn, next_page_btn]:
		if button.get_node_or_null("ButtonJuice") == null:
			var juice := ButtonJuice.new()
			juice.name = "ButtonJuice"
			button.add_child(juice)
	_refresh_page_visibility()


func _setup_detail_navigation() -> void:
	previous_detail_btn.pressed.connect(_turn_detail.bind(-1))
	next_detail_btn.pressed.connect(_turn_detail.bind(1))
	for button: Button in [previous_detail_btn, next_detail_btn]:
		if button.get_node_or_null("ButtonJuice") == null:
			var juice := ButtonJuice.new()
			juice.name = "ButtonJuice"
			button.add_child(juice)
	_refresh_detail_navigation()


func _catalog_item_count() -> int:
	if _search_active:
		return _items.size()
	var total := 0
	for tier: int in range(1, 4):
		total += ItemCatalog.all_for_tier(tier).size()
	return total


func _global_item_index() -> int:
	if _search_active:
		return maxi(_sel_idx, 0)
	var index := maxi(_sel_idx, 0)
	for tier: int in range(1, _tier):
		index += ItemCatalog.all_for_tier(tier).size()
	return index


func _refresh_detail_navigation() -> void:
	var total := _catalog_item_count()
	detail_navigation.visible = total > 0
	var current := clampi(_global_item_index(), 0, maxi(total - 1, 0))
	detail_indicator.text = "%02d / %02d" % [current + 1, total] if total > 0 else "00 / 00"
	previous_detail_btn.disabled = total == 0 or current <= 0
	next_detail_btn.disabled = total == 0 or current >= total - 1


func _turn_detail(direction: int) -> void:
	var total := _catalog_item_count()
	if total == 0:
		return
	if _search_active:
		_select(clampi(_sel_idx + direction, 0, _items.size() - 1))
		return
	var target := clampi(_global_item_index() + direction, 0, total - 1)
	for tier: int in range(1, 4):
		var tier_items: Array[ItemData] = ItemCatalog.all_for_tier(tier)
		if target < tier_items.size():
			_load_tier_item(tier, target)
			return
		target -= tier_items.size()


## 搜索覆盖三档道具，但数据边界仍严格限制在道具章节内。
func get_search_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item: ItemData in _item_catalog:
		entries.append({
			"id": StringName(item.item_id),
			"label": tr(item.item_name),
			"search_text": tr(item.item_name),
		})
	return entries


func set_search_query(query: String) -> void:
	var normalized := query.strip_edges().to_lower()
	if normalized == _search_query and (_search_active or normalized.is_empty()):
		return
	_search_query = normalized
	if normalized.is_empty():
		_search_active = false
		_load_tier_item(_tier, 0)
		detail_area.visible = not _items.is_empty()
		return
	_search_active = true
	_items.clear()
	for item: ItemData in _item_catalog:
		var searchable := tr(item.item_name)
		if searchable.to_lower().contains(normalized):
			_items.append(item)
	_sel_idx = -1
	_current_page = 0
	if not _items.is_empty():
		_tier = _items[0].tier
	_build_pool()
	_refresh_page_visibility()
	detail_area.visible = not _items.is_empty()
	if not _items.is_empty():
		_select(0)
	else:
		_refresh_detail_navigation()


func search_result_count() -> int:
	return _items.size()


func select_search_result(entry_id: StringName) -> void:
	for tier: int in range(1, 4):
		var tier_items: Array[ItemData] = ItemCatalog.all_for_tier(tier)
		for index: int in tier_items.size():
			if StringName(tier_items[index].item_id) == entry_id:
				_load_tier_item(tier, index)
				return


func _grid_float(property_name: StringName, fallback: float) -> float:
	var value: Variant = item_grid.get(property_name)
	return float(value) if value != null else fallback


func _grid_columns() -> int:
	return maxi(roundi(_grid_float(&"columns", COLS)), 1)


func _grid_page_size() -> int:
	return maxi(roundi(_grid_float(&"cards_per_page", CARDS_PER_PAGE)), 1)


func _grid_box_size() -> float:
	return maxf(_grid_float(&"box_size", BOX), 48.0)


func _page_count() -> int:
	return maxi(ceili(_items.size() / float(_grid_page_size())), 1)


func _catalog_pages() -> Array[Vector2i]:
	var pages: Array[Vector2i] = []
	for tier: int in range(1, 4):
		var tier_items: Array[ItemData] = ItemCatalog.all_for_tier(tier)
		if tier_items.is_empty():
			continue
		var tier_page_count := ceili(tier_items.size() / float(_grid_page_size()))
		for local_page: int in tier_page_count:
			pages.append(Vector2i(tier, local_page))
	return pages


func _catalog_page_count() -> int:
	if _search_active:
		return _page_count()
	return _catalog_pages().size()


func _global_page_index() -> int:
	if _search_active:
		return _current_page
	var index := _catalog_pages().find(Vector2i(_tier, _current_page))
	return maxi(index, 0)


func _refresh_page_visibility() -> void:
	var page_size := _grid_page_size()
	var first_index := _current_page * page_size
	var last_index := mini(first_index + page_size, _cards.size())
	for index in _cards.size():
		var card := _cards[index]
		card.visible = index >= first_index and index < last_index
		if card.visible:
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
	var total_pages := maxi(_catalog_page_count(), 1)
	var global_page := _global_page_index()
	page_navigation.visible = total_pages > 1
	page_indicator.text = "%02d / %02d" % [global_page + 1, total_pages]
	previous_page_btn.disabled = global_page <= 0
	next_page_btn.disabled = global_page >= total_pages - 1


func _turn_page(direction: int) -> void:
	if _search_active:
		var target_page := clampi(_current_page + direction, 0, _page_count() - 1)
		if target_page == _current_page:
			return
		var local_slot := _sel_idx % _grid_page_size() if _sel_idx >= 0 else 0
		_select(mini(target_page * _grid_page_size() + local_slot, _items.size() - 1))
		return
	var pages := _catalog_pages()
	if pages.is_empty():
		return
	var current_global := _global_page_index()
	var target_global := clampi(current_global + direction, 0, pages.size() - 1)
	if target_global == current_global:
		return
	var page_size := _grid_page_size()
	var local_slot := _sel_idx % page_size if _sel_idx >= 0 else 0
	var target_page := pages[target_global]
	var target_items: Array[ItemData] = ItemCatalog.all_for_tier(target_page.x)
	var target_index := mini(target_page.y * page_size + local_slot, target_items.size() - 1)
	if target_page.x == _tier:
		_select(target_index)
	else:
		_load_tier_item(target_page.x, target_index)


func _grid_card_position(index: int, cols: int, step_x: float, row_height: float) -> Vector2:
	var row := floori(index / float(cols))
	var column := index % cols
	var center_column := (cols - 1) * 0.5
	var normalized_edge := absf(float(column) - center_column) / maxf(center_column, 1.0)
	return Vector2(
		column * step_x + float(row % 2) * _grid_float(&"row_stagger_x", 0.0),
		row * row_height
			+ normalized_edge * normalized_edge * _grid_float(&"page_curve_y", 0.0))


# ============================================================
# 左页网格：按当前书页所属稀有度重建
# ============================================================

## 调试与测试入口：直接打开某一稀有度的第一页；正式浏览只通过连续翻页进入。
func _select_tier(t: int) -> void:
	_load_tier_item(clampi(t, 1, 3), 0)


## 统一图鉴侧签的公开入口；保留 _select_tier 供既有调试与测试调用。
func select_tier(t: int) -> void:
	_select_tier(t)


func get_current_tier() -> int:
	return _tier


func _load_tier_item(tier: int, item_index: int) -> void:
	_tier = clampi(tier, 1, 3)
	_items = ItemCatalog.all_for_tier(_tier)
	_sel_idx = -1
	var safe_index := clampi(item_index, 0, maxi(_items.size() - 1, 0))
	_current_page = floori(safe_index / float(_grid_page_size())) if not _items.is_empty() else 0
	_build_pool()
	_refresh_page_visibility()
	if not _items.is_empty():
		_select(safe_index)
	tier_changed.emit(_tier)


func _adjacent_nonempty_tier(direction: int) -> int:
	var candidate := _tier + signi(direction)
	while candidate >= 1 and candidate <= 3:
		if not ItemCatalog.all_for_tier(candidate).is_empty():
			return candidate
		candidate += signi(direction)
	return 0


func _step_catalog_selection(step: int) -> void:
	var target_index := _sel_idx + step
	if target_index >= 0 and target_index < _items.size():
		_select(target_index)
		return
	if target_index >= _items.size():
		var next_tier := _adjacent_nonempty_tier(1)
		if next_tier == 0:
			_select(_items.size() - 1)
			return
		var overflow := target_index - _items.size()
		var next_items: Array[ItemData] = ItemCatalog.all_for_tier(next_tier)
		_load_tier_item(next_tier, mini(overflow, next_items.size() - 1))
		return
	var previous_tier := _adjacent_nonempty_tier(-1)
	if previous_tier == 0:
		_select(0)
		return
	var previous_items: Array[ItemData] = ItemCatalog.all_for_tier(previous_tier)
	_load_tier_item(previous_tier, maxi(previous_items.size() + target_index, 0))


func _build_pool() -> void:
	for c: Node in item_grid.get_children():
		item_grid.remove_child(c)
		c.free()
	_cards.clear()
	var cols := _grid_columns()
	var page_size := _grid_page_size()
	var step_x := _grid_float(&"step_x", STEP_X)
	var row_height := _grid_float(&"row_height", ROW_H)
	for i in _items.size():
		var card := _make_item_card(_items[i], i)
		card.position = _grid_card_position(i % page_size, cols, step_x, row_height)
		item_grid.add_child(card)
		_cards.append(card)
	item_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_tier_frame_material(tier: int) -> ShaderMaterial:
	return ItemFrameStyle.make_frame_material(tier)


func _set_tier_frame_palette(m: ShaderMaterial, tier: int) -> void:
	ItemFrameStyle.apply_frame_palette(m, tier)


func _set_item_frame_selected(frame: TextureRect, tier: int, _selected: bool) -> void:
	var material := frame.material as ShaderMaterial
	# 选中不再把蓝/紫阶级框覆盖成旧金框；语义色在所有交互状态保持稳定。
	_set_tier_frame_palette(material, tier)


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


## 单件道具卡。选中态与英雄图鉴一致：真实框转金，左侧显示单色粗像素三角箭头。
func _make_item_card(item: ItemData, idx: int) -> Button:
	var box := _grid_box_size()
	var card := Button.new()
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.size = Vector2(box, box + NAME_H)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	card.add_child(_make_selection_pointer(box))
	# 格底：三档均使用稀有度整格纵向渐变填充。
	var slot_rect := Rect2(Vector2.ZERO, Vector2(box, box))
	var frame_position := slot_rect.position + slot_rect.size * FRAME_OFFSET_RATIO
	var frame_size := slot_rect.size * FRAME_ART_SCALE
	var cell_inset := box * CELL_INSET_RATIO
	var cell := ColorRect.new()
	cell.name = "Cell"
	cell.color = Color.WHITE
	cell.position = slot_rect.position + Vector2.ONE * cell_inset
	cell.size = slot_rect.size - Vector2.ONE * cell_inset * 2.0
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ItemFrameStyle.make_cell_material(item.tier, box / 6.0)
	cell.material = cm
	card.add_child(cell)
	var tex: Texture2D = ItemCatalog.load_icon(item.item_id)
	var isz := box * (70.0 / 92.0)
	var icon_position := Vector2((box - isz) * 0.5, (box - isz) * 0.5)
	var icon_size := Vector2(isz, isz)
	if tex != null:
		card.add_child(ItemFrameStyle.make_item_art_shadow(
				tex, icon_position, icon_size))
	# 回纹阶框（2026-07-13 换皮：头像框素材同源换色三阶变体·原稀有度像素框 shader 退役）
	var frame := TextureRect.new()
	frame.name = "Frame"   # 选中提亮要取（2026-07-14）
	frame.texture = ITEM_FRAME_TEX
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.position = frame_position
	frame.size = frame_size
	frame.material = _make_tier_frame_material(item.tier)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	# 图标（居中于暗格）
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.position = icon_position
		icon.size = icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
	# 名字（框外下方·亮页墨字直读）
	var name_lbl := Label.new()
	name_lbl.name = "ItemName"
	name_lbl.text = tr(item.item_name)
	name_lbl.position = Vector2(-16.0, box + 4.0)
	name_lbl.size = Vector2(box + 32.0, NAME_H)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FontManager.apply(name_lbl, 17)
	name_lbl.add_theme_color_override("font_color", INK)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)
	card.pressed.connect(_select.bind(idx))
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	card.add_child(bj)
	return card


# ============================================================
# 右页：单列居中主轴。
#   ①名字 → ②大号图鉴格 → ③效果描述 → ④风味文字
#   稀有度只由左页阶级索引、框色和名字墨色表达；不再重复显示页内阶章或分隔线。
# ============================================================

func _build_detail_panel() -> void:
	_d_name = $DetailArea/ItemName as Label
	var detail_cell := $DetailArea/DetailCell as ColorRect
	detail_cell.material = detail_cell.material.duplicate()
	_d_cell_mat = detail_cell.material as ShaderMaterial
	_d_frame = $DetailArea/DetailFrame as TextureRect
	_d_frame.material = _d_frame.material.duplicate()
	_d_frame_mat = _d_frame.material as ShaderMaterial
	_d_icon_shadow = $DetailArea/ItemArtShadow as TextureRect
	_d_icon_shadow.self_modulate = ItemFrameStyle.ITEM_ART_SHADOW_COLOR
	_d_icon = $DetailArea/ItemIcon as TextureRect
	_d_icon_fallback = $DetailArea/ItemIconFallback as Label
	_d_rarity_mark = $DetailArea/RarityBadge/TypeMark as Control
	_d_rarity_label = $DetailArea/RarityBadge/BadgeLabel as Label
	_d_desc = $DetailArea/Description as Label
	_d_flavor = $DetailArea/Flavor as Label


## 选中某件道具：左卡使用英雄图鉴同款金框与书页棕三角箭头；右页同步详情。
func _select(idx: int) -> void:
	if idx < 0 or idx >= _items.size():
		return
	var target_page := floori(idx / float(_grid_page_size()))
	if target_page != _current_page:
		_current_page = target_page
		_refresh_page_visibility()
	if _sel_idx == idx:
		return
	for tw: Tween in _sel_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_sel_tweens.clear()
	if _sel_idx >= 0 and _sel_idx < _cards.size():
		var old := _cards[_sel_idx]
		var old_pointer := old.get_node("SelectionPointer") as Control
		var old_pointer_home: Vector2 = old_pointer.get_meta("home_position")
		old_pointer.visible = false
		old_pointer.modulate = Color.WHITE
		old_pointer.position = old_pointer_home
		_set_item_frame_selected(old.get_node("Frame") as TextureRect,
				_items[_sel_idx].tier, false)
		(old.get_node("ItemName") as Label).add_theme_color_override("font_color", INK)
	_sel_idx = idx
	_play_select_fx(_cards[idx])

	var it := _items[idx]
	var tex: Texture2D = ItemCatalog.load_icon(it.item_id)
	if tex != null:
		_d_icon.texture = tex
		_d_icon_shadow.texture = tex
		_d_icon_shadow.visible = true
		_d_icon.visible = true
		_d_icon_fallback.visible = false
	else:
		_d_icon_shadow.visible = false
		_d_icon.visible = false
		_d_icon_fallback.text = tr(it.item_name)
		_d_icon_fallback.visible = true
	# 右页大格跟随稀有度（材质持久·三参数每次重设：普通/稀有=色对·传说=金底图）
	_set_tier_frame_palette(_d_frame_mat, it.tier)
	ItemFrameStyle.apply_cell_palette(_d_cell_mat, it.tier)
	# 图标落位微弹（0.12s·换件时右页也有反馈·快速方向键连按先 kill）
	if _d_pop_tween != null and _d_pop_tween.is_valid():
		_d_pop_tween.kill()
	_d_icon.pivot_offset = _d_icon.size * 0.5
	_d_icon_shadow.pivot_offset = _d_icon_shadow.size * 0.5
	_d_icon.scale = Vector2(1.06, 1.06)
	_d_icon_shadow.scale = Vector2(1.06, 1.06)
	_d_pop_tween = create_tween().set_parallel(true)
	_d_pop_tween.tween_property(_d_icon, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_d_pop_tween.tween_property(_d_icon_shadow, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_d_name.text = tr(it.item_name)
	_d_name.add_theme_color_override("font_color", DETAIL_NAME_INK)
	_d_rarity_label.text = tr(TIER_LABEL[it.tier])
	_d_rarity_label.add_theme_color_override("font_color", Color.WHITE)
	var tag_color: Color = TIER_TAG_COLOR[it.tier]
	_d_rarity_mark.set("passive_color", tag_color)
	_d_rarity_mark.set("active_color", tag_color)
	_d_rarity_mark.call("set_passive", true)
	# 与英雄说明一致从固定顶边起笔；垂直居中会让不同换行数的首行高度发生跳动。
	_d_desc.text = EffectTextFormatterScript.protect_cjk_line_breaks(
			tr(it.description).strip_edges())
	_d_flavor.text = EffectTextFormatterScript.protect_cjk_line_breaks(tr(it.flavor))
	_refresh_detail_navigation()


## 选中动效：真实框立即转金，英雄图鉴同款粗像素棕色箭头轻推入并静止。
func _play_select_fx(card: Button) -> void:
	var pointer := card.get_node("SelectionPointer") as Control
	_set_item_frame_selected(card.get_node("Frame") as TextureRect,
			_items[_sel_idx].tier, true)
	(card.get_node("ItemName") as Label).add_theme_color_override(
			"font_color", SELECTED_NAME_INK)
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
		step = -_grid_columns()
	elif event.is_action_pressed("ui_down"):
		step = _grid_columns()
	if step != 0 and _sel_idx >= 0 and not _items.is_empty():
		_step_catalog_selection(step)
		get_viewport().set_input_as_handled()


## 战斗内嵌模式（battle_codex_overlay 注入）：有效时「返回/ESC」改走关闭浮层，不切场景。
var embedded_close: Callable = Callable()


func _back_to_menu() -> void:
	if embedded_close.is_valid():
		embedded_close.call()
		return
	TransitionManager.transition_to(MENU_SCENE)


## 入场：返回滑入 + 书轻微上浮 + 当前页卡按行翻开扫过 + 右页淡入。
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
	for i in _cards.size():
		var card := _cards[i]
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

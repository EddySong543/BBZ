class_name ItemDraftPopup
extends Control

## 道具 3 选 1 弹窗（抽取 / 升级·M3）：模态全屏暗幕 + 居中候选卡。
## 卡面 = 纸卡贴图（2026-07-14 卡衬纸落位：悬停框族语竖版=近黑框+奶油纸+回纹角·jelly 稀有度色芯片退役）。
## 稀有度表达：卡名墨色三阶 TIER_INK（图鉴同源·⛔整卡染色）+ 单一 item_frame 母版运行时换色；
## 描述=墨字直书纸面（暗衬 scrim / 白字描边随亮纸退役）。
## 用法：实例化 → add_child（覆盖在 battle_screen 上）→ setup(options, can_cancel, title)
##   → `var choice: int = await popup.resolved`（返回选中 index；-1 = 取消）→ 调用方 queue_free。

signal resolved(choice: int)

const CARD_W := 263.0                 # =贴图实寸（源 1052×1420 ÷4 整数倍降采样·2026-07-14）
const CARD_H := 355.0
const CARD_GAP := 28.0
const EffectTextFormatterScript := preload("res://src/ui/effect_text_formatter.gd")
const PAGE_SIZE := 3
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

const CARD_TEX := preload("res://assets/ui/item_draft_card.png")     # 纸卡衬纸（悬停框族语竖版）
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")  # 取消钮底板（全游戏导航一个语言）
const ENERGY_COST_SHEET := preload("res://assets/ui/icons/energy_idle.png")
const DURABILITY_BADGE_ICON := preload("res://assets/ui/icons/item_durability.png")
const ITEM_FRAME_TEX := ItemFrameStyle.FRAME_TEXTURE
# 兼容既有调用/测试的公开别名；真实值只在 ItemFrameStyle 中维护。
const CELL_FILL := ItemFrameStyle.CELL_TOP
const CELL_CENTER := ItemFrameStyle.CELL_BOTTOM
const FRAME_SHADOW := ItemFrameStyle.FRAME_SHADOW
const FRAME_MID := ItemFrameStyle.FRAME_MID
const FRAME_HIGHLIGHT := ItemFrameStyle.FRAME_HIGHLIGHT
const FRAME_ART_SCALE := ItemFrameStyle.FRAME_ART_SCALE
const FRAME_OFFSET_RATIO := ItemFrameStyle.FRAME_OFFSET_RATIO
const CELL_INSET_RATIO := ItemFrameStyle.CELL_INSET_RATIO
const TIER_INK := ItemFrameStyle.FRAME_MID  # 卡名与对应稀有度框主体色同源，卡面本身不染色。
const INK := Color(0.24, 0.19, 0.12)  # 墨字（亮纸主文字·与战斗悬停提示同源）

var _can_cancel := true
var _done := false   # 防重复 resolve（连点 / ESC 抢答）
var _options: Array = []
var _page: int = 0
var _cards: Array[Control] = []
var _page_label: Label
var _prev_button: Button
var _next_button: Button


func _make_tier_frame_material(tier: int) -> ShaderMaterial:
	return ItemFrameStyle.make_frame_material(tier)


func _make_item_stat_badge(name_value: String, texture: Texture2D,
		hframes_value: int, vframes_value: int, number: int,
		badge_position: Vector2, badge_size: Vector2) -> IconBadge:
	var badge := IconBadge.new()
	badge.name = name_value
	badge.position = badge_position
	badge.size = badge_size
	badge.z_index = 20
	badge.set_icon(texture, hframes_value, vframes_value, 0)
	badge.set_number(number)
	badge.normalize_icon_visual = true
	badge.icon_visual_ratio = 0.82
	badge.font_size = 13
	badge.outline_size = 4
	badge.embolden = 0.7
	return badge


func setup(options: Array, can_cancel: bool = true, title_text: String = "抽取道具（3 选 1）") -> void:
	_can_cancel = can_cancel
	_options = options.duplicate()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 吃掉所有背景点击（模态）

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var title := Label.new()
	title.text = tr(title_text)   # 区分「抽取」/「升级」3 选 1
	title.position = Vector2(0.0, SCREEN_H * 0.5 - CARD_H * 0.5 - 70.0)
	title.size = Vector2(SCREEN_W, 48.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var card_y: float = (SCREEN_H - CARD_H) * 0.5
	_build_page()
	if _options.size() > PAGE_SIZE:
		_prev_button = _make_nav_button(tr("上一页"), Vector2(430.0, card_y + CARD_H + 36.0))
		_next_button = _make_nav_button(tr("下一页"), Vector2(SCREEN_W - 590.0, card_y + CARD_H + 36.0))
		_prev_button.pressed.connect(_change_page.bind(-1))
		_next_button.pressed.connect(_change_page.bind(1))
		add_child(_prev_button)
		add_child(_next_button)
		_page_label = Label.new()
		_page_label.position = Vector2(SCREEN_W * 0.5 - 80.0, card_y + CARD_H + 36.0)
		_page_label.size = Vector2(160.0, 48.0)
		_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_page_label.add_theme_color_override("font_color", INK)
		add_child(_page_label)
		_refresh_page_nav()

	if can_cancel:
		var cancel := _make_nav_button(tr("取消"), Vector2(
			(SCREEN_W - 160.0) * 0.5,
			card_y + CARD_H + (94.0 if _options.size() > PAGE_SIZE else 36.0)))
		cancel.pressed.connect(_resolve.bind(-1))
		add_child(cancel)


func _make_nav_button(label: String, position_value: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.size = Vector2(160.0, 48.0)
	button.position = position_value
	button.focus_mode = Control.FOCUS_NONE
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", INK)
	var plate := NinePatchRect.new()
	plate.texture = NAV_PLATE_TEX
	plate.patch_margin_left = 22
	plate.patch_margin_right = 22
	plate.patch_margin_top = 20
	plate.patch_margin_bottom = 20
	plate.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.show_behind_parent = true
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(plate)
	return button


func _build_page() -> void:
	for card in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()
	var first: int = _page * PAGE_SIZE
	var count: int = mini(PAGE_SIZE, _options.size() - first)
	var total_w: float = count * CARD_W + maxf(0.0, (count - 1)) * CARD_GAP
	var start_x: float = (SCREEN_W - total_w) * 0.5
	var card_y: float = (SCREEN_H - CARD_H) * 0.5
	for local_index in range(count):
		var option_index: int = first + local_index
		var card: Control = _build_card(_options[option_index], Vector2(
			start_x + local_index * (CARD_W + CARD_GAP), card_y), option_index)
		_cards.append(card)


func _change_page(delta: int) -> void:
	var page_count: int = ceili(float(_options.size()) / float(PAGE_SIZE))
	_page = clampi(_page + delta, 0, page_count - 1)
	_build_page()
	_refresh_page_nav()


func _refresh_page_nav() -> void:
	var page_count: int = ceili(float(_options.size()) / float(PAGE_SIZE))
	_prev_button.disabled = _page <= 0
	_next_button.disabled = _page >= page_count - 1
	_page_label.text = tr("%d / %d") % [_page + 1, page_count]


func _build_card(item: ItemData, pos: Vector2, idx: int) -> Control:
	var card := Button.new()
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.position = pos
	card.size = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("normal", StyleBoxEmpty.new())   # 去默认按钮底 → 露出 jelly
	card.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	card.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	card.pressed.connect(_resolve.bind(idx))
	add_child(card)

	var tier: int = item.tier if item != null else 1
	# 卡面=纸卡贴图（2026-07-14 卡衬纸·jelly 芯片退役）。子节点全 IGNORE，点击穿透到 card。
	var bg := TextureRect.new()
	bg.texture = CARD_TEX
	bg.position = Vector2.ZERO
	bg.size = Vector2(CARD_W, CARD_H)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg)

	# 图标（缺图 → 描述区上移占满）。
	var tex: Texture2D = ItemCatalog.load_icon(item.item_id) if item != null else null
	var desc_top := 244.0 if tex != null else 116.0

	var name_lbl := Label.new()
	name_lbl.text = tr(item.item_name) if item != null else "?"
	name_lbl.position = Vector2(24.0, 24.0)
	name_lbl.size = Vector2(CARD_W - 48.0, 56.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", TIER_INK.get(tier, INK))   # 稀有度=名字墨色（亮纸免描边）
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	if tex != null:
		# 格底（图鉴格同配方：三档完整上深下亮渐变）——铺在阶框下。
		var slot_rect := Rect2(Vector2(CARD_W * 0.5 - 64.0, 92.0), Vector2(128.0, 128.0))
		var frame_position := slot_rect.position + slot_rect.size * FRAME_OFFSET_RATIO
		var frame_size := slot_rect.size * FRAME_ART_SCALE
		card.add_child(ItemFrameStyle.make_frame_shadow(
				frame_position, frame_size, "BottomShadow"))
		var cell_inset := slot_rect.size.x * CELL_INSET_RATIO
		var cell := ColorRect.new()
		cell.name = "ItemCell"
		cell.color = Color.WHITE
		cell.position = slot_rect.position + Vector2.ONE * cell_inset
		cell.size = slot_rect.size - Vector2.ONE * cell_inset * 2.0
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 与图鉴/战斗栏共用纵向渐变、传说贴图与统一内孔比例。
		var cm := ItemFrameStyle.make_cell_material(tier, 128.0 / 6.0)
		cell.material = cm
		card.add_child(cell)
		var icon_position := Vector2(CARD_W * 0.5 - 48.0, 108.0)
		var icon_size := Vector2(96.0, 96.0)
		card.add_child(ItemFrameStyle.make_item_art_shadow(
				tex, icon_position, icon_size))
		# 阶框+图标：补偿新素材透明边，使金属外沿仍与 128px 图标槽对齐。
		var frame := TextureRect.new()
		frame.name = "ItemFrame"
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.texture = ITEM_FRAME_TEX
		frame.position = frame_position
		frame.size = frame_size
		frame.material = _make_tier_frame_material(tier)
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
		var icon := TextureRect.new()
		icon.name = "ItemIcon"
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素清晰
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ItemFrameStyle.configure_item_art(icon, tex, Rect2(icon_position, icon_size))
		card.add_child(icon)
		var badge_size := Vector2(40.0, 40.0)
		var positions := ItemFrameStyle.stat_badge_positions(
			Rect2(frame_position, frame_size), badge_size)
		card.add_child(_make_item_stat_badge(
			"UseCostBadge", ENERGY_COST_SHEET, 4, 4, item.use_cost,
			positions["cost"], badge_size))
		card.add_child(_make_item_stat_badge(
			"DurabilityBadge", DURABILITY_BADGE_ICON, 1, 1, item.max_durability,
			positions["durability"], badge_size))

	# 分隔墨线（图鉴右页同手法）。
	var divider := ColorRect.new()
	divider.color = Color(INK.r, INK.g, INK.b, 0.45)
	divider.position = Vector2(40.0, desc_top - 14.0)
	divider.size = Vector2(CARD_W - 80.0, 2.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(divider)

	# 描述=墨字直书纸面·定宽手动换行（2026-07-11 Eddy：AUTOWRAP 在长中文描述上溢出卡底被截）：
	# 每行统一字数（宽度/字号），行数超出描述区高度 → 降号 16→12（Z工坊 12px 基准）重排。
	var desc_text: String = tr(item.description) if item != null else ""
	var box_w := CARD_W - 60.0
	var box_h := CARD_H - desc_top - 28.0
	var f_size := 16
	var per_line := int(box_w / f_size)
	if ceilf(desc_text.length() / float(per_line)) * f_size * 1.4 > box_h:
		f_size = 12
		per_line = int(box_w / f_size)
	var desc_lbl := Label.new()
	desc_lbl.text = _wrap_fixed(desc_text, per_line)
	desc_lbl.position = Vector2(30.0, desc_top)
	desc_lbl.size = Vector2(box_w, box_h)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_lbl.add_theme_font_size_override("font_size", f_size)
	desc_lbl.add_theme_color_override("font_color", INK)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc_lbl)
	return card


## 手动定宽换行：每行固定 chars 个字符（CJK 等宽·统一每行字数·保留已有换行）。
func _wrap_fixed(text: String, chars: int) -> String:
	return EffectTextFormatterScript.wrap_fixed_cjk(text, chars)


func _input(event: InputEvent) -> void:
	if _can_cancel and event.is_action_pressed("ui_cancel"):
		accept_event()
		_resolve(-1)


func _resolve(choice: int) -> void:
	if _done:
		return
	_done = true
	resolved.emit(choice)

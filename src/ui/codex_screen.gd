extends Control
class_name CodexScreen

## 英雄、道具与效果共享同一本图鉴；此节点负责烟褐衬底、统一缩书构图与左缘夹页索引。
## 三套书页仍在各自的 1920x1080 设计坐标中运行，不重排内部节点。

signal section_changed(section: int)

enum Section { HERO, ITEM, EFFECT }

const MAIN_MENU_SCENE := "res://src/ui/main_menu.tscn"
const GALLERY_SCENES: Array[PackedScene] = [
	preload("res://src/ui/hero_gallery_screen.tscn"),
	preload("res://src/ui/item_gallery_screen.tscn"),
	preload("res://src/ui/effect_gallery_screen.tscn"),
]
const GALLERY_NODE_PATHS: Array[NodePath] = [
	NodePath("HeroGallery"), NodePath("ItemGallery"), NodePath("EffectGallery"),
]
const ItemCatalogScript := preload("res://src/battle/item_catalog.gd")
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const BOOK_SCALE := Vector2(0.84, 0.84)
const BOOK_ORIGIN := (DESIGN_SIZE - DESIGN_SIZE * BOOK_SCALE) * 0.5
const BOOKMARK_LAYER_ORIGIN := Vector2.ZERO
const BOOKMARK_LAYER_SCALE := Vector2.ONE
const INK := Color("34281D")
const INK_SOFT := Color("675746")
const BOOKMARK_HOVER_MODULATE := Color(1.0, 0.975, 0.93, 1.0)
const BOOKMARK_SHADOW_OFFSET := Vector2(4.0, 5.0)
const BOOKMARK_SHADOW_COLOR := Color(0.164706, 0.12549, 0.0941176, 0.38)
const RARITY_STRIPE_COLORS: Array[Color] = [
	ItemCatalogScript.RARITY_NORMAL,
	ItemCatalogScript.RARITY_RARE,
	ItemCatalogScript.RARITY_LEGENDARY,
]
const CHAPTER_SELECTED_X := 9.6
const CHAPTER_IDLE_X := 9.6
const RARITY_SELECTED_X := 0.0
const RARITY_IDLE_X := 0.0
const PRESS_INSET := 1.0
const OVERLAY_BACKDROP_ALPHA := 0.30
const OVERLAY_OPEN_DURATION := 0.18
const OVERLAY_OPEN_LIFT := Vector2(0.0, 12.0)
const OVERLAY_CLOSE_DURATION := 0.14
const OVERLAY_CLOSE_DROP := Vector2(0.0, 10.0)
const TAB_HOVER_DURATION := 0.07
const PRESS_RELEASE_DURATION := 0.04
const RARITY_TARGET_Y: Array[float] = [0.0, 50.0, 100.0]
const EFFECT_BOOKMARK_REST_Y := 366.75
const EFFECT_BOOKMARK_ITEM_Y := 532.75
const CHAPTER_IDLE_TEXT_INSET := 26.0
const RARITY_IDLE_TEXT_INSET := 17.0
const BACK_IDLE_COLOR := INK_SOFT
const BACK_HOVER_COLOR := INK
const BACK_ARROW_REST_POSITION := Vector2(30.0, 20.0)
const BACK_ARROW_HOVER_SHIFT := Vector2(-1.0, 0.0)
const BACK_ARROW_PRESS_SHIFT := Vector2(1.0, 0.0)
const CLOSE_IDLE_COLOR := Color("4A3A2D")
const CLOSE_HOVER_COLOR := Color("9A6828")
const CLOSE_PRESSED_COLOR := Color("2F241B")
const SEARCH_PLACEHOLDER := "搜索..."
const CLOSE_STYLE_STATES: Array[StringName] = [
	&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled",
	&"normal_mirrored", &"hover_mirrored", &"pressed_mirrored",
	&"hover_pressed_mirrored", &"disabled_mirrored",
]

@export_enum("英雄", "道具", "效果") var initial_section: int = Section.HERO
@export_group("侧签选中动画", "bookmark_fold_")
## 越接近 1，纸签收窄幅度越小；建议保持在 0.70–0.88。
@export_range(0.55, 0.92, 0.01) var bookmark_fold_min_scale := 0.78
@export_range(0.02, 0.20, 0.005) var bookmark_fold_collapse_duration := 0.075
@export_range(0.02, 0.20, 0.005) var bookmark_fold_expand_duration := 0.09
@export_group("搜索彩蛋")
@export_range(0.0, 1.0, 0.01) var search_cat_easter_egg_chance := 0.10

@onready var gallery_host: Control = $GalleryHost
@onready var native_text_layer: CodexNativeTextLayer = $NativeTextLayer
@onready var backdrop: TextureRect = $Backdrop
@onready var backdrop_motion: ColorRect = $BackdropMotion
@onready var bookmark_layer: Control = $BookmarkLayer
@onready var hero_bookmark: Button = $BookmarkLayer/HeroBookmark
@onready var item_bookmark: Button = $BookmarkLayer/ItemBookmark
@onready var effect_bookmark: Button = $BookmarkLayer/EffectBookmark
@onready var rarity_bookmarks: Control = $BookmarkLayer/RarityBookmarks
@onready var rarity_buttons: Array[Button] = [
	$BookmarkLayer/RarityBookmarks/Normal,
	$BookmarkLayer/RarityBookmarks/Rare,
	$BookmarkLayer/RarityBookmarks/Legendary,
]
@onready var book_contact_shadow: ColorRect = $BookContactShadow
@onready var close_button: Button = $CloseButton
@onready var search_control: Control = $SearchControl
@onready var search_button: Button = $SearchControl/SearchButton
@onready var search_frame: CodexSearchFieldFrame = $SearchControl/SearchFieldFrame
@onready var search_input: LineEdit = $SearchControl/SearchInput
@onready var search_curved_text: CodexSearchCurvedText = $SearchControl/SearchCurvedText
@onready var search_clear_button: Button = $SearchControl/SearchClearButton
@onready var search_empty_state: Control = $SearchEmptyState
@onready var search_empty_left: Label = $SearchEmptyState/LeftMessage
@onready var search_empty_right: Label = $SearchEmptyState/RightMessage
@onready var search_empty_cat_group: Control = $SearchEmptyState/CatGroup
@onready var back_button: Button = $BackButton
@onready var back_arrow: Polygon2D = $BackButton/BackArrow
@onready var back_text: Label = $BackButton/BackText

var embedded_close: Callable = Callable()
var current_section: int = -1
var _galleries: Array[Control] = [null, null, null]
var _tab_tweens: Dictionary = {}
var _hover_tweens: Dictionary = {}
var _press_tweens: Dictionary = {}
var _hovered_tabs: Dictionary = {}
var _bookmark_selected_states: Dictionary = {}
var _bookmark_fold_scales: Dictionary = {}
var _rarity_group_tween: Tween
var _overlay_open_tween: Tween
var _overlay_close_tween: Tween
var _applied_search_query := ""
var _showing_search_cat_egg := false


func _ready() -> void:
	# 主签始终压在二级签上方；二级签只离散显隐，不再做弹性位移。
	effect_bookmark.move_to_front()
	item_bookmark.move_to_front()
	hero_bookmark.pressed.connect(show_section.bind(Section.HERO))
	item_bookmark.pressed.connect(show_section.bind(Section.ITEM))
	effect_bookmark.pressed.connect(show_section.bind(Section.EFFECT))
	for index: int in rarity_buttons.size():
		rarity_buttons[index].pressed.connect(_on_rarity_pressed.bind(index + 1))
	for button: Button in _all_bookmarks():
		button.offset_transform_enabled = true
		button.offset_transform_visual_only = true
		button.offset_transform_position = Vector2.ZERO
		button.button_down.connect(_on_bookmark_down.bind(button))
		button.button_up.connect(_on_bookmark_up.bind(button))
		button.mouse_entered.connect(_on_bookmark_hover.bind(button, true))
		button.mouse_exited.connect(_on_bookmark_hover.bind(button, false))
	_apply_bookmark_fonts()
	_apply_rarity_stripe_colors()
	_setup_back_button()
	_setup_close_button()
	_setup_search()
	_configure_embedded_overlay()
	# 图鉴已经统一为场景内浮层；旧返回签只保留为历史节点，不再参与运行时布局或输入。
	back_button.visible = false
	back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 三个章节都在首帧预热并保持隐藏，切换时不会再暴露子图鉴的透明入场帧。
	for section: int in [Section.HERO, Section.ITEM, Section.EFFECT]:
		get_gallery(section)
	show_section(clampi(initial_section, Section.HERO, Section.EFFECT))


func show_section(section: int) -> void:
	var safe_section := clampi(section, Section.HERO, Section.EFFECT)
	var previous_section := current_section
	var gallery := get_gallery(safe_section)
	# 每次重新进入道具章节都从普通第一页开始；缓存只复用节点，不再复用浏览位置。
	if safe_section == Section.ITEM and previous_section != Section.ITEM:
		gallery.call("select_tier", 1)
	for index: int in _galleries.size():
		var cached := _galleries[index]
		if cached == null:
			continue
		var is_active := index == safe_section
		cached.visible = is_active
		cached.set_process_unhandled_input(is_active)
	current_section = safe_section
	_apply_search_to_gallery(gallery)
	native_text_layer.set_source_root(gallery)
	_refresh_search_empty_state()
	_refresh_search_scope()
	var animate := previous_section >= 0 and previous_section != current_section
	_refresh_chapter_bookmarks(animate)
	_position_effect_bookmark(current_section == Section.ITEM, animate)
	if current_section == Section.ITEM and _applied_search_query.is_empty():
		_open_rarity_bookmarks(animate)
		_refresh_rarity_bookmarks(_item_tier(gallery), animate)
	else:
		_close_rarity_bookmarks(animate)
	section_changed.emit(current_section)


## 战斗内浮层会复用同一个 CodexScreen；重新打开时仍需落实道具章节的默认入口。
func reset_for_open() -> void:
	if current_section != Section.ITEM:
		return
	var gallery := get_gallery(Section.ITEM)
	if _applied_search_query.is_empty():
		gallery.call("select_tier", 1)
		_refresh_rarity_bookmarks(1, false)
	else:
		_apply_search_to_gallery(gallery)


## 场景内呼出只做视觉偏移与淡入，不改变书本、页签或文字的真实布局坐标。
func play_overlay_open_animation() -> void:
	if _overlay_open_tween != null and _overlay_open_tween.is_valid():
		_overlay_open_tween.kill()
	if _overlay_close_tween != null and _overlay_close_tween.is_valid():
		_overlay_close_tween.kill()
	close_button.disabled = false
	if embedded_close.is_valid():
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.self_modulate.a = 0.0
	backdrop_motion.self_modulate.a = 0.0
	var lifted_layers: Array[Control] = [
		book_contact_shadow,
		bookmark_layer,
		gallery_host,
		native_text_layer,
		search_empty_state,
		search_control,
		close_button,
	]
	for layer: Control in lifted_layers:
		layer.offset_transform_enabled = true
		layer.offset_transform_visual_only = true
		layer.offset_transform_position = OVERLAY_OPEN_LIFT
		layer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_overlay_open_tween = create_tween().bind_node(self).set_parallel(true)
	_overlay_open_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_overlay_open_tween.tween_property(
		backdrop, "self_modulate:a", OVERLAY_BACKDROP_ALPHA, OVERLAY_OPEN_DURATION)
	_overlay_open_tween.tween_property(
		backdrop_motion, "self_modulate:a", 0.36, OVERLAY_OPEN_DURATION)
	for layer: Control in lifted_layers:
		_overlay_open_tween.tween_property(
			layer, "offset_transform_position", Vector2.ZERO, OVERLAY_OPEN_DURATION)
		_overlay_open_tween.tween_property(
			layer, "modulate", Color.WHITE, OVERLAY_OPEN_DURATION)


## 退场是入场的克制反向：书本轻微下沉并淡出，结束后由外层生命周期节点隐藏。
func play_overlay_close_animation() -> void:
	if _overlay_open_tween != null and _overlay_open_tween.is_valid():
		_overlay_open_tween.kill()
	if _overlay_close_tween != null and _overlay_close_tween.is_valid():
		_overlay_close_tween.kill()
	close_button.disabled = true
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var closing_layers: Array[Control] = [
		book_contact_shadow,
		bookmark_layer,
		gallery_host,
		native_text_layer,
		search_empty_state,
		search_control,
		close_button,
	]
	_overlay_close_tween = create_tween().bind_node(self).set_parallel(true)
	_overlay_close_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_overlay_close_tween.tween_property(
			backdrop, "self_modulate:a", 0.0, OVERLAY_CLOSE_DURATION)
	_overlay_close_tween.tween_property(
			backdrop_motion, "self_modulate:a", 0.0, OVERLAY_CLOSE_DURATION)
	for layer: Control in closing_layers:
		layer.offset_transform_enabled = true
		layer.offset_transform_visual_only = true
		_overlay_close_tween.tween_property(
				layer,
				"offset_transform_position",
				OVERLAY_CLOSE_DROP,
				OVERLAY_CLOSE_DURATION)
		_overlay_close_tween.tween_property(
				layer, "modulate", Color(1.0, 1.0, 1.0, 0.0), OVERLAY_CLOSE_DURATION)
	await _overlay_close_tween.finished


func get_gallery(section: int) -> Control:
	var safe_section := clampi(section, Section.HERO, Section.EFFECT)
	if _galleries[safe_section] != null:
		return _galleries[safe_section]
	# 两页作为 PackedScene 实例保存在 tscn 中，编辑器无需 F6 即可看到真实书本资产。
	# 保留运行时 fallback，避免旧存档或局部测试场景缺失预置子节点时崩溃。
	var gallery := gallery_host.get_node_or_null(GALLERY_NODE_PATHS[safe_section]) as Control
	if gallery == null:
		gallery = GALLERY_SCENES[safe_section].instantiate() as Control
		gallery.name = StringName(String(GALLERY_NODE_PATHS[safe_section]))
		gallery.set("embedded_in_codex", true)
		gallery_host.add_child(gallery)
	gallery.visible = false
	gallery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gallery.set_process_unhandled_input(false)
	gallery.set("embedded_in_codex", true)
	gallery.set("embedded_close", Callable(self, "_back_to_menu"))
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery.position = Vector2.ZERO
	gallery.scale = Vector2.ONE
	if safe_section == Section.ITEM and gallery.has_signal("tier_changed"):
		gallery.connect("tier_changed", Callable(self, "_on_item_tier_changed"))
	_galleries[safe_section] = gallery
	return gallery


func _apply_bookmark_fonts() -> void:
	for button: Button in [hero_bookmark, item_bookmark, effect_bookmark]:
		FontManager.apply_btn(button, 22)
		_prepare_bookmark_state_text(button, 22, CHAPTER_IDLE_TEXT_INSET)
	for button: Button in rarity_buttons:
		FontManager.apply_btn(button, 16)
		_prepare_bookmark_state_text(button, 16, RARITY_IDLE_TEXT_INSET)


func _prepare_bookmark_state_text(button: Button, font_size: int, idle_inset: float) -> void:
	var caption := button.text
	button.text = ""
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var state_text := Label.new()
	state_text.name = "StateText"
	state_text.text = caption
	state_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(state_text)
	state_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	state_text.offset_left = idle_inset
	state_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_text.add_theme_color_override("font_color", INK_SOFT)
	FontManager.apply(state_text, font_size)
	_bookmark_fold_scales[button] = 1.0
	_prepare_bookmark_assets(button)


func _prepare_bookmark_assets(button: Button) -> void:
	for node_name: String in [
		"IdleShadow", "SelectedShadow", "IdleArt", "SelectedArt",
	]:
		if not button.has_node(node_name):
			continue
		var layer := button.get_node(node_name) as TextureRect
		layer.material = null
		layer.self_modulate = Color.WHITE if node_name.ends_with("Art") \
				else BOOKMARK_SHADOW_COLOR
	for stripe_name: String in ["IdleStripe", "SelectedStripe"]:
		if not button.has_node(stripe_name):
			continue
		var stripe := button.get_node(stripe_name) as TextureRect
		assert(stripe.material is ShaderMaterial)
	_apply_bookmark_endpoint(button, false)
	_set_bookmark_fold_scale(1.0, button)


func _apply_rarity_stripe_colors() -> void:
	for index: int in rarity_buttons.size():
		var color: Color = RARITY_STRIPE_COLORS[index]
		for stripe_name: String in ["IdleStripe", "SelectedStripe"]:
			var stripe := rarity_buttons[index].get_node(stripe_name) as TextureRect
			var stripe_material := stripe.material as ShaderMaterial
			stripe_material.set_shader_parameter("rarity_color", color)


func _refresh_chapter_bookmarks(animate: bool = true) -> void:
	_set_bookmark_state(hero_bookmark, current_section == Section.HERO, animate)
	_set_bookmark_state(item_bookmark, current_section == Section.ITEM, animate)
	_set_bookmark_state(effect_bookmark, current_section == Section.EFFECT, animate)


func _refresh_rarity_bookmarks(tier: int, animate: bool = true) -> void:
	for index: int in rarity_buttons.size():
		_set_bookmark_state(rarity_buttons[index], index + 1 == tier, animate)


func _set_bookmark_state(button: Button, selected: bool, animate: bool) -> void:
	var had_state := _bookmark_selected_states.has(button)
	var previous_selected := bool(_bookmark_selected_states.get(button, selected))
	var state_changed := had_state and previous_selected != selected
	_bookmark_selected_states[button] = selected
	button.button_pressed = selected
	var chapter := button in [hero_bookmark, item_bookmark, effect_bookmark]
	var selected_x := CHAPTER_SELECTED_X if chapter else RARITY_SELECTED_X
	var idle_x := CHAPTER_IDLE_X if chapter else RARITY_IDLE_X
	var target_x := selected_x if selected else idle_x
	var hovered := bool(_hovered_tabs.get(button, false))
	var target_color := BOOKMARK_HOVER_MODULATE if hovered else Color.WHITE
	# 悬停或同档重复通知只能更新明暗，不能中断正在进行的纸签状态过渡。
	if had_state and not state_changed:
		_animate_bookmark_chrome(button, target_x, target_color, animate)
		return
	_animate_bookmark(
			button,
			target_x,
			target_color,
			selected,
			animate,
			state_changed)


func _apply_bookmark_visual_state(button: Button, selected: bool) -> void:
	_apply_bookmark_endpoint(button, selected)
	_set_bookmark_fold_scale(1.0, button)


func _apply_bookmark_endpoint(button: Button, selected: bool) -> void:
	var state_text := button.get_node("StateText") as Label
	state_text.add_theme_color_override("font_color", INK if selected else INK_SOFT)
	for node_name: String in [
		"IdleShadow", "SelectedShadow", "IdleArt", "SelectedArt",
	]:
		if not button.has_node(node_name):
			continue
		var layer := button.get_node(node_name) as TextureRect
		var selected_layer := node_name.begins_with("Selected")
		layer.visible = selected_layer == selected
		layer.material = null
	if button.has_node("IdleStripe") and button.has_node("SelectedStripe"):
		var idle_stripe := button.get_node("IdleStripe") as TextureRect
		var selected_stripe := button.get_node("SelectedStripe") as TextureRect
		idle_stripe.visible = not selected
		selected_stripe.visible = selected
		idle_stripe.self_modulate = Color.WHITE
		selected_stripe.self_modulate = Color.WHITE
		assert(idle_stripe.material is ShaderMaterial)
		assert(selected_stripe.material is ShaderMaterial)


func _bookmark_visual_nodes(button: Button) -> Array[Control]:
	var nodes: Array[Control] = [button.get_node("StateText") as Control]
	for node_name: String in [
		"IdleShadow", "SelectedShadow", "IdleArt", "SelectedArt",
		"IdleStripe", "SelectedStripe",
	]:
		if button.has_node(node_name):
			nodes.append(button.get_node(node_name) as Control)
	return nodes


## 纸签以书缝（按钮右缘）为轴收窄；只缩放视觉子节点，按钮点击矩形始终不变。
func _set_bookmark_fold_scale(amount: float, button: Button) -> void:
	var safe_amount := clampf(amount, bookmark_fold_min_scale, 1.0)
	_bookmark_fold_scales[button] = safe_amount
	for visual: Control in _bookmark_visual_nodes(button):
		visual.pivot_offset = Vector2(
			button.size.x - visual.position.x,
			button.size.y * 0.5 - visual.position.y)
		visual.scale = Vector2(safe_amount, 1.0)


func _animate_bookmark(
		button: Button,
		target_x: float,
		target_color: Color,
		selected: bool,
		animate: bool,
		state_changed: bool) -> void:
	_kill_button_tween(button)
	button.position.x = target_x
	button.modulate = target_color
	if not animate or not state_changed:
		_apply_bookmark_visual_state(button, selected)
		return
	var current_scale := float(_bookmark_fold_scales.get(button, 1.0))
	var collapse_distance := maxf(
		current_scale - bookmark_fold_min_scale, 0.0) \
		/ (1.0 - bookmark_fold_min_scale)
	var collapse_duration := maxf(
		bookmark_fold_collapse_duration * collapse_distance, 0.018)
	var tween := create_tween().bind_node(button)
	tween.tween_method(
			_set_bookmark_fold_scale.bind(button),
			current_scale,
			bookmark_fold_min_scale,
			collapse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_apply_bookmark_endpoint.bind(button, selected))
	tween.tween_method(
			_set_bookmark_fold_scale.bind(button),
			bookmark_fold_min_scale,
			1.0,
			bookmark_fold_expand_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tab_tweens[button] = tween


func _open_rarity_bookmarks(animate: bool) -> void:
	_kill_rarity_group_tween()
	rarity_bookmarks.visible = true
	for index: int in rarity_buttons.size():
		var button := rarity_buttons[index]
		button.position.y = RARITY_TARGET_Y[index]
		button.self_modulate.a = 1.0
		button.visible = not animate
		button.mouse_filter = Control.MOUSE_FILTER_STOP if not animate else Control.MOUSE_FILTER_IGNORE
	if not animate:
		return
	_rarity_group_tween = create_tween().bind_node(rarity_bookmarks)
	for index: int in rarity_buttons.size():
		_rarity_group_tween.tween_interval(0.025)
		_rarity_group_tween.tween_callback(
				_set_rarity_button_visible.bind(rarity_buttons[index], true))


func _close_rarity_bookmarks(animate: bool) -> void:
	_kill_rarity_group_tween()
	if not rarity_bookmarks.visible:
		return
	if not animate:
		rarity_bookmarks.visible = false
		return
	for button: Button in rarity_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rarity_group_tween = create_tween().bind_node(rarity_bookmarks)
	for reverse_index: int in rarity_buttons.size():
		var index := rarity_buttons.size() - 1 - reverse_index
		_rarity_group_tween.tween_interval(0.018)
		_rarity_group_tween.tween_callback(
				_set_rarity_button_visible.bind(rarity_buttons[index], false))
	_rarity_group_tween.tween_callback(_finish_rarity_close)


func _set_rarity_button_visible(button: Button, visible: bool) -> void:
	button.visible = visible
	button.mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE


func _finish_rarity_close() -> void:
	rarity_bookmarks.visible = false
	for button: Button in rarity_buttons:
		button.visible = true
		button.position.y = RARITY_TARGET_Y[rarity_buttons.find(button)]
		button.self_modulate.a = 1.0
		button.mouse_filter = Control.MOUSE_FILTER_STOP


## 道具展开二级稀有度签时，把下一枚主签顺势下排；离开道具后恢复紧凑主签间距。
## 只移动新增的效果签，不改已经通过的英雄、道具与稀有度坐标。
func _position_effect_bookmark(after_rarity: bool, _animate: bool) -> void:
	var target_y := EFFECT_BOOKMARK_ITEM_Y if after_rarity else EFFECT_BOOKMARK_REST_Y
	# 点击矩形与纸签画面必须始终一致；这里做离散插入，不给主签留下移动中的误触区域。
	effect_bookmark.position.y = target_y


func _on_bookmark_down(button: Button) -> void:
	_kill_press_tween(button)
	# visual-only 位移不改变点击矩形，也不会破坏侧签与书封的静态接缝。
	button.offset_transform_position = Vector2(PRESS_INSET, 0.0)


func _on_bookmark_up(button: Button) -> void:
	_kill_press_tween(button)
	var tween := create_tween().bind_node(button)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
			button, "offset_transform_position", Vector2.ZERO, PRESS_RELEASE_DURATION)
	_press_tweens[button] = tween


func _on_bookmark_hover(button: Button, hovered: bool) -> void:
	_hovered_tabs[button] = hovered
	var target_color := BOOKMARK_HOVER_MODULATE if hovered else Color.WHITE
	_animate_bookmark_chrome(button, button.position.x, target_color, true)


func _animate_bookmark_chrome(
		button: Button, target_x: float, target_color: Color, animate: bool) -> void:
	_kill_hover_tween(button)
	if not animate:
		button.position.x = target_x
		button.modulate = target_color
		return
	var tween := create_tween().bind_node(button).set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position:x", target_x, TAB_HOVER_DURATION)
	tween.tween_property(button, "modulate", target_color, TAB_HOVER_DURATION)
	_hover_tweens[button] = tween


func _setup_back_button() -> void:
	var back_art := back_button.get_node("BackArt") as TextureRect
	# 返回签也保持资产原色，不再套用纸色归一或状态 shader。
	back_art.material = null
	FontManager.apply(back_text, 18)
	back_text.add_theme_color_override("font_color", BACK_IDLE_COLOR)
	back_arrow.position = BACK_ARROW_REST_POSITION
	back_button.pressed.connect(_back_to_menu)
	back_button.mouse_entered.connect(_on_back_hover.bind(true))
	back_button.mouse_exited.connect(_on_back_hover.bind(false))
	back_button.button_down.connect(_on_back_down)
	back_button.button_up.connect(_on_back_up)


func _setup_close_button() -> void:
	close_button.flat = true
	for state: StringName in CLOSE_STYLE_STATES:
		close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	close_button.pressed.connect(_back_to_menu)
	close_button.mouse_entered.connect(_on_close_hover.bind(true))
	close_button.mouse_exited.connect(_on_close_hover.bind(false))
	close_button.button_down.connect(_on_close_down)
	close_button.button_up.connect(_on_close_up)
	_on_close_hover(false)


func _setup_search() -> void:
	search_button.pressed.connect(_focus_search)
	search_button.mouse_entered.connect(_on_search_icon_hover.bind(true))
	search_button.mouse_exited.connect(_on_search_icon_hover.bind(false))
	search_button.button_down.connect(_on_search_icon_down)
	search_button.button_up.connect(_on_search_icon_up)
	search_input.text_submitted.connect(_on_search_text_submitted)
	search_input.text_changed.connect(_on_search_text_changed)
	search_input.focus_entered.connect(_on_search_focus_changed.bind(true))
	search_input.focus_exited.connect(_on_search_focus_changed.bind(false))
	search_input.gui_input.connect(_on_search_input_gui)
	search_clear_button.pressed.connect(_clear_applied_search)
	search_clear_button.mouse_entered.connect(_on_search_clear_hover.bind(true))
	search_clear_button.mouse_exited.connect(_on_search_clear_hover.bind(false))
	search_clear_button.button_down.connect(_on_search_clear_down)
	search_clear_button.button_up.connect(_on_search_clear_up)
	search_input.caret_blink = true
	search_input.caret_blink_interval = 0.55
	search_curved_text.caret_blink_interval = search_input.caret_blink_interval
	search_input.keep_editing_on_text_submit = true
	search_clear_button.visible = false
	_on_search_icon_hover(false)
	_on_search_clear_hover(false)
	_refresh_search_scope()


func _focus_search() -> void:
	search_input.grab_focus()
	search_input.caret_column = search_input.text.length()


func _refresh_search_scope() -> void:
	search_input.placeholder_text = tr(SEARCH_PLACEHOLDER)
	search_curved_text.queue_redraw()


func _on_search_text_submitted(text: String) -> void:
	_applied_search_query = text.strip_edges()
	_showing_search_cat_egg = not _applied_search_query.is_empty() \
			and randf() < search_cat_easter_egg_chance
	search_input.text = _applied_search_query
	search_input.caret_column = search_input.text.length()
	search_clear_button.visible = not _applied_search_query.is_empty()
	for gallery: Control in _galleries:
		if gallery != null:
			_apply_search_to_gallery(gallery)
	if current_section >= 0:
		var current_gallery := get_gallery(current_section)
		native_text_layer.set_source_root(current_gallery)
		_refresh_search_empty_state()
		if current_section == Section.ITEM:
			if _applied_search_query.is_empty():
				_open_rarity_bookmarks(false)
				_refresh_rarity_bookmarks(_item_tier(current_gallery), false)
			else:
				_close_rarity_bookmarks(false)
	search_input.grab_focus()


func _on_search_text_changed(text: String) -> void:
	search_clear_button.visible = not text.is_empty()
	# 已提交的搜索被手动删空时同步恢复书页，避免“框已空但过滤仍存在”。
	if text.is_empty() and not _applied_search_query.is_empty():
		_clear_applied_search()


func _apply_search_to_gallery(gallery: Control) -> void:
	if gallery.has_method("set_search_query"):
		gallery.call("set_search_query", _applied_search_query)


func _clear_applied_search() -> void:
	_applied_search_query = ""
	_showing_search_cat_egg = false
	if not search_input.text.is_empty():
		search_input.clear()
	search_clear_button.visible = false
	for gallery: Control in _galleries:
		if gallery != null:
			_apply_search_to_gallery(gallery)
	if current_section >= 0:
		var current_gallery := get_gallery(current_section)
		native_text_layer.set_source_root(current_gallery)
		_refresh_search_empty_state()
		if current_section == Section.ITEM:
			_open_rarity_bookmarks(false)
			_refresh_rarity_bookmarks(_item_tier(current_gallery), false)
	search_input.grab_focus()
	search_input.caret_column = 0


func _refresh_search_empty_state() -> void:
	if current_section < 0 or _applied_search_query.is_empty():
		search_empty_state.visible = false
		return
	var gallery := get_gallery(current_section)
	var result_count := 0
	if gallery.has_method("search_result_count"):
		result_count = int(gallery.call("search_result_count"))
	var has_no_results := result_count <= 0
	search_empty_state.visible = has_no_results
	if not has_no_results:
		return
	search_empty_left.text = "没搜到..." if _showing_search_cat_egg \
			else "没有找到对应的结果..."
	search_empty_right.text = ""
	search_empty_right.visible = false
	search_empty_cat_group.visible = _showing_search_cat_egg


func _on_search_focus_changed(focused: bool) -> void:
	search_frame.set_focused(focused)


func _on_search_input_gui(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		return
	search_input.release_focus()
	search_input.accept_event()


func _set_search_icon_color(color: Color) -> void:
	(search_button.get_node("Lens") as Line2D).default_color = color
	(search_button.get_node("Handle") as Line2D).default_color = color


func _on_search_icon_hover(hovered: bool) -> void:
	_set_search_icon_color(CLOSE_HOVER_COLOR if hovered else CLOSE_IDLE_COLOR)


func _on_search_icon_down() -> void:
	_set_search_icon_color(CLOSE_PRESSED_COLOR)


func _on_search_icon_up() -> void:
	_on_search_icon_hover(search_button.is_hovered())


func _set_search_clear_color(color: Color) -> void:
	(search_clear_button.get_node("StrokeA") as Line2D).default_color = color
	(search_clear_button.get_node("StrokeB") as Line2D).default_color = color


func _on_search_clear_hover(hovered: bool) -> void:
	_set_search_clear_color(CLOSE_HOVER_COLOR if hovered else CLOSE_IDLE_COLOR)


func _on_search_clear_down() -> void:
	_set_search_clear_color(CLOSE_PRESSED_COLOR)


func _on_search_clear_up() -> void:
	_on_search_clear_hover(search_clear_button.is_hovered())


func _on_close_hover(hovered: bool) -> void:
	var stroke_color := CLOSE_HOVER_COLOR if hovered else CLOSE_IDLE_COLOR
	(close_button.get_node("StrokeA") as Line2D).default_color = stroke_color
	(close_button.get_node("StrokeB") as Line2D).default_color = stroke_color


func _on_close_down() -> void:
	(close_button.get_node("StrokeA") as Line2D).default_color = CLOSE_PRESSED_COLOR
	(close_button.get_node("StrokeB") as Line2D).default_color = CLOSE_PRESSED_COLOR


func _on_close_up() -> void:
	_on_close_hover(close_button.is_hovered())


func _configure_embedded_overlay() -> void:
	if not embedded_close.is_valid():
		return
	backdrop.self_modulate = Color(1.0, 1.0, 1.0, OVERLAY_BACKDROP_ALPHA)
	backdrop_motion.self_modulate = Color(1.0, 1.0, 1.0, 0.36)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if not backdrop.gui_input.is_connected(_on_overlay_backdrop_input):
		backdrop.gui_input.connect(_on_overlay_backdrop_input)
	back_button.visible = false
	back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_overlay_backdrop_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var book_rect := Rect2(BOOK_ORIGIN, DESIGN_SIZE * BOOK_SCALE)
	if book_rect.has_point(mouse_event.position):
		return
	embedded_close.call()
	accept_event()


func _on_back_hover(hovered: bool) -> void:
	back_arrow.color = BACK_HOVER_COLOR if hovered else BACK_IDLE_COLOR
	back_arrow.position = BACK_ARROW_REST_POSITION \
			+ (BACK_ARROW_HOVER_SHIFT if hovered else Vector2.ZERO)
	back_text.add_theme_color_override(
			"font_color", BACK_HOVER_COLOR if hovered else BACK_IDLE_COLOR)
	_animate_back_modulate(BOOKMARK_HOVER_MODULATE if hovered else Color.WHITE)


func _on_back_down() -> void:
	back_arrow.position = BACK_ARROW_REST_POSITION + BACK_ARROW_PRESS_SHIFT


func _on_back_up() -> void:
	back_arrow.position = BACK_ARROW_REST_POSITION \
			+ (BACK_ARROW_HOVER_SHIFT if back_button.is_hovered() else Vector2.ZERO)


func _animate_back_modulate(target: Color) -> void:
	_kill_hover_tween(back_button)
	var tween := create_tween().bind_node(back_button)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(back_button, "modulate", target, TAB_HOVER_DURATION)
	_hover_tweens[back_button] = tween


func _is_bookmark_selected(button: Button) -> bool:
	if button == hero_bookmark:
		return current_section == Section.HERO
	if button == item_bookmark:
		return current_section == Section.ITEM
	if button == effect_bookmark:
		return current_section == Section.EFFECT
	var rarity_index := rarity_buttons.find(button)
	if rarity_index < 0 or current_section != Section.ITEM:
		return false
	return rarity_index + 1 == _item_tier(get_gallery(Section.ITEM))


func _all_bookmarks() -> Array[Button]:
	var buttons: Array[Button] = [hero_bookmark, item_bookmark, effect_bookmark]
	buttons.append_array(rarity_buttons)
	return buttons


func _kill_button_tween(button: Button) -> void:
	var tween := _tab_tweens.get(button) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_tab_tweens.erase(button)


func _kill_hover_tween(button: Button) -> void:
	var tween := _hover_tweens.get(button) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_hover_tweens.erase(button)


func _kill_press_tween(button: Button) -> void:
	var tween := _press_tweens.get(button) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_press_tweens.erase(button)


func _kill_rarity_group_tween() -> void:
	if _rarity_group_tween != null and _rarity_group_tween.is_valid():
		_rarity_group_tween.kill()
	_rarity_group_tween = null


func _on_rarity_pressed(tier: int) -> void:
	if current_section != Section.ITEM:
		show_section(Section.ITEM)
	var item_gallery := get_gallery(Section.ITEM)
	item_gallery.call("select_tier", tier)


func _on_item_tier_changed(tier: int) -> void:
	if current_section == Section.ITEM:
		_refresh_rarity_bookmarks(tier, true)


func _item_tier(gallery: Control) -> int:
	if gallery.has_method("get_current_tier"):
		return int(gallery.call("get_current_tier"))
	return int(gallery.get("_tier"))


func _back_to_menu() -> void:
	if embedded_close.is_valid():
		embedded_close.call()
		return
	TransitionManager.transition_to(MAIN_MENU_SCENE)

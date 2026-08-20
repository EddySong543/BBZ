extends Control
class_name CodexScreen

## 英雄与道具共享同一本图鉴；此节点负责烟褐衬底、统一缩书构图与左缘夹页索引。
## 两套成熟书页仍在各自的 1920x1080 设计坐标中运行，不重排内部节点。

signal section_changed(section: int)

enum Section { HERO, ITEM }

const MAIN_MENU_SCENE := "res://src/ui/main_menu.tscn"
const GALLERY_SCENES: Array[PackedScene] = [
	preload("res://src/ui/hero_gallery_screen.tscn"),
	preload("res://src/ui/item_gallery_screen.tscn"),
]
const BOOK_ORIGIN := Vector2(230.0, 130.0)
const BOOK_SCALE := Vector2(0.76, 0.76)
const INK := Color("34281D")
const INK_SOFT := Color("675746")
const CHAPTER_SELECTED_X := 96.0
const CHAPTER_IDLE_X := 96.0
const RARITY_SELECTED_X := 0.0
const RARITY_IDLE_X := 0.0
const HOVER_PULL := 4.0
const PRESS_INSET := 3.0
const TAB_TWEEN_DURATION := 0.16
const RARITY_TARGET_Y: Array[float] = [0.0, 52.0, 104.0]
const RARITY_COLLAPSED_Y: Array[float] = [-22.0, -16.0, -10.0]

@export_enum("英雄", "道具") var initial_section: int = Section.HERO

@onready var gallery_host: Control = $GalleryHost
@onready var bookmark_layer: Control = $BookmarkLayer
@onready var hero_bookmark: Button = $BookmarkLayer/HeroBookmark
@onready var item_bookmark: Button = $BookmarkLayer/ItemBookmark
@onready var rarity_bookmarks: Control = $BookmarkLayer/RarityBookmarks
@onready var rarity_buttons: Array[Button] = [
	$BookmarkLayer/RarityBookmarks/Normal,
	$BookmarkLayer/RarityBookmarks/Rare,
	$BookmarkLayer/RarityBookmarks/Legendary,
]

var embedded_close: Callable = Callable()
var current_section: int = -1
var _galleries: Array[Control] = [null, null]
var _tab_tweens: Dictionary = {}
var _hovered_tabs: Dictionary = {}
var _rarity_group_tween: Tween


func _ready() -> void:
	# 二级签从道具主签背后展开，主签始终压在它们上方。
	item_bookmark.move_to_front()
	hero_bookmark.pressed.connect(show_section.bind(Section.HERO))
	item_bookmark.pressed.connect(show_section.bind(Section.ITEM))
	for index: int in rarity_buttons.size():
		rarity_buttons[index].pressed.connect(_on_rarity_pressed.bind(index + 1))
	for button: Button in _all_bookmarks():
		button.button_down.connect(_on_bookmark_down.bind(button))
		button.button_up.connect(_on_bookmark_up.bind(button))
		button.mouse_entered.connect(_on_bookmark_hover.bind(button, true))
		button.mouse_exited.connect(_on_bookmark_hover.bind(button, false))
	_apply_bookmark_fonts()
	show_section(clampi(initial_section, Section.HERO, Section.ITEM))


func show_section(section: int) -> void:
	var safe_section := clampi(section, Section.HERO, Section.ITEM)
	var previous_section := current_section
	var gallery := get_gallery(safe_section)
	for index: int in _galleries.size():
		var cached := _galleries[index]
		if cached == null:
			continue
		var is_active := index == safe_section
		cached.visible = is_active
		cached.set_process_unhandled_input(is_active)
	current_section = safe_section
	var animate := previous_section >= 0 and previous_section != current_section
	_refresh_chapter_bookmarks(animate)
	if current_section == Section.ITEM:
		_open_rarity_bookmarks(animate)
		_refresh_rarity_bookmarks(_item_tier(gallery), animate)
	else:
		_close_rarity_bookmarks(animate)
	section_changed.emit(current_section)


func get_gallery(section: int) -> Control:
	var safe_section := clampi(section, Section.HERO, Section.ITEM)
	if _galleries[safe_section] != null:
		return _galleries[safe_section]
	var gallery := GALLERY_SCENES[safe_section].instantiate() as Control
	gallery_host.add_child(gallery)
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery.position = Vector2.ZERO
	gallery.scale = Vector2.ONE
	gallery.set("embedded_close", Callable(self, "_back_to_menu"))
	if safe_section == Section.ITEM and gallery.has_signal("tier_changed"):
		gallery.connect("tier_changed", Callable(self, "_on_item_tier_changed"))
	_galleries[safe_section] = gallery
	return gallery


func _apply_bookmark_fonts() -> void:
	for button: Button in [hero_bookmark, item_bookmark]:
		FontManager.apply_btn(button, 22)
		_apply_bookmark_text_colors(button)
	for button: Button in rarity_buttons:
		FontManager.apply_btn(button, 17)
		_apply_bookmark_text_colors(button)


func _apply_bookmark_text_colors(button: Button) -> void:
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)


func _refresh_chapter_bookmarks(animate: bool = true) -> void:
	_set_bookmark_state(hero_bookmark, current_section == Section.HERO, animate)
	_set_bookmark_state(item_bookmark, current_section == Section.ITEM, animate)


func _refresh_rarity_bookmarks(tier: int, animate: bool = true) -> void:
	for index: int in rarity_buttons.size():
		_set_bookmark_state(rarity_buttons[index], index + 1 == tier, animate)


func _set_bookmark_state(button: Button, selected: bool, animate: bool) -> void:
	button.button_pressed = selected
	_set_bookmark_art(button, selected)
	var chapter := button == hero_bookmark or button == item_bookmark
	var selected_x := CHAPTER_SELECTED_X if chapter else RARITY_SELECTED_X
	var idle_x := CHAPTER_IDLE_X if chapter else RARITY_IDLE_X
	var target_x := selected_x if selected else idle_x
	if not selected and bool(_hovered_tabs.get(button, false)):
		target_x -= HOVER_PULL
	button.add_theme_color_override("font_color", INK if selected else INK_SOFT)
	_animate_bookmark(button, target_x, Color.WHITE, animate)


func _set_bookmark_art(button: Button, selected: bool) -> void:
	var idle_art := button.get_node_or_null("IdleArt") as CanvasItem
	var selected_art := button.get_node_or_null("SelectedArt") as CanvasItem
	if idle_art != null:
		idle_art.visible = not selected
	if selected_art != null:
		selected_art.visible = selected
	var idle_stripe := button.get_node_or_null("IdleStripe") as CanvasItem
	var selected_stripe := button.get_node_or_null("SelectedStripe") as CanvasItem
	if idle_stripe != null:
		idle_stripe.visible = not selected
	if selected_stripe != null:
		selected_stripe.visible = selected


func _animate_bookmark(button: Button, target_x: float, target_color: Color, animate: bool) -> void:
	_kill_button_tween(button)
	if not animate:
		button.position.x = target_x
		button.modulate = target_color
		return
	var tween := create_tween().bind_node(button).set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position:x", target_x, TAB_TWEEN_DURATION)
	tween.tween_property(button, "modulate", target_color, TAB_TWEEN_DURATION)
	_tab_tweens[button] = tween


func _open_rarity_bookmarks(animate: bool) -> void:
	_kill_rarity_group_tween()
	rarity_bookmarks.visible = true
	for button: Button in rarity_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not animate:
		for index: int in rarity_buttons.size():
			rarity_buttons[index].position.y = RARITY_TARGET_Y[index]
			rarity_buttons[index].self_modulate.a = 1.0
		return
	for index: int in rarity_buttons.size():
		rarity_buttons[index].position.y = RARITY_COLLAPSED_Y[index]
		rarity_buttons[index].self_modulate.a = 0.0
	_rarity_group_tween = create_tween().bind_node(rarity_bookmarks).set_parallel(true)
	_rarity_group_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for index: int in rarity_buttons.size():
		var delay := index * 0.025
		_rarity_group_tween.tween_property(
				rarity_buttons[index], "position:y", RARITY_TARGET_Y[index], 0.16).set_delay(delay)
		_rarity_group_tween.tween_property(
				rarity_buttons[index], "self_modulate:a", 1.0, 0.11).set_delay(delay)


func _close_rarity_bookmarks(animate: bool) -> void:
	_kill_rarity_group_tween()
	if not rarity_bookmarks.visible:
		return
	if not animate:
		rarity_bookmarks.visible = false
		return
	for button: Button in rarity_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rarity_group_tween = create_tween().bind_node(rarity_bookmarks).set_parallel(true)
	_rarity_group_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for reverse_index: int in rarity_buttons.size():
		var index := rarity_buttons.size() - 1 - reverse_index
		var delay := reverse_index * 0.018
		_rarity_group_tween.tween_property(
				rarity_buttons[index], "position:y", RARITY_COLLAPSED_Y[index], 0.12).set_delay(delay)
		_rarity_group_tween.tween_property(
				rarity_buttons[index], "self_modulate:a", 0.0, 0.09).set_delay(delay)
	_rarity_group_tween.chain().tween_callback(_finish_rarity_close)


func _finish_rarity_close() -> void:
	rarity_bookmarks.visible = false
	for button: Button in rarity_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_bookmark_down(button: Button) -> void:
	_kill_button_tween(button)
	# 三像素压入必须在按下帧即可读到；松开仍用短 cubic tween 回弹。
	button.position.x += PRESS_INSET


func _on_bookmark_up(button: Button) -> void:
	call_deferred("_restore_bookmark_after_press", button)


func _restore_bookmark_after_press(button: Button) -> void:
	if not is_instance_valid(button):
		return
	_set_bookmark_state(button, _is_bookmark_selected(button), true)


func _on_bookmark_hover(button: Button, hovered: bool) -> void:
	_hovered_tabs[button] = hovered
	_set_bookmark_state(button, _is_bookmark_selected(button), true)


func _is_bookmark_selected(button: Button) -> bool:
	if button == hero_bookmark:
		return current_section == Section.HERO
	if button == item_bookmark:
		return current_section == Section.ITEM
	var rarity_index := rarity_buttons.find(button)
	if rarity_index < 0 or current_section != Section.ITEM:
		return false
	return rarity_index + 1 == _item_tier(get_gallery(Section.ITEM))


func _all_bookmarks() -> Array[Button]:
	var buttons: Array[Button] = [hero_bookmark, item_bookmark]
	buttons.append_array(rarity_buttons)
	return buttons


func _kill_button_tween(button: Button) -> void:
	var tween := _tab_tweens.get(button) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_tab_tweens.erase(button)


func _kill_rarity_group_tween() -> void:
	if _rarity_group_tween != null and _rarity_group_tween.is_valid():
		_rarity_group_tween.kill()
	_rarity_group_tween = null


func _on_rarity_pressed(tier: int) -> void:
	if current_section != Section.ITEM:
		show_section(Section.ITEM)
	var item_gallery := get_gallery(Section.ITEM)
	item_gallery.call("select_tier", tier)
	_refresh_rarity_bookmarks(tier, true)


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

extends Control
class_name EffectGalleryScreen

## 通用效果图鉴：左页为效果索引，右页显示同源图标与完整解释。
## 语义色仍保留在 EffectCatalog 供战斗系统复用；图鉴正文统一使用纸页深墨色。

const EffectCatalogScript := preload("res://src/battle/effect_catalog.gd")
const EffectTextFormatterScript := preload("res://src/ui/effect_text_formatter.gd")
const SELECTION_MARKER_SCRIPT := preload("res://src/ui/components/hero_gallery_selection_marker.gd")
const INK := Color("2E2922")
const SELECTED_INK := Color("9A6828")
const ICON_ALPHA_THRESHOLD := 0.06
const POINTER_COLOR := Color("7B5E3E")
const POINTER_SIZE := Vector2(20.0, 36.0)
const DETAIL_TWEEN_DURATION := 0.14
const FRAME_SHADOW := Color("49372B")
const FRAME_MID := Color("8B765D")
const FRAME_HIGHLIGHT := Color("D7BD91")
const FRAME_SELECTED_SHADOW := Color("704A1E")
const FRAME_SELECTED_MID := Color("C99032")
const FRAME_SELECTED_HIGHLIGHT := Color("F2D28B")
const DISPLAY_ORDER: Array[StringName] = [
	&"bonus_effect",
	&"armor",
	&"pierce_defense",
	&"pierce_guard",
	&"true_damage",
	&"h02_wave_upgrade",
	&"h08_retained_big_defend",
	&"poison",
	&"vulnerable",
	&"sword_qi",
]

@export var embedded_in_codex: bool = false
var embedded_close: Callable = Callable()
var _selected_id: StringName = &"bonus_effect"
var _buttons: Array[Button] = []
var _entries: Array[Dictionary] = []
var _button_home_positions: Array[Vector2] = []
var _filtered_entry_indices: Array[int] = []
var _search_query := ""
var _normalized_icons: Dictionary = {}
var _selection_tweens: Array[Tween] = []
var _detail_tween: Tween

@onready var _book_layer: Control = $BookLayer
@onready var effect_list: Control = $EffectList
@onready var detail_area: Control = $DetailArea
@onready var detail_name: Label = $DetailArea/EffectName
@onready var detail_icon: TextureRect = $DetailArea/EffectIcon
@onready var detail_description: Label = $DetailArea/Description
@onready var detail_navigation: Control = $DetailArea/DetailNavigation
@onready var previous_detail_button: Button = $DetailArea/DetailNavigation/PreviousItem
@onready var detail_indicator: Label = $DetailArea/DetailNavigation/ItemIndicator
@onready var next_detail_button: Button = $DetailArea/DetailNavigation/NextItem
@onready var back_button: Button = $TopBand/BackButton


func _ready() -> void:
	_book_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.assign(effect_list.get_children())
	for button: Button in _buttons:
		_button_home_positions.append(button.position)
	_entries.clear()
	for effect_id: StringName in DISPLAY_ORDER:
		_entries.append(EffectCatalogScript.get_by_id(effect_id))
	for index: int in _entries.size():
		_filtered_entry_indices.append(index)
	assert(_buttons.size() == _entries.size())
	for index: int in _buttons.size():
		var button := _buttons[index]
		var entry: Dictionary = _entries[index]
		button.text = ""
		button.set_meta(&"effect_id", entry.id)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_clear_button_chrome(button)
		var name_label := button.get_node("NameLabel") as Label
		name_label.text = entry.name
		FontManager.apply(name_label, 17)
		name_label.add_theme_color_override("font_color", INK)
		var icon := button.get_node("EffectFrame/Icon") as TextureRect
		icon.texture = _load_effect_icon(entry)
		icon.visible = icon.texture != null
		button.add_child(_make_selection_pointer(104.0))
		var juice := ButtonJuice.new()
		juice.name = "ButtonJuice"
		button.add_child(juice)
		button.pressed.connect(select_effect.bind(entry.id))
	FontManager.apply(detail_name, 32)
	FontManager.apply(detail_description, 24)
	detail_icon.set_meta(&"home_position", detail_icon.position)
	_setup_detail_navigation()
	_setup_back_button()
	select_effect(_selected_id)


func select_effect(effect_id: StringName) -> void:
	var entry := EffectCatalogScript.get_by_id(effect_id)
	if entry.is_empty():
		return
	_selected_id = effect_id
	for tween: Tween in _selection_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_selection_tweens.clear()
	for button: Button in _buttons:
		var selected: bool = button.get_meta(&"effect_id") == effect_id
		(button.get_node("SelectionPointer") as Control).visible = false
		button.button_pressed = selected
		_set_effect_frame_selected(button, selected)
		(button.get_node("NameLabel") as Label).add_theme_color_override(
				"font_color", SELECTED_INK if selected else INK)
		if selected:
			_play_select_fx(button)
	_refresh_detail(entry)
	_play_detail_switch_fx()
	_refresh_detail_navigation()


func _set_effect_frame_selected(button: Button, selected: bool) -> void:
	var frame_art := button.get_node("EffectFrame/GalleryItemFrame") as TextureRect
	var material := frame_art.material as ShaderMaterial
	material.set_shader_parameter(
			"shadow_color", FRAME_SELECTED_SHADOW if selected else FRAME_SHADOW)
	material.set_shader_parameter(
			"mid_color", FRAME_SELECTED_MID if selected else FRAME_MID)
	material.set_shader_parameter(
			"highlight_color", FRAME_SELECTED_HIGHLIGHT if selected else FRAME_HIGHLIGHT)


func _make_selection_pointer(row_height: float) -> Control:
	var pointer := SELECTION_MARKER_SCRIPT.new() as Control
	pointer.name = "SelectionPointer"
	pointer.position = Vector2(-28.0, floorf((row_height - POINTER_SIZE.y) * 0.5))
	pointer.size = POINTER_SIZE
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.visible = false
	pointer.set("color", POINTER_COLOR)
	pointer.set_meta(&"home_position", pointer.position)
	return pointer


## 与英雄图鉴共用：真实框转金，书页棕像素指针轻推入后完全静止。
func _play_select_fx(button: Button) -> void:
	var pointer := button.get_node("SelectionPointer") as Control
	var pointer_home: Vector2 = pointer.get_meta(&"home_position")
	pointer.visible = true
	pointer.position = pointer_home - Vector2(6.0, 0.0)
	pointer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(pointer, "position", pointer_home, 0.16)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(pointer, "modulate:a", 1.0, 0.12)
	_selection_tweens.append(pop)


func _play_detail_switch_fx() -> void:
	if _detail_tween != null and _detail_tween.is_valid():
		_detail_tween.kill()
	var home: Vector2 = detail_icon.get_meta(&"home_position")
	detail_icon.pivot_offset = detail_icon.size * 0.5
	detail_icon.position = home + Vector2(0.0, 4.0)
	detail_icon.scale = Vector2.ONE * 1.06
	detail_icon.modulate.a = 0.72
	_detail_tween = create_tween()
	_detail_tween.set_parallel(true)
	_detail_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_detail_tween.tween_property(detail_icon, "position", home, DETAIL_TWEEN_DURATION)
	_detail_tween.tween_property(detail_icon, "scale", Vector2.ONE, DETAIL_TWEEN_DURATION)
	_detail_tween.tween_property(detail_icon, "modulate:a", 1.0, DETAIL_TWEEN_DURATION)


func _setup_detail_navigation() -> void:
	previous_detail_button.pressed.connect(_turn_detail.bind(-1))
	next_detail_button.pressed.connect(_turn_detail.bind(1))
	for button: Button in [previous_detail_button, next_detail_button]:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		FontManager.apply_btn(button, 24)
		var juice := ButtonJuice.new()
		juice.name = "ButtonJuice"
		button.add_child(juice)
	FontManager.apply(detail_indicator, 22)
	_refresh_detail_navigation()


func _turn_detail(step: int) -> void:
	if _filtered_entry_indices.is_empty():
		return
	var current_catalog_index := _entry_index(_selected_id)
	var current := maxi(_filtered_entry_indices.find(current_catalog_index), 0)
	var target := clampi(current + step, 0, _filtered_entry_indices.size() - 1)
	if target == current:
		return
	select_effect(_entries[_filtered_entry_indices[target]].id)


func _refresh_detail_navigation() -> void:
	var total := _filtered_entry_indices.size()
	detail_navigation.visible = total > 0
	var current := clampi(
			_filtered_entry_indices.find(_entry_index(_selected_id)), 0, maxi(total - 1, 0))
	detail_indicator.text = "%02d / %02d" % [current + 1, total] if total > 0 else "00 / 00"
	previous_detail_button.disabled = total == 0 or current <= 0
	next_detail_button.disabled = total == 0 or current >= total - 1


func _entry_index(effect_id: StringName) -> int:
	for index: int in _entries.size():
		if _entries[index].id == effect_id:
			return index
	return -1


func get_search_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		entries.append({
			"id": entry.id,
			"label": String(entry.name),
			"search_text": String(entry.name),
		})
	return entries


func set_search_query(query: String) -> void:
	var normalized := query.strip_edges().to_lower()
	if normalized == _search_query and not _filtered_entry_indices.is_empty():
		return
	_search_query = normalized
	_filtered_entry_indices.clear()
	for index: int in _entries.size():
		var entry := _entries[index]
		var searchable := String(entry.name)
		if normalized.is_empty() or searchable.to_lower().contains(normalized):
			_filtered_entry_indices.append(index)
	for button: Button in _buttons:
		button.visible = false
	for slot_index: int in _filtered_entry_indices.size():
		var catalog_index := _filtered_entry_indices[slot_index]
		var button := _buttons[catalog_index]
		button.position = _button_home_positions[slot_index]
		button.visible = true
	detail_area.visible = not _filtered_entry_indices.is_empty()
	if not _filtered_entry_indices.is_empty():
		select_effect(_entries[_filtered_entry_indices[0]].id)
	else:
		_refresh_detail_navigation()


func search_result_count() -> int:
	return _filtered_entry_indices.size()


func select_search_result(entry_id: StringName) -> void:
	select_effect(entry_id)


func _refresh_detail(entry: Dictionary) -> void:
	detail_name.text = entry.name
	detail_name.add_theme_color_override("font_color", INK)
	detail_icon.texture = _load_effect_icon(entry)
	detail_icon.visible = detail_icon.texture != null
	detail_description.text = EffectTextFormatterScript.protect_cjk_line_breaks(
			String(entry.description))


func _load_effect_icon(entry: Dictionary) -> Texture2D:
	var icon_path := String(entry.get("icon_path", ""))
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	if _normalized_icons.has(icon_path):
		return _normalized_icons[icon_path] as Texture2D
	var source := load(icon_path) as Texture2D
	var normalized := _crop_to_visible_content(source)
	_normalized_icons[icon_path] = normalized
	return normalized


func _crop_to_visible_content(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	var bounds := _visible_bounds(image)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(Vector2(bounds.position), Vector2(bounds.size))
	return atlas


func _visible_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < ICON_ALPHA_THRESHOLD:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _clear_button_chrome(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _setup_back_button() -> void:
	if embedded_in_codex:
		back_button.visible = false
		back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	FontManager.apply_btn(back_button, 24)
	back_button.pressed.connect(_back_to_menu)


func _back_to_menu() -> void:
	if embedded_close.is_valid():
		embedded_close.call()
		return
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")

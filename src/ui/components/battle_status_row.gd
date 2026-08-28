@tool
class_name BattleStatusRow
extends Control

## 出战英雄玩家名后的常驻效果队列。
## 排版宽度包含数字以避免相邻项遮挡，但战斗定位只使用图标联合边界，数字不参与锚定。

const COUNT_BASE_FONT: Font = preload("res://assets/font/zlabs_pixel_ui.tres")

@export_group("Buff Icon")
@export var icon_box_size := Vector2(34.0, 34.0)
@export_range(0.0, 32.0, 1.0) var slot_gap := 0.0
@export_range(0.0, 0.5, 0.01) var icon_alpha_threshold := 0.06

@export_group("Icon Shadow")
@export var icon_shadow_enabled := true
@export var icon_shadow_color := Color(0.0, 0.0, 0.0, 0.32)
@export var icon_shadow_offset := Vector2(2.0, 2.0)

@export_group("Per Icon Optical Scale")
## 剑气是纵向窄构图；等比放大可补偿可见面积，不改变其方向语义。
@export var use_per_icon_visual_scales := true
@export_range(0.5, 2.0, 0.01) var poison_icon_scale := 1.0
@export_range(0.5, 2.0, 0.01) var vulnerable_icon_scale := 1.0
@export_range(0.5, 2.0, 0.01) var sword_qi_icon_scale := 1.2

@export_group("Buff Enter Motion")
@export var enter_motion_enabled := true
@export_range(0.05, 0.4, 0.01, "suffix:s") var enter_duration := 0.16
@export_range(0.0, 12.0, 1.0, "suffix:px") var enter_lift := 3.0
@export_range(0.5, 1.0, 0.01) var enter_scale := 0.9

@export_group("Stack Number")
## 相对图标右边缘的位置；x 为横向间隔，y 为距图标顶边的位置。
@export var count_offset := Vector2(-4.0, 18.0)
@export var count_box_size := Vector2(26.0, 18.0)
@export_range(8, 32, 1) var count_font_size := 12
@export_range(0.0, 1.5, 0.05) var count_embolden := 0.6
## 小写 x 与数值之间的像素间距；Inspector 滑杆可实时调整。
@export_range(0.0, 12.0, 1.0, "suffix:px") var count_symbol_gap := 2.0
@export_range(0, 8, 1) var count_outline_size := 2
@export var count_text_color := Color("F2E8CC")
@export var count_outline_color := Color.BLACK
@export var count_shadow_color := Color(0.0, 0.0, 0.0, 0.32)
@export var count_shadow_offset := Vector2i(1, 1)
@export_range(0, 4, 1) var count_shadow_outline_size := 0
@export_range(0.0, 1.0, 0.01) var count_pop_duration := 0.14

@export_group("Per Icon Count Offset")
## 开启后毒素、脆弱与剑气直接使用各自坐标；适合在临时场景中做光学对齐。
@export var use_per_icon_count_offsets := true
@export var poison_count_offset := Vector2(0.0, 20.0)
@export var vulnerable_count_offset := Vector2(-2.0, 20.0)
@export var sword_qi_count_offset := Vector2(-6.0, 20.0)

@export_group("Editor Preview")
## 正式战斗运行时保持关闭；调试场景实例会打开并展示真实毒素/脆弱/剑气组件。
@export var preview_enabled := false
@export_range(1, 99, 1) var preview_poison_count := 3
@export_range(1, 99, 1) var preview_vulnerable_count := 2
@export_range(1, 99, 1) var preview_sword_qi_count := 4

var _signature := ""
var _effect_ids: Array[StringName] = []
var _slot_rects: Array[Rect2] = []
var _icons: Array[TextureRect] = []
var _values: Dictionary[StringName, int] = {}
var _icon_alignment_rect := Rect2()
var _has_icon_alignment_rect := false
static var _normalized_icons: Dictionary = {}
var _editor_preview_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		set_process(true)
		_refresh_editor_preview()
	elif preview_enabled:
		refresh(_preview_entries())
	else:
		set_process(false)
		visible = false
		size = Vector2.ZERO


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_refresh_editor_preview()


func refresh(entries: Array) -> void:
	var signature_parts: PackedStringArray = []
	for entry_variant: Variant in entries:
		var entry: Dictionary = entry_variant
		signature_parts.append("%s:%d:%s:%s" % [
				String(entry.get("id", &"")), int(entry.get("value", 0)),
				str(bool(entry.get("show_stack_count", false))),
				String(entry.get("icon_path", ""))])
	var next_signature := "|".join(signature_parts)
	if next_signature == _signature:
		visible = not entries.is_empty()
		return
	_signature = next_signature
	var previous_values: Dictionary[StringName, int] = _values.duplicate()
	_clear_slots()
	if entries.is_empty():
		visible = false
		size = Vector2.ZERO
		return

	var cursor_x := 0.0
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		var effect_id := StringName(entry.get("id", &""))
		var value := maxi(int(entry.get("value", 0)), 0)
		var slot_width := _slot_width(
				bool(entry.get("show_stack_count", false)), effect_id, value)
		_build_slot(entry, cursor_x, slot_width, previous_values)
		cursor_x += slot_width + slot_gap
	size = Vector2(cursor_x - slot_gap, _slot_height())
	visible = true


func effect_ids() -> Array[StringName]:
	return _effect_ids.duplicate()


func debug_slot_rects() -> Array[Rect2]:
	return _slot_rects.duplicate()


func debug_icons() -> Array[TextureRect]:
	return _icons.duplicate()


func icon_alignment_center_x() -> float:
	if not _has_icon_alignment_rect:
		return size.x * 0.5
	return _icon_alignment_rect.get_center().x


func debug_icon_alignment_rect() -> Rect2:
	return _icon_alignment_rect


func _clear_slots() -> void:
	for child: Node in get_children():
		child.free()
	_effect_ids.clear()
	_slot_rects.clear()
	_icons.clear()
	_values.clear()
	_icon_alignment_rect = Rect2()
	_has_icon_alignment_rect = false


func _build_slot(entry: Dictionary, slot_x: float, slot_width: float,
		previous_values: Dictionary[StringName, int]) -> void:
	var effect_id := StringName(entry.get("id", &""))
	var value := maxi(int(entry.get("value", 0)), 0)
	var show_stack_count := bool(entry.get("show_stack_count", false))
	var slot_rect := Rect2(
			Vector2(slot_x, 0.0), Vector2(slot_width, _slot_height()))
	_effect_ids.append(effect_id)
	_slot_rects.append(slot_rect)
	_values[effect_id] = value

	var slot := Control.new()
	slot.name = "Status_%s" % String(effect_id)
	slot.position = slot_rect.position
	slot.size = slot_rect.size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta("effect_id", effect_id)
	add_child(slot)

	var icon_texture := _load_normalized_icon(String(entry.get("icon_path", "")))
	var icon_scale := _icon_scale_for(effect_id)
	var icon_visual_size := icon_box_size * icon_scale
	var icon_visual_position := (icon_box_size - icon_visual_size) * 0.5
	if icon_shadow_enabled:
		var icon_shadow := TextureRect.new()
		icon_shadow.name = "IconShadow"
		icon_shadow.position = icon_visual_position + icon_shadow_offset
		icon_shadow.size = icon_visual_size
		icon_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_shadow.texture = icon_texture
		icon_shadow.self_modulate = icon_shadow_color
		slot.add_child(icon_shadow)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = icon_visual_position
	icon.size = icon_visual_size
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 统一的是 34px 光学框，不是把长条剑气和近方形毒素强拉成同一比例。
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = icon_texture
	slot.add_child(icon)
	_icons.append(icon)
	var aligned_icon_rect := Rect2(
			Vector2(slot_x, 0.0) + icon_visual_position, icon_visual_size)
	if _has_icon_alignment_rect:
		_icon_alignment_rect = _icon_alignment_rect.merge(aligned_icon_rect)
	else:
		_icon_alignment_rect = aligned_icon_rect
		_has_icon_alignment_rect = true

	var count_control := Control.new()
	count_control.name = "Count"
	# 层数置于图标右下外侧：同组但不遮挡毒素，也不悬在图标正下方。
	count_control.position = Vector2(icon_box_size.x, 0.0) \
			+ _count_offset_for(effect_id)
	count_control.size = Vector2(_count_content_width(value), count_box_size.y)
	count_control.visible = show_stack_count
	count_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_control.set_meta("formatted_text", "x%d" % value)
	slot.add_child(count_control)
	# @tool 编辑器环境不保证运行时 Autoload 已初始化；直接使用 FontManager 的同源字体资源，
	# 让视窗预览与 F6 都能绘制数字，同时正式战斗字形保持完全一致。
	var count_font := FontVariation.new()
	count_font.base_font = COUNT_BASE_FONT
	count_font.variation_embolden = count_embolden
	var prefix_label := _build_count_glyph("Prefix", "x", count_font)
	count_control.add_child(prefix_label)
	var prefix_width := ceilf(prefix_label.get_combined_minimum_size().x)
	prefix_label.position = Vector2.ZERO
	prefix_label.size = Vector2(prefix_width, count_box_size.y)
	var value_text := str(value)
	var value_label := _build_count_glyph("Value", value_text, count_font)
	count_control.add_child(value_label)
	var value_width := ceilf(value_label.get_combined_minimum_size().x)
	value_label.position = Vector2(prefix_width + count_symbol_gap, 0.0)
	value_label.size = Vector2(value_width, count_box_size.y)
	count_control.size.x = maxf(
			count_box_size.x, value_label.position.x + value_width)
	if show_stack_count and previous_values.has(effect_id) \
			and int(previous_values[effect_id]) != value:
		count_control.pivot_offset = count_control.size * 0.5
		count_control.scale = Vector2.ONE * 0.82
		create_tween().tween_property(
				count_control, "scale", Vector2.ONE, count_pop_duration) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if enter_motion_enabled and not Engine.is_editor_hint() \
			and not previous_values.has(effect_id):
		_play_enter_motion(slot, slot_rect.position)


func _play_enter_motion(slot: Control, resting_position: Vector2) -> void:
	slot.pivot_offset = Vector2(icon_box_size.x * 0.5, icon_box_size.y * 0.5)
	slot.position = resting_position + Vector2(0.0, enter_lift)
	slot.scale = Vector2.ONE * enter_scale
	slot.modulate.a = 0.0
	slot.set_meta("enter_motion_played", true)
	var tween := slot.create_tween().set_parallel(true) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "position", resting_position, enter_duration)
	tween.tween_property(slot, "scale", Vector2.ONE, enter_duration)
	tween.tween_property(slot, "modulate:a", 1.0, enter_duration)


func _build_count_glyph(node_name: String, text: String,
		font: FontVariation) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", count_font_size)
	label.add_theme_color_override("font_color", count_text_color)
	label.add_theme_color_override("font_outline_color", count_outline_color)
	label.add_theme_constant_override("outline_size", count_outline_size)
	label.add_theme_color_override("font_shadow_color", count_shadow_color)
	label.add_theme_constant_override("shadow_offset_x", count_shadow_offset.x)
	label.add_theme_constant_override("shadow_offset_y", count_shadow_offset.y)
	label.add_theme_constant_override(
			"shadow_outline_size", count_shadow_outline_size)
	return label


func _count_content_width(value: int) -> float:
	var font := FontVariation.new()
	font.base_font = COUNT_BASE_FONT
	font.variation_embolden = count_embolden
	var prefix_label := _build_count_glyph("MeasurePrefix", "x", font)
	var value_label := _build_count_glyph("MeasureValue", str(value), font)
	add_child(prefix_label)
	add_child(value_label)
	var prefix_width := ceilf(prefix_label.get_combined_minimum_size().x)
	var value_width := ceilf(value_label.get_combined_minimum_size().x)
	prefix_label.free()
	value_label.free()
	return maxf(count_box_size.x,
			prefix_width + count_symbol_gap + value_width)


func _slot_width(show_stack_count: bool, effect_id: StringName = &"",
		value: int = 0) -> float:
	if not show_stack_count:
		return maxf(icon_box_size.x, 1.0)
	var resolved_offset := _count_offset_for(effect_id)
	return maxf(icon_box_size.x,
			icon_box_size.x + resolved_offset.x + _count_content_width(value))


func _slot_height() -> float:
	var lowest_count_y := count_offset.y
	if use_per_icon_count_offsets:
		lowest_count_y = maxf(
				poison_count_offset.y,
				maxf(vulnerable_count_offset.y, sword_qi_count_offset.y))
	return maxf(icon_box_size.y,
			lowest_count_y + count_box_size.y
					+ maxf(float(count_shadow_offset.y), 0.0))


func _count_offset_for(effect_id: StringName) -> Vector2:
	if not use_per_icon_count_offsets:
		return count_offset
	match effect_id:
		&"poison":
			return poison_count_offset
		&"vulnerable":
			return vulnerable_count_offset
		&"sword_qi":
			return sword_qi_count_offset
		_:
			return count_offset


func _icon_scale_for(effect_id: StringName) -> float:
	if not use_per_icon_visual_scales:
		return 1.0
	match effect_id:
		&"poison":
			return poison_icon_scale
		&"vulnerable":
			return vulnerable_icon_scale
		&"sword_qi":
			return sword_qi_icon_scale
		_:
			return 1.0


func _preview_entries() -> Array[Dictionary]:
	return [
		{
			"id": &"poison", "value": preview_poison_count,
			"show_stack_count": true,
			"icon_path": "res://assets/ui/effects/poison.png",
		},
		{
			"id": &"vulnerable", "value": preview_vulnerable_count,
			"show_stack_count": true,
			"icon_path": "res://assets/ui/effects/vulnerable.png",
		},
		{
			"id": &"sword_qi", "value": preview_sword_qi_count,
			"show_stack_count": true,
			"icon_path": "res://assets/ui/effects/sword_qi.png",
		},
	]


func _refresh_editor_preview() -> void:
	var signature_parts := PackedStringArray([
			str(preview_enabled), str(icon_box_size), str(slot_gap),
			str(icon_alpha_threshold), str(icon_shadow_enabled),
			str(icon_shadow_color), str(icon_shadow_offset),
			str(use_per_icon_visual_scales), str(poison_icon_scale),
			str(vulnerable_icon_scale), str(sword_qi_icon_scale),
			str(enter_motion_enabled), str(enter_duration), str(enter_lift),
			str(enter_scale),
			str(count_offset), str(count_box_size), str(count_font_size),
			str(count_embolden), str(count_symbol_gap), str(count_outline_size),
			str(count_text_color), str(count_outline_color), str(count_shadow_color),
			str(count_shadow_offset), str(count_shadow_outline_size),
			str(use_per_icon_count_offsets), str(poison_count_offset),
			str(vulnerable_count_offset), str(sword_qi_count_offset),
			str(preview_poison_count), str(preview_vulnerable_count),
			str(preview_sword_qi_count)])
	var next_signature := "|".join(signature_parts)
	if next_signature == _editor_preview_signature:
		return
	_editor_preview_signature = next_signature
	_signature = ""
	if preview_enabled:
		refresh(_preview_entries())
	else:
		_clear_slots()
		visible = false
		size = Vector2.ZERO


func _load_normalized_icon(icon_path: String) -> Texture2D:
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	var cache_key := "%s:%0.3f" % [icon_path, icon_alpha_threshold]
	if _normalized_icons.has(cache_key):
		return _normalized_icons[cache_key] as Texture2D
	var source := load(icon_path) as Texture2D
	var normalized := _crop_to_visible_content(source)
	_normalized_icons[cache_key] = normalized
	return normalized


func _crop_to_visible_content(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < icon_alpha_threshold:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(Vector2(minimum), Vector2(maximum - minimum + Vector2i.ONE))
	return atlas

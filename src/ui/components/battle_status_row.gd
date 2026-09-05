@tool
class_name BattleStatusRow
extends Control

## 出战英雄玩家名后的常驻效果队列。
## 每个状态使用相同的透明图标槽；数字锁在槽内，不参与图标对齐或横向节奏。

signal status_hovered(effect_id: StringName, value: int, target_rect: Rect2)
signal status_unhovered

const COUNT_BASE_FONT: Font = preload("res://assets/font/zlabs_pixel_ui.tres")
const DEFAULT_NUMBER_TUNING: BattleStatusNumberTuning = preload(
		"res://src/ui/components/battle_status_number_tuning.tres")
const ALPHA_SILHOUETTE_SHADER_CODE := """
shader_type canvas_item;

varying vec4 item_color;

void vertex() {
	item_color = COLOR;
}

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	COLOR = vec4(item_color.rgb, item_color.a * alpha);
}
"""

@export_group("Buff Icon")
@export var icon_box_size := Vector2(34.0, 34.0)
## 每个 Buff 占据相同的透明槽位；排版只认图标槽，不再被 xN 或素材宽窄改变节奏。
## 当前保持单行；换行需在重新选择 HUD 安全区域后另行接入。
@export var slot_size := Vector2(52.0, 42.0)
@export_range(0.0, 0.5, 0.01) var icon_alpha_threshold := 0.06
## P2 镜像整组展开方向：第一个获得的状态最靠近玩家名；单项数字仍位于图标正下方。
@export var right_to_left := false

@export_group("Icon Shadow")
@export var icon_shadow_enabled := true
@export var icon_shadow_color := Color(0.0, 0.0, 0.0, 0.32)
@export var icon_shadow_offset := Vector2(2.0, 2.0)

@export_group("Icon Contrast Envelope")
## 轮廓直接复用图标透明形状，不生成矩形底板；深色八方向外沿负责跨场景对比，
## 暖色迎光边只在左上露出一圈，避免整枚图标被统一染色。
@export var icon_contour_enabled := true
@export_range(1, 2, 1, "suffix:px") var icon_contour_width := 1
@export var icon_contour_dark_color := Color(0.025, 0.020, 0.018, 0.78)
@export var icon_contour_rim_color := Color(0.94, 0.79, 0.55, 0.34)
@export var icon_contour_rim_offset := Vector2(-1.0, -1.0)

@export_group("Per Icon Optical Scale")
## 剑气是纵向窄构图；等比放大可补偿可见面积，不改变其方向语义。
@export var use_per_icon_visual_scales := true
@export_range(0.5, 2.0, 0.01) var poison_icon_scale := 1.0
@export_range(0.5, 2.0, 0.01) var vulnerable_icon_scale := 1.0
@export_range(0.5, 2.0, 0.01) var sword_qi_icon_scale := 1.2

@export_group("Buff Enter Motion")
@export var enter_motion_enabled := true
@export_range(0.12, 0.4, 0.01, "suffix:s") var enter_duration := 0.24
## 从玩家名一侧横向落入：P1 为 -x，P2 自动镜像为 +x。
@export_range(0.0, 8.0, 1.0, "suffix:px") var enter_travel := 3.0
@export_range(0.5, 1.0, 0.01) var enter_scale := 0.84
@export_range(1.0, 1.2, 0.01) var enter_stamp_scale := 1.06
@export_range(0.0, 0.12, 0.01, "suffix:s") var enter_stagger := 0.04
@export_range(0.0, 0.12, 0.01, "suffix:s") var enter_count_delay := 0.04
@export_range(0.5, 1.0, 0.01) var enter_count_scale := 0.85
@export var enter_stamp_flash_color := Color(1.0, 0.86, 0.58, 0.88)

@export_group("Stack Number Source")
## 在 buff_tuning_lab 中展开此 Resource 调整；正式战斗读取同一份资源，禁止再手抄参数。
@export var number_tuning: BattleStatusNumberTuning = DEFAULT_NUMBER_TUNING:
	set(value):
		_disconnect_number_tuning()
		number_tuning = value if value != null else DEFAULT_NUMBER_TUNING
		_connect_number_tuning()
		_on_number_tuning_changed()

@export_group("Editor Preview")
## 正式战斗运行时保持关闭；调试场景实例会打开并展示真实毒素/脆弱/剑气组件。
@export var preview_enabled := false
@export_range(1, 99, 1) var preview_poison_count := 3
@export_range(1, 99, 1) var preview_vulnerable_count := 2
@export_range(1, 99, 1) var preview_sword_qi_count := 4

var _signature := ""
var _owner_key: StringName = &"default"
var _orders_by_owner: Dictionary = {}
var _current_entries: Array[Dictionary] = []
var _effect_ids: Array[StringName] = []
var _slot_rects: Array[Rect2] = []
var _icons: Array[TextureRect] = []
var _values: Dictionary[StringName, int] = {}
var _instance_keys: Dictionary[StringName, StringName] = {}
var _icon_alignment_rect := Rect2()
var _has_icon_alignment_rect := false
var _hovered_effect_id: StringName = &""
static var _normalized_icons: Dictionary = {}
static var _alpha_silhouette_material: ShaderMaterial = null
var _editor_preview_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_number_tuning()
	if Engine.is_editor_hint():
		set_process(true)
		_refresh_editor_preview()
	elif preview_enabled:
		set_process(true)
		refresh(_preview_entries())
	else:
		set_process(false)
		visible = false
		size = Vector2.ZERO


func _connect_number_tuning() -> void:
	if number_tuning == null:
		return
	if not number_tuning.changed.is_connected(_on_number_tuning_changed):
		number_tuning.changed.connect(_on_number_tuning_changed)


func _disconnect_number_tuning() -> void:
	if number_tuning == null:
		return
	if number_tuning.changed.is_connected(_on_number_tuning_changed):
		number_tuning.changed.disconnect(_on_number_tuning_changed)


func _on_number_tuning_changed() -> void:
	_editor_preview_signature = ""
	if not is_node_ready():
		return
	if Engine.is_editor_hint():
		_refresh_editor_preview()
	elif preview_enabled:
		refresh(_preview_entries())


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or preview_enabled:
		_refresh_editor_preview()


func refresh(entries: Array) -> void:
	var ordered_entries: Array[Dictionary] = _ordered_entries(entries)
	_current_entries = ordered_entries.duplicate(true)
	var signature_parts: PackedStringArray = []
	for entry_variant: Variant in ordered_entries:
		var entry: Dictionary = entry_variant
		signature_parts.append("%s:%s:%d:%s:%s:%s" % [
				String(entry.get("id", &"")),
				String(entry.get("instance_key", entry.get("id", &""))),
				int(entry.get("value", 0)),
				str(bool(entry.get("show_stack_count", false))),
				String(entry.get("icon_path", "")),
				String(entry.get("scope", ""))])
	var next_signature := "|".join(signature_parts)
	if next_signature == _signature:
		visible = not ordered_entries.is_empty()
		return
	_signature = next_signature
	var previous_values: Dictionary[StringName, int] = _values.duplicate()
	var previous_instance_keys: Dictionary[StringName, StringName] = _instance_keys.duplicate()
	_clear_slots()
	if ordered_entries.is_empty():
		visible = false
		size = Vector2.ZERO
		return

	var slot_origins: Array[float] = []
	var layout_direction := -1.0 if right_to_left else 1.0
	for index: int in ordered_entries.size():
		slot_origins.append(float(index) * slot_size.x * layout_direction)
	var new_motion_index := 0
	for index: int in ordered_entries.size():
		var effect_id := StringName(ordered_entries[index].get("id", &""))
		var instance_key := StringName(ordered_entries[index].get(
				"instance_key", effect_id))
		var is_new_status := not previous_instance_keys.has(effect_id) \
				or previous_instance_keys[effect_id] != instance_key
		var enter_delay := enter_stagger * float(new_motion_index) \
				if is_new_status else 0.0
		_build_slot(ordered_entries[index], slot_origins[index], slot_size.x,
				previous_values, previous_instance_keys, enter_delay)
		if is_new_status:
			new_motion_index += 1
	size = Vector2(float(ordered_entries.size()) * slot_size.x, _slot_height())
	visible = true


func set_owner_key(owner_key: StringName) -> void:
	if owner_key == _owner_key:
		return
	_owner_key = owner_key
	_signature = ""
	_current_entries.clear()
	_clear_slots()
	visible = false
	size = Vector2.ZERO


func owner_key() -> StringName:
	return _owner_key


## 换人演出开始时立即撤下英雄槽状态；剑气、玄金不动相、不坠神言等
## 队伍状态保留原实例与原顺序，既不会提前读取新英雄状态，也不会重新播放入场。
func retain_team_entries() -> void:
	var team_entries: Array[Dictionary] = []
	for entry: Dictionary in _current_entries:
		if String(entry.get("scope", "")) == "team":
			team_entries.append(entry)
	refresh(team_entries)


## 目录只提供当前有哪些状态；视觉顺序由每名英雄的首次出现顺序决定。
## 已有项保持位置，新项永远追加，消失后再次获得则重新追加到末尾。
func _ordered_entries(entries: Array) -> Array[Dictionary]:
	var entries_by_id: Dictionary = {}
	var incoming_ids: Array[StringName] = []
	for entry_variant: Variant in entries:
		var entry: Dictionary = entry_variant
		var effect_id := StringName(entry.get("id", &""))
		if effect_id == &"":
			continue
		entries_by_id[effect_id] = entry
		incoming_ids.append(effect_id)
	var previous_order: Array = _orders_by_owner.get(_owner_key, [])
	var next_order: Array[StringName] = []
	for effect_variant: Variant in previous_order:
		var effect_id := StringName(effect_variant)
		if entries_by_id.has(effect_id):
			next_order.append(effect_id)
	for effect_id: StringName in incoming_ids:
		if not next_order.has(effect_id):
			next_order.append(effect_id)
	_orders_by_owner[_owner_key] = next_order.duplicate()
	var result: Array[Dictionary] = []
	for effect_id: StringName in next_order:
		result.append(entries_by_id[effect_id] as Dictionary)
	return result


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
	if _hovered_effect_id != &"":
		_hovered_effect_id = &""
		status_unhovered.emit()
	for child: Node in get_children():
		child.free()
	_effect_ids.clear()
	_slot_rects.clear()
	_icons.clear()
	_values.clear()
	_instance_keys.clear()
	_icon_alignment_rect = Rect2()
	_has_icon_alignment_rect = false


func _build_slot(entry: Dictionary, slot_x: float, slot_width: float,
		previous_values: Dictionary[StringName, int],
		previous_instance_keys: Dictionary[StringName, StringName],
		enter_delay: float) -> void:
	var effect_id := StringName(entry.get("id", &""))
	var instance_key := StringName(entry.get("instance_key", effect_id))
	var had_same_instance := previous_instance_keys.has(effect_id) \
			and previous_instance_keys[effect_id] == instance_key
	var value := maxi(int(entry.get("value", 0)), 0)
	var show_stack_count := bool(entry.get("show_stack_count", false))
	var slot_rect := Rect2(
			Vector2(slot_x, 0.0), Vector2(slot_width, _slot_height()))
	_effect_ids.append(effect_id)
	_slot_rects.append(slot_rect)
	_values[effect_id] = value
	_instance_keys[effect_id] = instance_key

	var slot := Control.new()
	slot.name = "Status_%s" % String(effect_id)
	slot.position = slot_rect.position
	slot.size = slot_rect.size
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_HELP
	slot.set_meta("effect_id", effect_id)
	slot.set_meta("instance_key", instance_key)
	slot.set_meta("scope", String(entry.get("scope", "")))
	add_child(slot)

	var icon_texture := _load_normalized_icon(String(entry.get("icon_path", "")))
	var icon_scale := _icon_scale_for(effect_id)
	var icon_visual_size := icon_box_size * icon_scale
	# P2 only mirrors the order of whole slots. The contents of each slot retain
	# the same reading order: icon first, then the x-count on its right.
	var icon_origin_x := 0.0
	var icon_visual_position := Vector2(icon_origin_x, 0.0) \
			+ (icon_box_size - icon_visual_size) * 0.5
	if icon_shadow_enabled:
		var icon_shadow := _build_icon_layer(
				"IconShadow", icon_texture,
				icon_visual_position + icon_shadow_offset,
				icon_visual_size, icon_shadow_color, true)
		slot.add_child(icon_shadow)

	if icon_contour_enabled:
		var contour := Control.new()
		contour.name = "IconContour"
		contour.position = icon_visual_position
		contour.size = icon_visual_size
		contour.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contour.clip_contents = false
		slot.add_child(contour)
		var width := float(icon_contour_width)
		var dark_offsets: Array[Vector2] = [
			Vector2(-width, -width), Vector2(0.0, -width),
			Vector2(width, -width), Vector2(-width, 0.0),
			Vector2(width, 0.0), Vector2(-width, width),
			Vector2(0.0, width), Vector2(width, width),
		]
		for outline_index: int in dark_offsets.size():
			var outline := _build_icon_layer(
					"Dark_%d" % outline_index, icon_texture,
					dark_offsets[outline_index], icon_visual_size,
					icon_contour_dark_color, true)
			contour.add_child(outline)
		var warm_rim := _build_icon_layer(
				"WarmRim", icon_texture, icon_contour_rim_offset,
				icon_visual_size, icon_contour_rim_color, true)
		contour.add_child(warm_rim)
		var stamp_flash := _build_icon_layer(
				"StampFlash", icon_texture,
				icon_visual_position + icon_contour_rim_offset,
				icon_visual_size, enter_stamp_flash_color, true)
		stamp_flash.modulate.a = 0.0
		slot.add_child(stamp_flash)

	var icon := _build_icon_layer(
			"Icon", icon_texture, icon_visual_position,
			icon_visual_size, Color.WHITE)
	# 统一的是 34px 光学框，不是把长条剑气和近方形毒素强拉成同一比例。
	slot.add_child(icon)
	_icons.append(icon)
	var aligned_icon_rect := Rect2(
			Vector2(slot_x, 0.0) + icon_visual_position, icon_visual_size)
	if icon_contour_enabled:
		aligned_icon_rect = aligned_icon_rect.grow(float(icon_contour_width))
	if _has_icon_alignment_rect:
		_icon_alignment_rect = _icon_alignment_rect.merge(aligned_icon_rect)
	else:
		_icon_alignment_rect = aligned_icon_rect
		_has_icon_alignment_rect = true

	var count_control := Control.new()
	count_control.name = "Count"
	# 数字锁在本图标正下方；P2 只反转状态组，不反转单槽内部布局。
	var count_width := _count_content_width(value)
	var resolved_count_offset := _resolved_count_position(
			effect_id, count_width)
	count_control.position = resolved_count_offset
	count_control.size = Vector2(count_width, number_tuning.count_box_size.y)
	count_control.visible = show_stack_count
	count_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_control.set_meta("formatted_text", "x%d" % value)
	count_control.set_meta("count_increase_motion_played", false)
	slot.add_child(count_control)
	# @tool 编辑器环境不保证运行时 Autoload 已初始化；直接使用 FontManager 的同源字体资源，
	# 让视窗预览与 F6 都能绘制数字，同时正式战斗字形保持完全一致。
	var count_font := FontVariation.new()
	count_font.base_font = COUNT_BASE_FONT
	count_font.variation_embolden = number_tuning.count_embolden
	var prefix_label := _build_count_glyph("Prefix", "x", count_font)
	count_control.add_child(prefix_label)
	var prefix_width := ceilf(prefix_label.get_combined_minimum_size().x)
	prefix_label.position = Vector2.ZERO
	prefix_label.size = Vector2(prefix_width, number_tuning.count_box_size.y)
	var value_text := str(value)
	var value_label := _build_count_glyph("Value", value_text, count_font)
	count_control.add_child(value_label)
	var value_width := ceilf(value_label.get_combined_minimum_size().x)
	value_label.position = Vector2(prefix_width + number_tuning.count_symbol_gap, 0.0)
	value_label.size = Vector2(value_width, number_tuning.count_box_size.y)
	count_control.size.x = maxf(
			number_tuning.count_box_size.x, value_label.position.x + value_width)
	if show_stack_count and had_same_instance and previous_values.has(effect_id) \
			and int(previous_values[effect_id]) < value:
		var resting_position := count_control.position
		count_control.set_meta("count_increase_motion_played", true)
		count_control.pivot_offset = count_control.size * 0.5
		count_control.position = resting_position + Vector2(
				0.0, number_tuning.count_increase_lift)
		count_control.scale = Vector2.ONE * number_tuning.count_increase_scale
		var count_tween := create_tween().set_parallel(true)
		count_tween.tween_property(
				count_control, "position", resting_position,
				number_tuning.count_pop_duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		count_tween.tween_property(
				count_control, "scale", Vector2.ONE,
				number_tuning.count_pop_duration) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if enter_motion_enabled and not Engine.is_editor_hint() \
			and not had_same_instance:
		_play_enter_motion(slot, slot_rect.position,
				Vector2(icon_origin_x, 0.0) + icon_box_size * 0.5,
				enter_delay)
	slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot, effect_id, value))
	slot.mouse_exited.connect(_on_slot_mouse_exited.bind(effect_id))


func _build_icon_layer(node_name: String, texture: Texture2D,
		layer_position: Vector2, layer_size: Vector2,
		layer_color: Color, alpha_silhouette: bool = false) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = node_name
	layer.position = layer_position
	layer.size = layer_size
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture = texture
	layer.self_modulate = layer_color
	if alpha_silhouette:
		layer.material = _get_alpha_silhouette_material()
	return layer


func _get_alpha_silhouette_material() -> ShaderMaterial:
	if _alpha_silhouette_material != null:
		return _alpha_silhouette_material
	var shader := Shader.new()
	shader.code = ALPHA_SILHOUETTE_SHADER_CODE
	_alpha_silhouette_material = ShaderMaterial.new()
	_alpha_silhouette_material.shader = shader
	return _alpha_silhouette_material


func _play_enter_motion(slot: Control, resting_position: Vector2,
		icon_center: Vector2, enter_delay: float) -> void:
	var direction := 1 if right_to_left else -1
	var approach_duration := enter_duration * 0.42
	var settle_duration := maxf(enter_duration - approach_duration, 0.01)
	slot.pivot_offset = icon_center
	slot.position = resting_position + Vector2(float(direction) * enter_travel, 0.0)
	slot.scale = Vector2.ONE * enter_scale
	slot.modulate.a = 0.0
	slot.set_meta("enter_motion_played", true)
	slot.set_meta("enter_motion_delay", enter_delay)
	slot.set_meta("enter_motion_direction", direction)
	slot.set_meta("enter_stamp_scale", enter_stamp_scale)

	var transform_tween := slot.create_tween()
	if enter_delay > 0.0:
		transform_tween.tween_interval(enter_delay)
	transform_tween.set_parallel(true)
	transform_tween.tween_property(
			slot, "position", resting_position, approach_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transform_tween.tween_property(
			slot, "scale", Vector2.ONE * enter_stamp_scale, approach_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transform_tween.tween_property(
			slot, "modulate:a", 1.0, approach_duration * 0.72) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	transform_tween.chain().tween_property(
			slot, "scale", Vector2.ONE, settle_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var count := slot.get_node_or_null("Count") as Control
	if count != null and count.visible:
		count.pivot_offset = count.size * 0.5
		count.scale = Vector2.ONE * enter_count_scale
		count.modulate.a = 0.0
		var count_duration := minf(0.12, maxf(enter_duration * 0.5, 0.06))
		var count_tween := count.create_tween().set_parallel(true)
		count_tween.tween_property(count, "modulate:a", 1.0, count_duration) \
				.set_delay(enter_delay + enter_count_delay) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		count_tween.tween_property(count, "scale", Vector2.ONE, count_duration) \
				.set_delay(enter_delay + enter_count_delay) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var icon_shadow := slot.get_node_or_null("IconShadow") as TextureRect
	if icon_shadow != null:
		icon_shadow.modulate.a = 0.0
		icon_shadow.create_tween().tween_property(
				icon_shadow, "modulate:a", 1.0, enter_duration * 0.5) \
				.set_delay(enter_delay + enter_duration * 0.25) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var stamp_flash := slot.get_node_or_null("StampFlash") as TextureRect
	if stamp_flash != null:
		stamp_flash.modulate.a = 0.0
		var flash_tween := stamp_flash.create_tween()
		flash_tween.tween_interval(enter_delay + approach_duration * 0.66)
		flash_tween.tween_property(stamp_flash, "modulate:a", 1.0, 0.016) \
				.set_trans(Tween.TRANS_LINEAR)
		flash_tween.tween_property(stamp_flash, "modulate:a", 0.0, 0.052) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_slot_mouse_entered(slot: Control, effect_id: StringName, value: int) -> void:
	_hovered_effect_id = effect_id
	var icon := slot.get_node_or_null("Icon") as TextureRect
	var target_rect := icon.get_global_rect() if icon != null else slot.get_global_rect()
	status_hovered.emit(effect_id, value, target_rect)


func _on_slot_mouse_exited(effect_id: StringName) -> void:
	if _hovered_effect_id != effect_id:
		return
	_hovered_effect_id = &""
	status_unhovered.emit()


func _build_count_glyph(node_name: String, text: String,
		font: FontVariation) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", number_tuning.count_font_size)
	label.add_theme_color_override("font_color", number_tuning.count_text_color)
	label.add_theme_color_override(
			"font_outline_color", number_tuning.count_outline_color)
	label.add_theme_constant_override(
			"outline_size", number_tuning.count_outline_size)
	label.add_theme_color_override(
			"font_shadow_color", number_tuning.count_shadow_color)
	label.add_theme_constant_override(
			"shadow_offset_x", number_tuning.count_shadow_offset.x)
	label.add_theme_constant_override(
			"shadow_offset_y", number_tuning.count_shadow_offset.y)
	label.add_theme_constant_override(
			"shadow_outline_size", number_tuning.count_shadow_outline_size)
	return label


func _count_content_width(value: int) -> float:
	var font := FontVariation.new()
	font.base_font = COUNT_BASE_FONT
	font.variation_embolden = number_tuning.count_embolden
	var prefix_label := _build_count_glyph("MeasurePrefix", "x", font)
	var value_label := _build_count_glyph("MeasureValue", str(value), font)
	add_child(prefix_label)
	add_child(value_label)
	var prefix_width := ceilf(prefix_label.get_combined_minimum_size().x)
	var value_width := ceilf(value_label.get_combined_minimum_size().x)
	prefix_label.free()
	value_label.free()
	return maxf(number_tuning.count_box_size.x,
			prefix_width + number_tuning.count_symbol_gap + value_width)


func _slot_width(_show_stack_count: bool, _effect_id: StringName = &"",
		_value: int = 0) -> float:
	return slot_size.x


func _visible_layout_bounds(entry: Dictionary) -> Rect2:
	var effect_id := StringName(entry.get("id", &""))
	var value := maxi(int(entry.get("value", 0)), 0)
	var icon_scale := _icon_scale_for(effect_id)
	var icon_visual_size := icon_box_size * icon_scale
	var icon_visual_position := (icon_box_size - icon_visual_size) * 0.5
	var result := Rect2(icon_visual_position, icon_visual_size)
	if icon_contour_enabled:
		result = result.grow(float(icon_contour_width))
	if icon_shadow_enabled and icon_shadow_color.a > 0.0:
		result = result.merge(Rect2(
				icon_visual_position + icon_shadow_offset, icon_visual_size))
	if not bool(entry.get("show_stack_count", false)):
		return result
	var count_width := _count_content_width(value)
	var count_position := _resolved_count_position(effect_id, count_width)
	var count_size := Vector2(count_width, number_tuning.count_box_size.y)
	var count_bounds := Rect2(count_position, count_size).grow(
			float(number_tuning.count_outline_size))
	if number_tuning.count_shadow_color.a > 0.0:
		var shadow_grow := float(number_tuning.count_outline_size \
				+ number_tuning.count_shadow_outline_size)
		count_bounds = count_bounds.merge(Rect2(
				count_position + Vector2(number_tuning.count_shadow_offset),
				count_size).grow(shadow_grow))
	return result.merge(count_bounds)


func _slot_height() -> float:
	var lowest_count_y := number_tuning.count_offset.y
	if number_tuning.use_per_icon_count_offsets:
		lowest_count_y = maxf(
				number_tuning.poison_count_offset.y,
				maxf(number_tuning.vulnerable_count_offset.y,
						number_tuning.sword_qi_count_offset.y))
	return maxf(slot_size.y, maxf(icon_box_size.y,
			lowest_count_y + number_tuning.count_box_size.y
					+ maxf(float(number_tuning.count_shadow_offset.y), 0.0)))


func _count_offset_for(effect_id: StringName) -> Vector2:
	if not number_tuning.use_per_icon_count_offsets:
		return number_tuning.count_offset
	match effect_id:
		&"poison":
			return number_tuning.poison_count_offset
		&"vulnerable":
			return number_tuning.vulnerable_count_offset
		&"sword_qi":
			return number_tuning.sword_qi_count_offset
		_:
			return number_tuning.count_offset


func _resolved_count_position(effect_id: StringName, count_width: float) -> Vector2:
	var optical_position := _count_offset_for(effect_id)
	var right_effect_margin := float(number_tuning.count_outline_size \
			+ number_tuning.count_shadow_outline_size \
			+ maxi(number_tuning.count_shadow_offset.x, 0) + 1)
	var latest_safe_x := slot_size.x - count_width - right_effect_margin
	return Vector2(minf(optical_position.x, latest_safe_x), optical_position.y)


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
			str(preview_enabled), str(icon_box_size), str(slot_size),
			str(icon_alpha_threshold), str(right_to_left), str(icon_shadow_enabled),
			str(icon_shadow_color), str(icon_shadow_offset),
			str(icon_contour_enabled), str(icon_contour_width),
			str(icon_contour_dark_color), str(icon_contour_rim_color),
			str(icon_contour_rim_offset),
			str(use_per_icon_visual_scales), str(poison_icon_scale),
			str(vulnerable_icon_scale), str(sword_qi_icon_scale),
			str(enter_motion_enabled), str(enter_duration), str(enter_travel),
			str(enter_scale), str(enter_stamp_scale), str(enter_stagger),
			str(enter_count_delay), str(enter_count_scale),
			str(enter_stamp_flash_color),
			str(number_tuning.count_offset), str(number_tuning.count_box_size),
			str(number_tuning.count_font_size), str(number_tuning.count_embolden),
			str(number_tuning.count_symbol_gap),
			str(number_tuning.count_outline_size),
			str(number_tuning.count_text_color),
			str(number_tuning.count_outline_color),
			str(number_tuning.count_shadow_color),
			str(number_tuning.count_shadow_offset),
			str(number_tuning.count_shadow_outline_size),
			str(number_tuning.count_pop_duration),
			str(number_tuning.count_increase_lift),
			str(number_tuning.count_increase_scale),
			str(number_tuning.use_per_icon_count_offsets),
			str(number_tuning.poison_count_offset),
			str(number_tuning.vulnerable_count_offset),
			str(number_tuning.sword_qi_count_offset),
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

extends Control
class_name CodexNativeTextLayer

## 将缩放书页里的文字复制到最终画布坐标中绘制。
## 原按钮仍保留点击区；书页纹理/框体继续由 GalleryHost 统一缩放，文字不再经过 0.84 二次采样。

const MIN_BODY_FONT_SIZE := 15
const PAGE_NAVIGATION_FONT_SIZE := 18
## Z工坊 15px 原生层在 0.84 倍书页外壳中，字面相对头像框会留下约 3px 的左侧视觉偏差。
## 这里统一补偿最终画布像素，禁止再通过每张卡的源 Label 位置重复修正。
const HERO_NAME_OPTICAL_OFFSET_X := 3.0
const PAGE_NAVIGATION_COLOR := Color(0.278431, 0.227451, 0.168627, 0.88)
const PAGE_NAVIGATION_DISABLED_COLOR := Color(0.278431, 0.227451, 0.168627, 0.42)
const PAGE_ARROW_WIDTH := 6.0
const PAGE_ARROW_HEIGHT := 10.0
const PAGE_ARROW_GAP := 8.0
const BUTTON_COLOR_NAMES: Array[StringName] = [
	&"font_color",
	&"font_hover_color",
	&"font_pressed_color",
	&"font_focus_color",
	&"font_disabled_color",
]

var _source_root: Control
var _mirrors: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_source_root(source_root: Control) -> void:
	_source_root = source_root
	sync_now()


func sync_now() -> void:
	if _source_root == null or not is_instance_valid(_source_root):
		_clear_mirrors()
		return
	var sources: Array[Control] = []
	_collect_text_sources(_source_root, sources)
	var active_sources: Dictionary = {}
	for source: Control in sources:
		active_sources[source] = true
		var mirror := _mirrors.get(source) as Label
		if mirror == null or not is_instance_valid(mirror):
			mirror = _make_mirror(source)
			_mirrors[source] = mirror
		_sync_mirror(source, mirror)
	for source: Variant in _mirrors.keys():
		if not is_instance_valid(source) or not active_sources.has(source):
			var stale := _mirrors[source] as Label
			if stale != null and is_instance_valid(stale):
				stale.queue_free()
			_mirrors.erase(source)


func _process(_delta: float) -> void:
	sync_now()


func mirror_count() -> int:
	return _mirrors.size()


func mirror_for_source(source: Control) -> Label:
	return _mirrors.get(source) as Label


func _collect_text_sources(node: Node, result: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			var label := child as Label
			if label.visible and not label.text.is_empty():
				result.append(label)
		elif child is Button:
			var button := child as Button
			if button.visible and not button.text.is_empty():
				result.append(button)
		_collect_text_sources(child, result)


func _make_mirror(source: Control) -> Label:
	var mirror := Label.new()
	mirror.name = "Native_%s" % source.name
	mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(mirror)
	if _is_page_navigation_button(source):
		var arrow := Polygon2D.new()
		arrow.name = "NavArrow"
		mirror.add_child(arrow)
	if source is Button:
		_store_and_hide_button_text(source as Button)
	else:
		source.self_modulate.a = 0.0
	return mirror


func _sync_mirror(source: Control, mirror: Label) -> void:
	var source_transform := source.get_global_transform_with_canvas()
	var layer_inverse := get_global_transform_with_canvas().affine_inverse()
	var source_rect := _source_text_rect(source)
	var global_top_left := source_transform * source_rect.position
	var global_bottom_right := source_transform * source_rect.end
	var local_top_left := layer_inverse * global_top_left
	var local_bottom_right := layer_inverse * global_bottom_right
	var raw_size := (local_bottom_right - local_top_left).abs()
	var final_size := raw_size.round()
	var raw_center := (local_top_left + local_bottom_right) * 0.5
	mirror.size = final_size
	mirror.position = (raw_center - final_size * 0.5).round()
	mirror.text = _source_text(source)
	mirror.horizontal_alignment = _source_alignment(source)
	mirror.vertical_alignment = _source_vertical_alignment(source)
	mirror.autowrap_mode = _source_autowrap(source)
	mirror.text_overrun_behavior = _source_overrun(source)
	mirror.clip_text = _source_clip_text(source)
	mirror.add_theme_font_override("font", _source_font(source))
	var source_scale := source_transform.get_scale().abs()
	var final_scale := minf(source_scale.x, source_scale.y)
	var final_font_size := _final_font_size(source, final_scale)
	mirror.add_theme_font_size_override("font_size", final_font_size)
	var font_color := _source_font_color(source)
	mirror.add_theme_color_override("font_color", font_color)
	if _is_page_navigation_button(source):
		_sync_page_navigation_button(
				source as Button, mirror, raw_center, final_size, final_font_size, font_color)
	if _is_page_navigation_source(source):
		_clear_font_effects(mirror)
	else:
		_copy_font_effects(source, mirror, final_scale)
	if source.name == &"HeroName":
		mirror.position.x += HERO_NAME_OPTICAL_OFFSET_X
	mirror.visible = source.is_visible_in_tree()


func _sync_page_navigation_button(
		button: Button,
		mirror: Label,
		raw_center: Vector2,
		final_size: Vector2,
		font_size: int,
		font_color: Color) -> void:
	var text_width := ceilf(mirror.get_theme_font("font").get_string_size(
			mirror.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var group_width := PAGE_ARROW_WIDTH + PAGE_ARROW_GAP + text_width
	var group_left := roundf(raw_center.x - group_width * 0.5)
	mirror.size = Vector2(text_width, final_size.y)
	mirror.position.y = roundf(raw_center.y - final_size.y * 0.5)
	mirror.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mirror.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var arrow := mirror.get_node("NavArrow") as Polygon2D
	var arrow_y := roundf((mirror.size.y - PAGE_ARROW_HEIGHT) * 0.5)
	if button.name == &"PreviousPage":
		mirror.position.x = group_left + PAGE_ARROW_WIDTH + PAGE_ARROW_GAP
		arrow.position = Vector2(-PAGE_ARROW_WIDTH - PAGE_ARROW_GAP, arrow_y)
		arrow.polygon = PackedVector2Array([
			Vector2(PAGE_ARROW_WIDTH, 0.0),
			Vector2(0.0, PAGE_ARROW_HEIGHT * 0.5),
			Vector2(PAGE_ARROW_WIDTH, PAGE_ARROW_HEIGHT),
		])
	else:
		mirror.position.x = group_left
		arrow.position = Vector2(text_width + PAGE_ARROW_GAP, arrow_y)
		arrow.polygon = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(PAGE_ARROW_WIDTH, PAGE_ARROW_HEIGHT * 0.5),
			Vector2(0.0, PAGE_ARROW_HEIGHT),
		])
	arrow.color = font_color


func _source_text_rect(source: Control) -> Rect2:
	if not source is Button:
		return Rect2(Vector2.ZERO, source.size)
	if source.get_parent() != null and source.get_parent().name == &"PageNavigation":
		return Rect2(Vector2.ZERO, source.size)
	var button := source as Button
	var state := "disabled" if button.disabled else "normal"
	if not button.disabled and button.button_pressed:
		state = "pressed"
	elif not button.disabled and button.is_hovered():
		state = "hover"
	var style := button.get_theme_stylebox(state)
	if style == null:
		return Rect2(Vector2.ZERO, button.size)
	var top_left := Vector2(
			style.get_content_margin(SIDE_LEFT),
			style.get_content_margin(SIDE_TOP))
	var bottom_right := button.size - Vector2(
			style.get_content_margin(SIDE_RIGHT),
			style.get_content_margin(SIDE_BOTTOM))
	var content_size := bottom_right - top_left
	return Rect2(top_left, Vector2(maxf(content_size.x, 0.0), maxf(content_size.y, 0.0)))


func _is_page_navigation_source(source: Control) -> bool:
	return source.get_parent() != null and source.get_parent().name == &"PageNavigation"


func _is_page_navigation_button(source: Control) -> bool:
	return source is Button and _is_page_navigation_source(source)


func _source_text(source: Control) -> String:
	if source is Label:
		return (source as Label).text
	return (source as Button).text


func _source_alignment(source: Control) -> HorizontalAlignment:
	if source is Label:
		return (source as Label).horizontal_alignment
	return (source as Button).alignment


func _source_vertical_alignment(source: Control) -> VerticalAlignment:
	if source is Label:
		return (source as Label).vertical_alignment
	return VERTICAL_ALIGNMENT_CENTER


func _source_autowrap(source: Control) -> TextServer.AutowrapMode:
	if source is Label:
		return (source as Label).autowrap_mode
	return TextServer.AUTOWRAP_OFF


func _source_overrun(source: Control) -> TextServer.OverrunBehavior:
	if source is Label:
		return (source as Label).text_overrun_behavior
	return TextServer.OVERRUN_TRIM_ELLIPSIS


func _source_clip_text(source: Control) -> bool:
	if source is Label:
		return (source as Label).clip_text
	return (source as Button).clip_text


func _source_font(source: Control) -> Font:
	return source.get_theme_font("font")


func _source_font_size(source: Control) -> int:
	return source.get_theme_font_size("font_size")


func _final_font_size(source: Control, final_scale: float) -> int:
	if _is_page_navigation_source(source):
		return PAGE_NAVIGATION_FONT_SIZE
	return maxi(ceili(_source_font_size(source) * final_scale), MIN_BODY_FONT_SIZE)


func _source_font_color(source: Control) -> Color:
	if _is_page_navigation_source(source):
		if source is Button and (source as Button).disabled:
			return PAGE_NAVIGATION_DISABLED_COLOR
		return PAGE_NAVIGATION_COLOR
	if source is Label:
		return source.get_theme_color("font_color")
	var button := source as Button
	var colors: Dictionary = button.get_meta(&"codex_native_button_colors", {})
	if button.disabled:
		return colors.get(&"font_disabled_color", Color.WHITE)
	if button.button_pressed:
		return colors.get(&"font_pressed_color", Color.WHITE)
	if button.is_hovered():
		return colors.get(&"font_hover_color", Color.WHITE)
	return colors.get(&"font_color", Color.WHITE)


func _store_and_hide_button_text(button: Button) -> void:
	if not button.has_meta(&"codex_native_button_colors"):
		var colors: Dictionary = {}
		for color_name: StringName in BUTTON_COLOR_NAMES:
			colors[color_name] = button.get_theme_color(color_name)
		button.set_meta(&"codex_native_button_colors", colors)
	var transparent := Color(1.0, 1.0, 1.0, 0.0)
	for color_name: StringName in BUTTON_COLOR_NAMES:
		button.add_theme_color_override(color_name, transparent)


func _copy_font_effects(source: Control, mirror: Label, final_scale: float) -> void:
	for color_name: StringName in [&"font_outline_color", &"font_shadow_color"]:
		mirror.add_theme_color_override(color_name, source.get_theme_color(color_name))
	for constant_name: StringName in [
		&"outline_size", &"shadow_offset_x", &"shadow_offset_y", &"line_spacing",
	]:
		var value := source.get_theme_constant(constant_name)
		mirror.add_theme_constant_override(constant_name, roundi(value * final_scale))


func _clear_font_effects(mirror: Label) -> void:
	mirror.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	mirror.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	for constant_name: StringName in [
		&"outline_size", &"shadow_offset_x", &"shadow_offset_y",
	]:
		mirror.add_theme_constant_override(constant_name, 0)


func _clear_mirrors() -> void:
	for mirror: Variant in _mirrors.values():
		if is_instance_valid(mirror):
			(mirror as Label).queue_free()
	_mirrors.clear()

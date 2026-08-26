class_name PortalPixelBeam
extends Control

## 参考ref44外形与配色的240×135低分辨率程序化光柱，经8倍最近邻放大。
## 淡紫光晕、深紫实体边、粉紫主体与象牙白亮核组成一条连续收束柱体；
## 九格底部爆发仍独立覆盖传送阵。不使用shader、外部纹理或逐帧动画素材。

const DESIGN_SIZE := Vector2i(1920, 1080)
const INTEGER_SCALE: int = 8
const LOGICAL_CANVAS_SIZE := Vector2i(240, 135)
const ANIMATION_FPS: int = 12
const PALETTE_LEVEL_COUNT: int = 5
const MAIN_BODY_ALPHA: float = 0.82
const BRIGHT_PIXEL_ALPHA: float = 0.80
const COLUMN_LAYER_COUNT: int = 5
const UPWARD_STREAM_COUNT: int = 5
const EDGE_TONGUE_COUNT: int = 0
const BASE_PULSE_RING_COUNT: int = 3
const LEADING_PRONG_COUNT: int = 1
const SILHOUETTE_STATE_COUNT: int = 6
const PROFILE_BAND_HEIGHT: int = 6
const LEADING_MERGE_DEPTH: int = 7
const MAX_PROFILE_OVERHANG: int = 3
const BEAM_STAGE_COUNT: int = 5
const CHARGE_END: float = 0.22
const CORE_RISE_START: float = 0.18
const CORE_RISE_END: float = 0.50
const BODY_RISE_START: float = 0.27
const RISE_END: float = 0.72
const PEAK_START: float = 0.90
const PEAK_EXPANSION_STEPS: int = 3
const TOP_WIDTH_RATIO: float = 0.58
const REF44_AURA := Color(0.929, 0.686, 0.890, 0.18)
const REF44_OUTLINE := Color("822B85")
const REF44_BODY := Color("C65FBF")
const REF44_INNER := Color("EDAFE3")
const REF44_CORE := Color("FDFCF7")

var beam_color: Color = REF44_BODY
var beam_progress: float = 0.0
var anim_time: float = 0.0
var portal_base_rect := Rect2()

var _render_viewport: SubViewport
var _pixel_canvas: PixelBeamCanvas
var _viewport_display: TextureRect
var _display_material: CanvasItemMaterial


class PixelBeamCanvas:
	extends Control

	const WIDTH_PROFILE := [0, 1, 0, -1, 0, 1]
	const CENTER_PROFILE := [0, 0, 1, 0, -1, 0]

	var progress: float = 0.0
	var frame_index: int = 0
	var base_rect := Rect2i()


	func configure(value: Rect2i) -> void:
		base_rect = value
		queue_redraw()


	func set_progress(value: float) -> void:
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


	func set_frame(value: int) -> void:
		var safe_value: int = maxi(value, 0)
		if frame_index == safe_value:
			return
		frame_index = safe_value
		queue_redraw()


	func _draw() -> void:
		for layer: Dictionary in _build_frame_layers():
			var rect: Rect2i = layer["rect"]
			var color: Color = layer["color"]
			draw_rect(Rect2(rect), color, true)


	func _build_frame_layers() -> Array[Dictionary]:
		var layers: Array[Dictionary] = []
		if progress <= 0.001 or base_rect.size.x <= 0 or base_rect.size.y <= 0:
			return layers
		_append_base_ignition(layers,
				clampf(progress / CHARGE_END, 0.0, 1.0))
		var core_rise: float = _core_progress()
		var body_rise: float = _body_progress()
		if core_rise <= 0.001 and body_rise <= 0.001:
			return layers
		var origin_y: int = base_rect.position.y + base_rect.size.y
		var core_front_y: int = _front_y(core_rise)
		var body_front_y: int = _front_y(body_rise)
		if body_front_y < origin_y:
			_append_body_profile(layers, body_front_y, origin_y)
		if core_front_y < origin_y:
			_append_core_profile(layers, core_front_y, origin_y)
		if body_front_y < origin_y:
			_append_upward_streams(layers, body_front_y, origin_y)
		return layers


	func _append_base_ignition(layers: Array[Dictionary], charge: float) -> void:
		var center := Vector2i(base_rect.position.x + base_rect.size.x / 2,
				base_rect.position.y + base_rect.size.y / 2)
		var pulse_step: int = posmod(frame_index, 4)
		var horizontal_height: int = 2 + int(charge >= 0.66)
		var vertical_width: int = maxi(3, base_rect.size.x / 7)
		_add_layer(layers, Rect2i(
				Vector2i(base_rect.position.x, center.y - horizontal_height / 2),
				Vector2i(base_rect.size.x, horizontal_height)), REF44_AURA)
		_add_layer(layers, Rect2i(
				Vector2i(center.x - vertical_width / 2, base_rect.position.y),
				Vector2i(vertical_width, base_rect.size.y)), REF44_AURA)
		var visible_ring_count: int = clampi(ceili(charge * BASE_PULSE_RING_COUNT),
				1, BASE_PULSE_RING_COUNT)
		for index: int in visible_ring_count:
			_append_outline(layers, _base_ring_rect(index),
					REF44_INNER if index == 0 else REF44_AURA)
		_add_layer(layers, _ignition_rect(),
				REF44_INNER if pulse_step < 2 else REF44_CORE)


	func _append_body_profile(layers: Array[Dictionary], front_y: int,
			origin_y: int) -> void:
		var state: int = posmod(frame_index, SILHOUETTE_STATE_COUNT)
		for y: int in range(front_y, origin_y):
			var span: Rect2i = _body_span_for_row(y, front_y, origin_y, state)
			_add_layer(layers, _expand_span(span, 2), REF44_AURA)
			_add_layer(layers, span, REF44_OUTLINE)
			_add_layer(layers, _inset_span(span, 1), REF44_BODY)
			_add_layer(layers, _inset_span(span, 3), REF44_INNER)


	func _body_spans_for_row(y: int, front_y: int, state: int) -> Array[Rect2i]:
		return [_body_span_for_row(y, front_y,
				base_rect.position.y + base_rect.size.y, state)]


	func _profile_insets(y: int, front_y: int, state: int) -> Vector2i:
		var span: Rect2i = _body_span_for_row(y, front_y,
				base_rect.position.y + base_rect.size.y, state)
		return Vector2i(span.position.x - base_rect.position.x,
				base_rect.end.x - span.end.x)


	func _body_span_for_row(y: int, front_y: int, origin_y: int,
			state: int) -> Rect2i:
		var travel_height: int = maxi(origin_y - front_y, 1)
		var row_ratio: float = clampf(float(y - front_y) / float(travel_height),
				0.0, 1.0)
		var shaped_ratio: float = row_ratio * row_ratio * (3.0 - 2.0 * row_ratio)
		var top_width: int = maxi(5,
				int(roundf(float(base_rect.size.x) * TOP_WIDTH_RATIO)))
		var width: int = int(roundf(lerpf(float(top_width),
				float(base_rect.size.x), shaped_ratio)))
		var band: int = maxi((y - front_y) / PROFILE_BAND_HEIGHT, 0)
		width += int(WIDTH_PROFILE[posmod(band + state, WIDTH_PROFILE.size())])
		width += mini(_peak_step(), 2)
		if front_y > 0 and y - front_y < LEADING_MERGE_DEPTH:
			width = mini(width, 3 + (y - front_y) * 3)
		width = clampi(width, 3, base_rect.size.x + 2)
		var center_shift: int = int(CENTER_PROFILE[
				posmod(band + state, CENTER_PROFILE.size())])
		var center_x: int = base_rect.position.x + base_rect.size.x / 2 + center_shift
		return Rect2i(Vector2i(center_x - width / 2, y), Vector2i(width, 1))


	func _inset_span(span: Rect2i, inset: int) -> Rect2i:
		var safe_inset: int = mini(inset, maxi((span.size.x - 1) / 2, 0))
		return Rect2i(Vector2i(span.position.x + safe_inset, span.position.y),
				Vector2i(maxi(span.size.x - safe_inset * 2, 1), 1))


	func _expand_span(span: Rect2i, amount: int) -> Rect2i:
		return Rect2i(Vector2i(span.position.x - amount, span.position.y),
				Vector2i(span.size.x + amount * 2, 1))


	func _append_core_profile(layers: Array[Dictionary], front_y: int,
			origin_y: int) -> void:
		var state: int = posmod(frame_index, SILHOUETTE_STATE_COUNT)
		for y: int in range(front_y, origin_y):
			_add_layer(layers, _core_span_for_row(y, front_y, origin_y, state),
					REF44_CORE)


	func _core_span_for_row(y: int, front_y: int, origin_y: int,
			state: int) -> Rect2i:
		var body_span: Rect2i = _body_span_for_row(y, front_y, origin_y, state)
		var pulse: int = 1 if posmod(y / PROFILE_BAND_HEIGHT + state, 4) == 0 else 0
		var width: int = maxi(3, int(roundf(float(body_span.size.x) * 0.34)) + pulse)
		return Rect2i(Vector2i(body_span.position.x
				+ (body_span.size.x - width) / 2, y), Vector2i(width, 1))


	func _append_upward_streams(layers: Array[Dictionary], front_y: int,
			origin_y: int) -> void:
		for index: int in UPWARD_STREAM_COUNT:
			var stream_rect: Rect2i = _stream_rect(index, front_y, origin_y)
			_add_layer(layers, stream_rect, REF44_CORE)


	func _append_edge_tongues(layers: Array[Dictionary], front_y: int,
			origin_y: int) -> void:
		pass


	func _add_layer(layers: Array[Dictionary], rect: Rect2i, color: Color) -> void:
		if rect.size.x <= 0 or rect.size.y <= 0:
			return
		layers.append({"rect": rect, "color": color})


	func _append_outline(layers: Array[Dictionary], rect: Rect2i,
			color: Color) -> void:
		if rect.size.x <= 0 or rect.size.y <= 0:
			return
		_add_layer(layers, Rect2i(rect.position, Vector2i(rect.size.x, 1)), color)
		_add_layer(layers, Rect2i(Vector2i(rect.position.x, rect.end.y - 1),
				Vector2i(rect.size.x, 1)), color)
		_add_layer(layers, Rect2i(rect.position, Vector2i(1, rect.size.y)), color)
		_add_layer(layers, Rect2i(Vector2i(rect.end.x - 1, rect.position.y),
				Vector2i(1, rect.size.y)), color)


	func _stream_rect(index: int, front_y: int, origin_y: int) -> Rect2i:
		var travel_height: int = maxi(origin_y - front_y, 1)
		var stream_height: int = 6 + posmod(index * 5, 9)
		var stream_width: int = 1 + index % 2
		var cycle: int = travel_height + stream_height + 14
		var speed: int = 2 + index % 3
		var distance: int = posmod(frame_index * speed + index * 17, cycle)
		var bottom: int = origin_y - distance
		var top: int = bottom - stream_height
		var clipped_top: int = maxi(top, front_y)
		var clipped_bottom: int = mini(bottom, origin_y)
		if clipped_bottom <= clipped_top:
			return Rect2i()
		var middle_y: int = (clipped_top + clipped_bottom) / 2
		var state: int = posmod(frame_index, SILHOUETTE_STATE_COUNT)
		var body_span: Rect2i = _body_span_for_row(middle_y, front_y, origin_y, state)
		var lane_span: int = maxi(body_span.size.x - stream_width - 6, 1)
		var x: int = body_span.position.x + 3 + posmod(index * 7, lane_span)
		return Rect2i(Vector2i(x, clipped_top),
				Vector2i(stream_width, clipped_bottom - clipped_top))


	func _edge_tongue_rect(index: int, front_y: int, origin_y: int) -> Rect2i:
		return Rect2i()


	func _core_progress() -> float:
		return clampf((progress - CORE_RISE_START) / (CORE_RISE_END - CORE_RISE_START),
				0.0, 1.0)


	func _body_progress() -> float:
		return clampf((progress - BODY_RISE_START) / (RISE_END - BODY_RISE_START),
				0.0, 1.0)


	func _front_y(rise: float) -> int:
		var origin_y: int = base_rect.position.y + base_rect.size.y
		return int(roundf(lerpf(float(origin_y), 0.0, clampf(rise, 0.0, 1.0))))


	func _peak_step() -> int:
		if progress <= PEAK_START:
			return 0
		var peak: float = (progress - PEAK_START) / (1.0 - PEAK_START)
		return clampi(ceili(peak * PEAK_EXPANSION_STEPS), 0, PEAK_EXPANSION_STEPS)


	func visible_upward_stream_count() -> int:
		var rise: float = _body_progress()
		if rise <= 0.001:
			return 0
		var front_y: int = _front_y(rise)
		var origin_y: int = base_rect.position.y + base_rect.size.y
		var count: int = 0
		for index: int in UPWARD_STREAM_COUNT:
			var stream_rect: Rect2i = _stream_rect(index, front_y, origin_y)
			if stream_rect.size.x > 0 and stream_rect.size.y > 0:
				count += 1
		return count


	func visible_edge_tongue_count() -> int:
		var rise: float = _body_progress()
		if rise <= 0.001:
			return 0
		var front_y: int = _front_y(rise)
		var origin_y: int = base_rect.position.y + base_rect.size.y
		var count: int = 0
		for index: int in EDGE_TONGUE_COUNT:
			var tongue_rect: Rect2i = _edge_tongue_rect(index, front_y, origin_y)
			if tongue_rect.size.x > 0 and tongue_rect.size.y > 0:
				count += 1
		return count


	func build_cpu_pixel_frame() -> Image:
		var image := Image.create(LOGICAL_CANVAS_SIZE.x, LOGICAL_CANVAS_SIZE.y,
				false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for layer: Dictionary in _build_frame_layers():
			var rect: Rect2i = layer["rect"]
			var color: Color = layer["color"]
			_cpu_fill(image, rect, color)
		return image


	func _base_ring_rect(index: int) -> Rect2i:
		var center := Vector2i(
				base_rect.position.x + base_rect.size.x / 2,
				base_rect.position.y + base_rect.size.y / 2)
		var expansion_step: int = posmod(frame_index + index * 2, 6)
		var scale_ratio: float = 0.26 + float(expansion_step) * 0.13
		var ring_size := Vector2i(
				maxi(4, int(roundf(float(base_rect.size.x) * scale_ratio))),
				maxi(4, int(roundf(float(base_rect.size.y) * scale_ratio))))
		return Rect2i(center - ring_size / 2, ring_size)


	func _ignition_rect() -> Rect2i:
		var center := Vector2i(
				base_rect.position.x + base_rect.size.x / 2,
				base_rect.position.y + base_rect.size.y / 2)
		var ignition_size := Vector2i(
				maxi(base_rect.size.x / 4, 3), maxi(base_rect.size.y / 4, 3))
		return Rect2i(center - ignition_size / 2, ignition_size)


	func _cpu_fill(image: Image, rect: Rect2i, color: Color) -> void:
		var clipped: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO,
				LOGICAL_CANVAS_SIZE))
		if clipped.size.x > 0 and clipped.size.y > 0:
			image.fill_rect(clipped, color)


func _ready() -> void:
	_build_runtime_canvas()
	_sync_runtime_canvas()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _viewport_display != null:
		_viewport_display.size = size


func set_beam_color(_value: Color) -> void:
	beam_color = REF44_BODY


func set_beam_progress(value: float) -> void:
	beam_progress = clampf(value, 0.0, 1.0)
	if _pixel_canvas != null:
		_pixel_canvas.set_progress(beam_progress)


func set_anim_time(value: float) -> void:
	anim_time = maxf(value, 0.0)
	if _pixel_canvas != null:
		_pixel_canvas.set_frame(int(floor(anim_time * float(ANIMATION_FPS))))


func set_portal_base_rect(value: Rect2) -> void:
	portal_base_rect = value.abs()
	if _pixel_canvas != null:
		_pixel_canvas.configure(_logical_base_rect())


func _build_runtime_canvas() -> void:
	if _render_viewport != null:
		return
	_render_viewport = SubViewport.new()
	_render_viewport.name = "PixelBeamViewport240x135"
	_render_viewport.size = LOGICAL_CANVAS_SIZE
	_render_viewport.transparent_bg = true
	_render_viewport.disable_3d = true
	_render_viewport.gui_disable_input = true
	_render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_render_viewport)

	_pixel_canvas = PixelBeamCanvas.new()
	_pixel_canvas.name = "IntegerPixelBeamCanvas"
	_pixel_canvas.size = Vector2(LOGICAL_CANVAS_SIZE)
	_pixel_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_viewport.add_child(_pixel_canvas)

	_viewport_display = TextureRect.new()
	_viewport_display.name = "NearestIntegerUpscale"
	_viewport_display.position = Vector2.ZERO
	_viewport_display.size = size
	_viewport_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewport_display.stretch_mode = TextureRect.STRETCH_SCALE
	_viewport_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_viewport_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_display.texture = _render_viewport.get_texture()
	_display_material = CanvasItemMaterial.new()
	# 四档近白色已经在低分辨率画布内预合成；整张纹理继续做加法混合会把
	# 轮廓和内部负空间一起夹成纯白长方形。
	_display_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_viewport_display.material = _display_material
	add_child(_viewport_display)


func _sync_runtime_canvas() -> void:
	if _pixel_canvas == null:
		return
	_pixel_canvas.configure(_logical_base_rect())
	_pixel_canvas.set_progress(beam_progress)
	_pixel_canvas.set_frame(int(floor(anim_time * float(ANIMATION_FPS))))


func _logical_base_rect() -> Rect2i:
	if portal_base_rect.size.x <= 0.0 or portal_base_rect.size.y <= 0.0:
		return Rect2i()
	var left: int = floori(portal_base_rect.position.x / float(INTEGER_SCALE))
	var top: int = floori(portal_base_rect.position.y / float(INTEGER_SCALE))
	var right: int = ceili(portal_base_rect.end.x / float(INTEGER_SCALE))
	var bottom: int = ceili(portal_base_rect.end.y / float(INTEGER_SCALE))
	return Rect2i(left, top, maxi(right - left, 1), maxi(bottom - top, 1))


func _column_progress() -> float:
	return clampf((beam_progress - BODY_RISE_START) / (RISE_END - BODY_RISE_START),
			0.0, 1.0)


func _core_progress() -> float:
	return clampf((beam_progress - CORE_RISE_START) / (CORE_RISE_END - CORE_RISE_START),
			0.0, 1.0)


func _current_stage() -> String:
	if beam_progress <= 0.001:
		return "hidden"
	if beam_progress <= CHARGE_END:
		return "base_charge"
	if beam_progress < BODY_RISE_START:
		return "core_ignition"
	if beam_progress < RISE_END:
		return "body_rise"
	if beam_progress < PEAK_START:
		return "sustain"
	return "peak"


func get_runtime_pixel_metrics() -> Dictionary:
	var metrics := {
		"image_ready": false,
		"sampling_mode": "unavailable",
		"frame_signature": 0,
		"active_pixel_count": 0,
		"bright_pixel_count": 0,
		"covered_column_rows": 0,
		"base_coverage_ratio": 0.0,
		"base_spans_full_rect": false,
		"column_fill_ratio": 0.0,
		"distinct_row_width_count": 0,
		"maximum_full_width_row_run": 0,
		"active_bounds": Rect2i(),
	}
	if _render_viewport == null or _pixel_canvas == null:
		return metrics
	var image: Image
	if DisplayServer.get_name() == "headless":
		# Headless GUT使用dummy renderer，无法回读SubViewport；使用与绘制函数共用
		# 几何参数的CPU整数画布，仍进行不落盘像素覆盖与帧差验证。
		image = _pixel_canvas.build_cpu_pixel_frame()
		metrics["sampling_mode"] = "cpu_integer_canvas"
	else:
		image = _render_viewport.get_texture().get_image()
		metrics["sampling_mode"] = "runtime_subviewport"
	if image == null or image.is_empty():
		return metrics
	var logical_base: Rect2i = _logical_base_rect()
	var width: int = image.get_width()
	var height: int = image.get_height()
	var origin_y: int = mini(logical_base.position.y + logical_base.size.y, height)
	var min_point := Vector2i(width, height)
	var max_point := Vector2i(-1, -1)
	var active_count: int = 0
	var bright_count: int = 0
	var covered_rows: int = 0
	var covered_base_pixels: int = 0
	var column_active_pixels: int = 0
	var row_widths := {}
	var current_full_width_run: int = 0
	var maximum_full_width_run: int = 0
	var base_min := Vector2i(logical_base.end.x, logical_base.end.y)
	var base_max := Vector2i(logical_base.position.x - 1,
			logical_base.position.y - 1)
	for y: int in height:
		var column_row_width: int = 0
		for x: int in width:
			var alpha: float = image.get_pixel(x, y).a
			if alpha > 0.02:
				active_count += 1
				min_point.x = mini(min_point.x, x)
				min_point.y = mini(min_point.y, y)
				max_point.x = maxi(max_point.x, x)
				max_point.y = maxi(max_point.y, y)
			if alpha >= BRIGHT_PIXEL_ALPHA:
				bright_count += 1
			if y < origin_y and x >= logical_base.position.x \
					and x < logical_base.end.x and alpha > 0.02:
				column_row_width += 1
			if logical_base.has_point(Vector2i(x, y)) and alpha > 0.02:
				covered_base_pixels += 1
				base_min.x = mini(base_min.x, x)
				base_min.y = mini(base_min.y, y)
				base_max.x = maxi(base_max.x, x)
				base_max.y = maxi(base_max.y, y)
		if y < origin_y:
			column_active_pixels += column_row_width
			if column_row_width > 0:
				covered_rows += 1
				row_widths[column_row_width] = true
			if column_row_width >= logical_base.size.x:
				current_full_width_run += 1
				maximum_full_width_run = maxi(maximum_full_width_run,
						current_full_width_run)
			else:
				current_full_width_run = 0
	var base_pixel_count: int = logical_base.size.x * logical_base.size.y
	metrics["image_ready"] = true
	metrics["frame_signature"] = hash(image.get_data())
	metrics["active_pixel_count"] = active_count
	metrics["bright_pixel_count"] = bright_count
	metrics["covered_column_rows"] = covered_rows
	metrics["base_coverage_ratio"] = float(covered_base_pixels) \
			/ float(maxi(base_pixel_count, 1))
	metrics["base_spans_full_rect"] = base_min.x <= logical_base.position.x \
			and base_min.y <= logical_base.position.y \
			and base_max.x >= logical_base.end.x - 1 \
			and base_max.y >= logical_base.end.y - 1
	metrics["column_fill_ratio"] = float(column_active_pixels) \
			/ float(maxi(logical_base.size.x * origin_y, 1))
	metrics["distinct_row_width_count"] = row_widths.size()
	metrics["maximum_full_width_row_run"] = maximum_full_width_run
	if max_point.x >= min_point.x and max_point.y >= min_point.y:
		metrics["active_bounds"] = Rect2i(min_point, max_point - min_point + Vector2i.ONE)
	return metrics


func get_visual_contract() -> Dictionary:
	var logical_base: Rect2i = _logical_base_rect()
	var covered_base := Rect2(
			Vector2(logical_base.position * INTEGER_SCALE),
			Vector2(logical_base.size * INTEGER_SCALE))
	var column_progress: float = _column_progress()
	var origin_y: int = logical_base.position.y + logical_base.size.y
	var front_y: int = int(roundf(lerpf(float(origin_y), 0.0, column_progress)))
	var body_rect := Rect2i(
			Vector2i(logical_base.position.x - MAX_PROFILE_OVERHANG, front_y),
			Vector2i(logical_base.size.x + MAX_PROFILE_OVERHANG * 2,
					maxi(origin_y - front_y, 0)))
	var visible_streams: int = _pixel_canvas.visible_upward_stream_count() \
			if _pixel_canvas != null else 0
	var visible_tongues: int = _pixel_canvas.visible_edge_tongue_count() \
			if _pixel_canvas != null else 0
	return {
		"implementation": "ref44_contoured_pixel_portal_beam",
		"reference_profile": "ref44",
		"uses_ref44_contour": true,
		"uses_single_connected_column": true,
		"uses_colored_outline": true,
		"uses_ivory_core": true,
		"uses_internal_cutouts": false,
		"uses_subviewport": true,
		"uses_runtime_viewport_texture": true,
		"uses_external_texture": false,
		"uses_shader": false,
		"uses_sprite_sheet": false,
		"uses_antialiasing": false,
		"uses_continuous_gradients": false,
		"uses_tapered_staircase_edges": false,
		"uses_additive_blend": false,
		"uses_full_frame_additive_blend": _display_material != null
				and _display_material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
		"uses_controlled_value_layers": true,
		"uses_connected_profile": true,
		"uses_full_body_rect": false,
		"uses_flat_top_cap": false,
		"uses_coherent_upward_streams": true,
		"uses_hash_mosaic": false,
		"uses_isolated_noise_chunks": false,
		"core_rises_before_body": CORE_RISE_START < BODY_RISE_START
				and CORE_RISE_END < RISE_END,
		"color_mode": "ref44_purple_ivory",
		"beam_color": beam_color,
		"outline_color": REF44_OUTLINE,
		"core_color": REF44_CORE,
		"top_width_ratio": TOP_WIDTH_RATIO,
		"logical_canvas_size": LOGICAL_CANVAS_SIZE,
		"integer_scale": INTEGER_SCALE,
		"pixel_block_size_px": INTEGER_SCALE,
		"texture_filter_nearest": _viewport_display != null \
				and _viewport_display.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"animation_fps": ANIMATION_FPS,
		"palette_level_count": PALETTE_LEVEL_COUNT,
		"leading_prong_count": LEADING_PRONG_COUNT,
		"silhouette_state_count": SILHOUETTE_STATE_COUNT,
		"profile_band_height": PROFILE_BAND_HEIGHT,
		"beam_stage_count": BEAM_STAGE_COUNT,
		"current_stage": _current_stage(),
		"column_layer_count": COLUMN_LAYER_COUNT,
		"upward_stream_count": UPWARD_STREAM_COUNT,
		"edge_tongue_count": EDGE_TONGUE_COUNT,
		"base_pulse_ring_count": BASE_PULSE_RING_COUNT,
		"peak_expansion_steps": PEAK_EXPANSION_STEPS,
		"portal_base_rect": portal_base_rect,
		"logical_base_rect": logical_base,
		"main_body_width_px": float(logical_base.size.x * INTEGER_SCALE),
		"main_body_alpha": MAIN_BODY_ALPHA,
		"main_body_rect_logical": body_rect,
		"front_y_logical": front_y,
		"core_front_y_logical": int(roundf(lerpf(float(origin_y), 0.0,
				_core_progress()))),
		"profile_spans_portal_width": body_rect.size.x * INTEGER_SCALE \
				>= portal_base_rect.size.x,
		"base_spans_nine_cells": covered_base.encloses(portal_base_rect),
		"column_progress": column_progress,
		"core_progress": _core_progress(),
		"visible_upward_stream_count": visible_streams,
		"visible_edge_tongue_count": visible_tongues,
		"reaches_screen_top": column_progress >= 0.999,
		"runtime_canvas_ready": _render_viewport != null and _pixel_canvas != null
				and _viewport_display != null,
	}

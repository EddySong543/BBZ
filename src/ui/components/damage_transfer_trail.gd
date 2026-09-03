class_name DamageTransferTrail
extends Control

## H19 溢出伤害的单向弧形像素残波。
## 收束、飞行和命中使用三套不同轮廓，避免同一条带状物在首尾形成虫体感。

# 整体保持黑色观感；窄内芯只留极低亮度的暗绛色，避免在暗场中吞掉弧度。
const RIBBON_OUTLINE: Color = Color("08060a")
const RIBBON_BODY: Color = Color("1a0d13")
const RIBBON_CORE: Color = Color("4b202a")
const RIBBON_SAMPLES: int = 17
const GATHER_ARC_COUNT: int = 3
const IMPACT_FRAGMENT_COUNT: int = 2
const SOURCE_GATHER_SPAN: float = 0.026
const TRAVEL_TAIL_SPAN: float = 0.18

var start_point: Vector2 = Vector2.ZERO
var end_point: Vector2 = Vector2.ZERO
var gather_progress: float = 0.0:
	set(value):
		gather_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var impact_progress: float = 0.0:
	set(value):
		impact_progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func configure(from_point: Vector2, to_point: Vector2) -> void:
	start_point = from_point.round()
	end_point = to_point.round()
	gather_progress = 0.0
	progress = 0.0
	impact_progress = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func point_at(t: float) -> Vector2:
	var clamped_t := clampf(t, 0.0, 1.0)
	var distance := start_point.distance_to(end_point)
	var lift := clampf(distance * 0.105, 78.0, 124.0)
	var control_a := start_point.lerp(end_point, 0.28) + Vector2(0.0, -lift)
	var control_b := start_point.lerp(end_point, 0.72) + Vector2(0.0, -lift)
	var inv := 1.0 - clamped_t
	return (inv * inv * inv * start_point
		+ 3.0 * inv * inv * clamped_t * control_a
		+ 3.0 * inv * clamped_t * clamped_t * control_b
		+ clamped_t * clamped_t * clamped_t * end_point).round()


func debug_visual_kind() -> StringName:
	return &"condensed_arc_wave"


func debug_gather_arc_count() -> int:
	return GATHER_ARC_COUNT


func debug_gather_radii() -> Array[float]:
	var radii: Array[float] = []
	for index: int in GATHER_ARC_COUNT:
		radii.append(_gather_arc_radius(index))
	return radii


func debug_has_full_length_core() -> bool:
	return false


func debug_tail_sliver_count() -> int:
	return 0


func debug_width_at_ratio(ratio: float) -> float:
	return _ribbon_width_profile(ratio)


func debug_impact_fragment_count() -> int:
	return IMPACT_FRAGMENT_COUNT if impact_progress > 0.0 else 0


func debug_impact_fragment_points() -> Array[PackedVector2Array]:
	if impact_progress <= 0.0:
		return []
	return [
		_impact_fragment_points(-1.0),
		_impact_fragment_points(1.0),
	]


func debug_travel_hidden_during_impact() -> bool:
	return impact_progress > 0.0


func debug_uses_square_blocks() -> bool:
	return false


func debug_source_gather_visible() -> bool:
	return gather_progress > 0.0 and progress <= 0.0


func debug_visible_segment_count() -> int:
	if gather_progress <= 0.0 and progress <= 0.0 and impact_progress <= 0.0:
		return 0
	return RIBBON_SAMPLES - 1


func debug_visible_head_t() -> float:
	return _visible_head_t()


func debug_palette() -> Array[Color]:
	return [RIBBON_OUTLINE, RIBBON_BODY, RIBBON_CORE]


func _draw() -> void:
	if impact_progress > 0.0:
		_draw_impact_split()
		return
	if progress > 0.0:
		_draw_travel_wave()
		return
	if gather_progress > 0.0:
		_draw_source_gather()


func _draw_source_gather() -> void:
	var eased: float = sin(gather_progress * PI * 0.5)
	var forward: Vector2 = (point_at(0.018) - start_point).normalized()
	if forward.is_zero_approx():
		forward = Vector2.RIGHT
	var backward_angle: float = forward.angle() + PI
	for index: int in GATHER_ARC_COUNT:
		var index_ratio: float = float(index) / float(GATHER_ARC_COUNT - 1)
		var radius: float = _gather_arc_radius(index)
		var angle_offset: float = lerpf(-0.16, 0.16, index_ratio)
		var half_span: float = lerpf(0.48, 0.68, eased)
		var color: Color = RIBBON_BODY if index != 1 else RIBBON_CORE
		var alpha: float = lerpf(0.34, 0.90, eased) * (0.82 + 0.09 * float(index))
		_draw_pixel_arc(
			start_point,
			radius,
			backward_angle + angle_offset - half_span,
			backward_angle + angle_offset + half_span,
			6,
			Color(color, alpha),
			2.0 + float(index == 1)
		)


func _gather_arc_radius(index: int) -> float:
	var eased: float = sin(gather_progress * PI * 0.5)
	var start_radius: float = 34.0 + 10.0 * float(index)
	var end_radius: float = 7.0 + 3.0 * float(index)
	return lerpf(start_radius, end_radius, eased)


func _draw_pixel_arc(center: Vector2, radius: float, start_angle: float,
		end_angle: float, segments: int, color: Color, width: float) -> void:
	var previous: Vector2 = (center + Vector2.from_angle(start_angle) * radius).round()
	for segment: int in segments:
		var ratio: float = float(segment + 1) / float(segments)
		var angle: float = lerpf(start_angle, end_angle, ratio)
		var current: Vector2 = (center + Vector2.from_angle(angle) * radius).round()
		if not previous.is_equal_approx(current):
			draw_line(previous, current, color, width, false)
		previous = current


func _draw_travel_wave() -> void:
	var to_t: float = _visible_head_t()
	var from_t: float = maxf(0.0, to_t - TRAVEL_TAIL_SPAN)
	_draw_ribbon_pass(from_t, to_t, 1.0, 2.0, Color(RIBBON_OUTLINE, 0.94))
	_draw_ribbon_pass(from_t, to_t, 0.66, 0.0, Color(RIBBON_BODY, 0.96))
	_draw_short_outer_edge(from_t, to_t)


func _draw_short_outer_edge(from_t: float, to_t: float) -> void:
	var previous: Vector2 = Vector2.ZERO
	var has_previous: bool = false
	for index: int in 5:
		var local_ratio: float = lerpf(0.62, 0.90, float(index) / 4.0)
		var t: float = lerpf(from_t, to_t, local_ratio)
		var before: Vector2 = point_at(maxf(0.0, t - 0.003))
		var after: Vector2 = point_at(minf(1.0, t + 0.003))
		var tangent: Vector2 = (after - before).normalized()
		if tangent.is_zero_approx():
			continue
		var normal := Vector2(-tangent.y, tangent.x)
		var edge_offset: float = _ribbon_width_profile(local_ratio) * 0.30
		var current: Vector2 = (point_at(t) - normal * edge_offset).round()
		if has_previous and not previous.is_equal_approx(current):
			draw_line(previous, current, Color(RIBBON_CORE, 0.34), 2.0, false)
		previous = current
		has_previous = true


func _draw_impact_split() -> void:
	var fade: float = 1.0 - smoothstep(0.46, 1.0, impact_progress)
	for side: float in [-1.0, 1.0]:
		var points: PackedVector2Array = _impact_fragment_points(side)
		draw_polyline(points, Color(RIBBON_OUTLINE, fade * 0.90), 6.0, false)
		draw_polyline(points, Color(RIBBON_BODY, fade * 0.96), 3.0, false)
		var edge_start: Vector2 = points[1]
		var edge_end: Vector2 = points[2]
		draw_line(edge_start, edge_end, Color(RIBBON_CORE, fade * 0.30), 1.0, false)


func _impact_fragment_points(side: float) -> PackedVector2Array:
	var eased: float = 1.0 - pow(1.0 - impact_progress, 2.0)
	var tangent: Vector2 = (end_point - point_at(0.98)).normalized()
	if tangent.is_zero_approx():
		tangent = Vector2.RIGHT
	var normal := Vector2(-tangent.y, tangent.x)
	var separation: float = lerpf(2.0, 17.0, eased)
	var advance: float = lerpf(0.0, 10.0, eased)
	return PackedVector2Array([
		(end_point - tangent * (13.0 - advance * 0.25)
			+ normal * side * (2.0 + separation * 0.28)).round(),
		(end_point - tangent * 2.0
			+ normal * side * (5.0 + separation * 0.72)).round(),
		(end_point + tangent * (7.0 + advance)
			+ normal * side * (4.0 + separation)).round(),
	])


func _ribbon_width_profile(ratio: float) -> float:
	var clamped_ratio: float = clampf(ratio, 0.0, 1.0)
	if clamped_ratio <= 0.68:
		var rise: float = clamped_ratio / 0.68
		return lerpf(1.2, 11.2, sin(rise * PI * 0.5))
	var fall: float = (clamped_ratio - 0.68) / 0.32
	return lerpf(11.2, 2.4, smoothstep(0.0, 1.0, fall))


func _visible_head_t() -> float:
	if progress <= 0.0:
		return SOURCE_GATHER_SPAN
	# 飞行从收束后的短弧面继续，不闪空，也不重复生成上一段残波。
	return lerpf(SOURCE_GATHER_SPAN, 1.0, progress)


func _draw_ribbon_pass(from_t: float, to_t: float, width_scale: float,
		extra_width: float, color: Color) -> void:
	var previous := point_at(from_t)
	for index: int in RIBBON_SAMPLES - 1:
		var ratio := float(index + 1) / float(RIBBON_SAMPLES - 1)
		var t := lerpf(from_t, to_t, ratio)
		var current := point_at(t)
		var width_profile: float = _ribbon_width_profile(ratio)
		var width := maxf(1.0, width_profile * width_scale + extra_width)
		if not previous.is_equal_approx(current):
			draw_line(previous, current, color, width, false)
		previous = current

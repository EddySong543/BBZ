class_name GridRoutePreview
extends RefCounted

const FOOTPRINT_SPACING_CELLS: float = 0.34
const STREAM_SPEED_CELLS_PER_SECOND: float = 0.32
const TURN_RADIUS_CELLS: float = 0.16
const TURN_SAMPLES: int = 5
const SOLE_LENGTH_CELLS: float = 0.20
const SOLE_WIDTH_CELLS: float = 0.092
const SIDE_OFFSET_CELLS: float = 0.082
const ENDPOINT_FADE_CELLS: float = 0.18
const MIN_START_OPACITY: float = 0.36
const MIN_END_OPACITY: float = 0.22
const BASE_OPACITY: float = 0.72
const TRAIL_COLOR := Color("FFD34E")

## 交替脚印按固定最大间距覆盖整条路线，并沿路径距离持续向目标平移。
## 脚印数量随路线长度增加，每枚到达终点后独立回到起点；左右脚相对路线
## 切线错位，端点只做轻微透明度渐隐。这里不绘制逐个闪烁、阴影、亮核、
## 光晕、箭头、虚线、节点或路径带。


static func build_route_curve(cells: Array[Vector2i],
		cell_size: float) -> PackedVector2Array:
	var curve := PackedVector2Array()
	if cells.is_empty() or cell_size <= 0.0:
		return curve
	var centers := PackedVector2Array()
	for cell: Vector2i in cells:
		centers.append((Vector2(cell) + Vector2.ONE * 0.5) * cell_size)
	curve.append(centers[0])
	if centers.size() == 1:
		return curve
	var preferred_radius: float = cell_size * TURN_RADIUS_CELLS
	for index: int in range(1, centers.size() - 1):
		var previous: Vector2 = centers[index - 1]
		var center: Vector2 = centers[index]
		var following: Vector2 = centers[index + 1]
		var incoming: Vector2 = (center - previous).normalized()
		var outgoing: Vector2 = (following - center).normalized()
		if incoming.is_equal_approx(outgoing):
			curve.append(center)
			continue
		var radius: float = minf(preferred_radius,
				minf(previous.distance_to(center), center.distance_to(following)) * 0.25)
		var entry: Vector2 = center - incoming * radius
		var exit: Vector2 = center + outgoing * radius
		curve.append(entry)
		for sample_index: int in range(1, TURN_SAMPLES + 1):
			var weight: float = float(sample_index) / float(TURN_SAMPLES)
			var inverse: float = 1.0 - weight
			curve.append(inverse * inverse * entry
					+ 2.0 * inverse * weight * center
					+ weight * weight * exit)
	curve.append(centers[centers.size() - 1])
	return curve


static func sample_curve(curve: PackedVector2Array, distance: float) -> Dictionary:
	if curve.size() < 2:
		return {
			"position": curve[0] if curve.size() == 1 else Vector2.ZERO,
			"tangent": Vector2.RIGHT,
		}
	var remaining: float = maxf(distance, 0.0)
	for index: int in curve.size() - 1:
		var start: Vector2 = curve[index]
		var finish: Vector2 = curve[index + 1]
		var segment: Vector2 = finish - start
		var segment_length: float = segment.length()
		if segment_length <= 0.001:
			continue
		var tangent: Vector2 = segment / segment_length
		if remaining <= segment_length:
			return {
				"position": start + tangent * remaining,
				"tangent": tangent,
			}
		remaining -= segment_length
	var tail: Vector2 = curve[curve.size() - 1] - curve[curve.size() - 2]
	return {
		"position": curve[curve.size() - 1],
		"tangent": tail.normalized() if tail.length_squared() > 0.0001 \
				else Vector2.RIGHT,
	}


static func build_stream_footprints(cells: Array[Vector2i], cell_size: float,
		anim_time: float) -> Array[Dictionary]:
	var footprints: Array[Dictionary] = []
	var curve: PackedVector2Array = build_route_curve(cells, cell_size)
	if curve.size() < 2:
		return footprints
	var total_length: float = _curve_length(curve)
	if total_length <= 0.001:
		return footprints
	var target_spacing: float = cell_size * FOOTPRINT_SPACING_CELLS
	var footprint_count: int = maxi(2, ceili(total_length / target_spacing))
	if footprint_count % 2 != 0:
		footprint_count += 1
	var actual_spacing: float = total_length / float(footprint_count)
	var speed: float = cell_size * STREAM_SPEED_CELLS_PER_SECOND
	var phase_distance: float = fposmod(maxf(anim_time, 0.0) * speed,
			total_length)
	var side_offset: float = cell_size * SIDE_OFFSET_CELLS
	var endpoint_fade: float = cell_size * ENDPOINT_FADE_CELLS
	for stream_index: int in footprint_count:
		var path_distance: float = fposmod(
				float(stream_index) * actual_spacing + phase_distance,
				total_length)
		var sample: Dictionary = sample_curve(curve, path_distance)
		var path_position := Vector2(sample["position"])
		var direction := Vector2(sample["tangent"]).normalized()
		var normal := Vector2(-direction.y, direction.x)
		var side: String = "left" if stream_index % 2 == 0 else "right"
		var side_sign: float = -1.0 if side == "left" else 1.0
		var center: Vector2 = path_position + normal * side_offset * side_sign
		var start_opacity: float = lerpf(MIN_START_OPACITY, 1.0,
				smoothstep(0.0, endpoint_fade, path_distance))
		var end_opacity: float = lerpf(MIN_END_OPACITY, 1.0,
				smoothstep(0.0, endpoint_fade, total_length - path_distance))
		var endpoint_opacity: float = start_opacity * end_opacity
		footprints.append({
			"stream_index": stream_index,
			"side": side,
			"path_distance": path_distance,
			"actual_spacing": actual_spacing,
			"path_position": path_position,
			"center": center,
			"direction": direction,
			"base_opacity": BASE_OPACITY,
			"opacity": BASE_OPACITY * endpoint_opacity,
			"parts": build_sole_parts(center, direction,
					cell_size * SOLE_LENGTH_CELLS,
					cell_size * SOLE_WIDTH_CELLS),
		})
	return footprints


static func build_sole_parts(center: Vector2, direction: Vector2,
		length: float, width: float) -> Array[PackedVector2Array]:
	var parts: Array[PackedVector2Array] = []
	if direction.length_squared() <= 0.0001:
		return parts
	var forward: Vector2 = direction.normalized()
	var normal := Vector2(-forward.y, forward.x)
	var safe_length: float = maxf(length, 8.0)
	var safe_width: float = maxf(width, 4.0)
	var forefoot_length: float = safe_length * 0.56
	var heel_length: float = safe_length * 0.27
	var forefoot_center: Vector2 = center + forward * safe_length * 0.22
	var heel_center: Vector2 = center - forward * safe_length * 0.36
	var forefoot_front: Vector2 = forefoot_center + forward * forefoot_length * 0.5
	var forefoot_middle: Vector2 = forefoot_center + forward * forefoot_length * 0.08
	var forefoot_back: Vector2 = forefoot_center - forward * forefoot_length * 0.5
	var forefoot_half_width: float = safe_width * 0.5
	var forefoot := PackedVector2Array([
		forefoot_front + normal * forefoot_half_width * 0.38,
		forefoot_middle + normal * forefoot_half_width,
		forefoot_back + normal * forefoot_half_width * 0.78,
		forefoot_back - normal * forefoot_half_width * 0.78,
		forefoot_middle - normal * forefoot_half_width,
		forefoot_front - normal * forefoot_half_width * 0.38,
	])
	var heel_half_width: float = safe_width * 0.31
	var heel_front: Vector2 = heel_center + forward * heel_length * 0.5
	var heel_back: Vector2 = heel_center - forward * heel_length * 0.5
	var heel := PackedVector2Array([
		heel_front + normal * heel_half_width,
		heel_back + normal * heel_half_width,
		heel_back - normal * heel_half_width,
		heel_front - normal * heel_half_width,
	])
	parts.append(forefoot)
	parts.append(heel)
	return parts


static func draw_preview(canvas: CanvasItem, cells: Array[Vector2i],
		cell_size: float, anim_time: float) -> void:
	if canvas == null:
		return
	for footprint: Dictionary in build_stream_footprints(cells, cell_size, anim_time):
		var opacity: float = float(footprint["opacity"])
		if opacity <= 0.001:
			continue
		var parts: Array[PackedVector2Array] = footprint["parts"]
		for part: PackedVector2Array in parts:
			var pixel_part := PackedVector2Array()
			for point: Vector2 in part:
				pixel_part.append(point.round())
			canvas.draw_colored_polygon(pixel_part, Color(TRAIL_COLOR, opacity))


static func _curve_length(curve: PackedVector2Array) -> float:
	var total_length: float = 0.0
	for index: int in curve.size() - 1:
		total_length += curve[index].distance_to(curve[index + 1])
	return total_length


static func get_style_contract() -> Dictionary:
	return {
		"implementation": "full_route_alternating_footprint_stream",
		"uses_footprints": true,
		"alternates_left_right": true,
		"covers_full_route": true,
		"count_scales_with_route_length": true,
		"uses_fixed_visible_count": false,
		"uses_footprint_count_cap": false,
		"moves_continuously_forward": true,
		"uses_distance_sampling": true,
		"uses_smoothed_turn_tangents": true,
		"uses_endpoint_fade": true,
		"uses_loop_gap": false,
		"uses_uniform_base_opacity": true,
		"fills_every_path_cell": false,
		"fills_every_path_cell_with_pair": false,
		"lights_individual_footprints": false,
		"uses_two_part_sole": true,
		"uses_toe_details": false,
		"uses_ground_shadow": false,
		"uses_inner_core": false,
		"uses_glow": false,
		"uses_inset_edge_bars": false,
		"uses_arrows": false,
		"uses_chevrons": false,
		"uses_continuous_ribbon": false,
		"uses_dashes": false,
		"uses_nodes": false,
		"footprint_spacing_cells": FOOTPRINT_SPACING_CELLS,
		"stream_speed_cells_per_second": STREAM_SPEED_CELLS_PER_SECOND,
		"uses_external_texture": false,
		"uses_shader": false,
		"uses_sprite_sheet": false,
	}

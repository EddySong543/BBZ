class_name GridRoutePreview
extends RefCounted

## 把四方向格路径转换为规整点列：直线保持笔直，拐角只做紧凑圆角。
## 标记相位可逐帧向终点推进，仅改变展示，不改变寻路结果。


static func build_curve(cells: Array[Vector2i], cell_size: float,
		corner_radius: float = 12.0, corner_samples: int = 4) -> PackedVector2Array:
	var curve := PackedVector2Array()
	if cells.is_empty():
		return curve
	var centers: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in cells:
		centers.append((Vector2(cell) + Vector2.ONE * 0.5) * cell_size)
	curve.append(centers[0])
	var safe_radius: float = clampf(corner_radius, 0.0, cell_size * 0.25)
	var samples: int = maxi(corner_samples, 2)
	for index: int in range(1, centers.size() - 1):
		var center: Vector2 = centers[index]
		var incoming: Vector2 = (center - centers[index - 1]).normalized()
		var outgoing: Vector2 = (centers[index + 1] - center).normalized()
		if incoming.is_equal_approx(outgoing):
			curve.append(center)
			continue
		var entry: Vector2 = center - incoming * safe_radius
		var exit: Vector2 = center + outgoing * safe_radius
		curve.append(entry)
		for sample: int in range(1, samples + 1):
			var t: float = float(sample) / float(samples)
			var inverse: float = 1.0 - t
			curve.append(inverse * inverse * entry
					+ 2.0 * inverse * t * center + t * t * exit)
	curve.append(centers[centers.size() - 1])
	return curve


static func build_markers(curve: PackedVector2Array, spacing: float,
		phase: float, marker_length: float) -> Array[PackedVector2Array]:
	var markers: Array[PackedVector2Array] = []
	if curve.size() < 2:
		return markers
	var safe_spacing: float = maxf(spacing, 2.0)
	var safe_length: float = clampf(marker_length, 2.0, safe_spacing * 0.72)
	var total_length: float = 0.0
	for index: int in curve.size() - 1:
		total_length += curve[index].distance_to(curve[index + 1])
	var distance: float = fposmod(phase, safe_spacing) + safe_length * 0.5
	while distance <= total_length - safe_length * 0.5:
		var sample: Dictionary = _sample_curve(curve, distance)
		var center := Vector2(sample["position"])
		var tangent := Vector2(sample["tangent"])
		markers.append(PackedVector2Array([
			center - tangent * safe_length * 0.5,
			center + tangent * safe_length * 0.5,
		]))
		distance += safe_spacing
	return markers


static func _sample_curve(curve: PackedVector2Array, distance: float) -> Dictionary:
	var remaining: float = maxf(distance, 0.0)
	for index: int in curve.size() - 1:
		var start: Vector2 = curve[index]
		var finish: Vector2 = curve[index + 1]
		var segment: Vector2 = finish - start
		var length: float = segment.length()
		if length <= 0.001:
			continue
		if remaining <= length:
			var tangent: Vector2 = segment / length
			return {
				"position": start + tangent * remaining,
				"tangent": tangent,
			}
		remaining -= length
	var tail: Vector2 = curve[curve.size() - 1] - curve[curve.size() - 2]
	return {
		"position": curve[curve.size() - 1],
		"tangent": tail.normalized(),
	}

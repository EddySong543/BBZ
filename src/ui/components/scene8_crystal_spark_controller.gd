extends Node

const LEFT_PATH := NodePath("../ForegroundLeft")
const RIGHT_PATH := NodePath("../ForegroundRight")
const DESIGN_VIEWPORT_RECT := Rect2(0.0, 0.0, 1920.0, 1080.0)
const LEFT_ELLIPSES: Array[Vector4] = [
	Vector4(55.0, 42.0, 31.0, 42.0),
	Vector4(82.0, 111.0, 32.0, 54.0),
	Vector4(143.0, 137.0, 16.0, 25.0),
	Vector4(202.0, 174.0, 13.0, 18.0),
]
const RIGHT_ELLIPSES: Array[Vector4] = [
	Vector4(253.0, 58.0, 35.0, 58.0),
	Vector4(158.0, 128.0, 34.0, 43.0),
]
# Source-texture polygons registered from the red outlines in res/left.png and
# res/right.png. They are applied after connectivity is resolved so a marked
# snow cap cannot sever and discard an otherwise valid crystal body.
const CRYSTAL_ANNOTATION_EXCLUSION_POLYGONS: Array[Array] = [
	[
		Vector2(43.61, 53.60), Vector2(56.37, 60.04), Vector2(63.36, 64.48),
		Vector2(64.59, 65.28), Vector2(66.65, 66.90), Vector2(67.89, 68.10),
		Vector2(69.53, 70.52), Vector2(71.18, 73.75), Vector2(71.18, 79.79),
		Vector2(70.77, 81.00), Vector2(67.47, 85.84), Vector2(67.06, 86.24),
		Vector2(66.24, 86.64), Vector2(65.83, 86.64), Vector2(62.13, 86.24),
		Vector2(59.66, 85.03), Vector2(43.61, 75.36),
	],
	[
		Vector2(58.42, 121.30), Vector2(58.83, 115.66), Vector2(59.25, 114.45),
		Vector2(59.66, 113.64), Vector2(60.07, 113.24), Vector2(61.30, 112.84),
		Vector2(63.77, 112.84), Vector2(65.42, 113.64), Vector2(97.10, 143.46),
		Vector2(97.92, 144.27), Vector2(100.39, 147.49), Vector2(101.62, 149.91),
		Vector2(102.86, 152.73), Vector2(103.27, 153.94), Vector2(103.27, 157.57),
		Vector2(102.86, 158.78), Vector2(101.21, 160.39), Vector2(99.98, 160.79),
		Vector2(95.04, 160.79), Vector2(83.93, 157.57), Vector2(82.70, 157.16),
		Vector2(79.82, 155.96), Vector2(76.53, 154.34), Vector2(74.06, 152.73),
		Vector2(70.35, 149.10), Vector2(67.89, 146.28), Vector2(67.06, 145.07),
		Vector2(62.95, 137.42), Vector2(61.30, 134.19), Vector2(60.07, 130.97),
		Vector2(59.25, 128.55), Vector2(58.42, 124.52),
	],
	[],
	[],
	[
		Vector2(221.78, 88.76), Vector2(222.18, 88.00), Vector2(222.58, 87.62),
		Vector2(229.36, 82.67), Vector2(230.16, 82.29), Vector2(230.56, 82.29),
		Vector2(231.76, 100.57), Vector2(231.76, 100.95), Vector2(229.36, 99.81),
		Vector2(226.97, 98.29), Vector2(225.37, 97.14), Vector2(223.78, 95.62),
		Vector2(222.18, 93.71), Vector2(221.78, 92.57),
	],
	[
		Vector2(141.61, 170.29), Vector2(142.40, 167.62), Vector2(142.80, 166.86),
		Vector2(145.20, 163.43), Vector2(146.39, 162.29), Vector2(147.19, 161.90),
		Vector2(151.18, 160.38), Vector2(152.78, 160.00), Vector2(154.77, 159.62),
		Vector2(160.75, 159.62), Vector2(167.53, 160.00), Vector2(170.33, 160.38),
		Vector2(171.52, 160.76), Vector2(173.92, 161.90), Vector2(174.32, 162.29),
		Vector2(174.32, 165.33), Vector2(173.92, 166.10), Vector2(172.72, 168.00),
		Vector2(171.92, 169.14), Vector2(169.53, 172.19), Vector2(166.34, 175.24),
		Vector2(165.54, 175.62), Vector2(163.94, 176.00), Vector2(155.17, 176.00),
		Vector2(144.40, 174.86), Vector2(143.20, 174.48), Vector2(142.40, 174.10),
		Vector2(141.61, 173.33),
	],
]
const RIGHT2_EDGE_ANNOTATION_EXCLUSION_POLYGON: Array[Vector2] = [
	Vector2(232.9530, 80.0000),
	Vector2(232.1552, 81.1429),
	Vector2(231.7563, 82.2857),
	Vector2(230.9585, 84.9524),
	Vector2(230.5596, 86.8571),
	Vector2(230.5596, 90.6667),
	Vector2(230.9585, 94.0952),
	Vector2(231.3574, 95.6190),
	Vector2(231.7563, 97.5238),
	Vector2(232.1552, 99.0476),
	Vector2(232.5541, 100.5714),
	Vector2(233.3519, 102.0952),
	Vector2(233.3519, 104.0000),
	Vector2(233.7508, 104.3810),
	Vector2(233.7508, 79.6190),
]
const FACET_DIRECTIONS: Array[Vector2] = [
	Vector2(-0.36, -0.93),
	Vector2(-0.18, -0.98),
	Vector2(0.13, -0.99),
	Vector2(0.38, -0.92),
	Vector2(0.27, -0.96),
	Vector2(-0.48, -0.88),
]
const FACET_ALTERNATE_DIRECTIONS: Array[Vector2] = [
	Vector2(0.56, -0.83),
	Vector2(0.64, -0.77),
	Vector2(-0.52, -0.85),
	Vector2(-0.61, -0.79),
	Vector2(-0.58, -0.82),
	Vector2(0.52, -0.85),
]
const CORE_COLOR := Color(0.91, 1.0, 1.0, 1.0)
const CYAN_COLOR := Color(0.42, 0.96, 0.94, 1.0)
const GREEN_ACCENT := Color(0.48, 1.0, 0.72, 1.0)
const VIOLET_ACCENT := Color(0.72, 0.67, 1.0, 1.0)

@export_range(0.4, 1.0, 0.01) var response_lifetime_sec: float = 0.64
@export_range(2, 4, 1) var shard_count: int = 3
@export_range(16.0, 28.0, 1.0) var minimum_facet_length_px: float = 20.0
@export_range(32.0, 56.0, 1.0) var maximum_facet_length_px: float = 44.0

var _crystals: Array[Dictionary] = []


class CrystalFacetResponse:
	extends Node2D

	var lifetime_sec: float = 0.64
	var elapsed_sec: float = 0.0
	var facet_start: Vector2 = Vector2(-12.0, 5.0)
	var facet_end: Vector2 = Vector2(18.0, -8.0)
	var shard_directions: Array[Vector2] = []
	var shard_lengths: Array[float] = []
	var core_color: Color = Color.WHITE
	var facet_color: Color = Color.WHITE
	var accent_color: Color = Color.WHITE


	func configure(
			configured_lifetime: float,
			configured_start: Vector2,
			configured_end: Vector2,
			configured_shard_directions: Array[Vector2],
			configured_shard_lengths: Array[float],
			configured_core_color: Color,
			configured_facet_color: Color,
			configured_accent_color: Color) -> void:
		lifetime_sec = configured_lifetime
		facet_start = configured_start
		facet_end = configured_end
		shard_directions = configured_shard_directions
		shard_lengths = configured_shard_lengths
		core_color = configured_core_color
		facet_color = configured_facet_color
		accent_color = configured_accent_color
		var additive_material := CanvasItemMaterial.new()
		additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive_material
		queue_redraw()


	func _process(delta: float) -> void:
		elapsed_sec += delta
		if elapsed_sec >= lifetime_sec:
			queue_free()
			return
		queue_redraw()


	func contract_for_testing() -> Dictionary:
		return {
			"primitive": "facet_refraction",
			"shard_count": shard_directions.size(),
			"lifetime_sec": lifetime_sec,
			"facet_length_px": facet_start.distance_to(facet_end),
			"contact_footprint_px": 5.0,
			"maximum_shard_length_px": shard_lengths.max() if not shard_lengths.is_empty() else 0.0,
			"core_brightness": maxf(core_color.r, maxf(core_color.g, core_color.b)),
		}


	func timeline_state_for_testing(sample_time: float) -> Dictionary:
		var active_shards := 0
		for shard_index: int in shard_directions.size():
			var start_time := 0.13 + float(shard_index) * 0.032
			if sample_time >= start_time and sample_time < start_time + 0.43:
				active_shards += 1
		return {
			"contact_visible": sample_time >= 0.0 and sample_time <= 0.18,
			"facet_visible": sample_time > 0.035 and sample_time < 0.345,
			"active_shards": active_shards,
		}


	func _draw() -> void:
		_draw_contact_flash()
		_draw_facet_refraction()
		_draw_short_shards()


	func _draw_contact_flash() -> void:
		if elapsed_sec > 0.18:
			return
		var rise := clampf(elapsed_sec / 0.045, 0.0, 1.0)
		var fall := 1.0 - clampf((elapsed_sec - 0.07) / 0.11, 0.0, 1.0)
		var alpha := rise * fall
		var axis := (facet_end - facet_start).normalized()
		_draw_pixel(Vector2.ZERO, 5.0, _with_alpha(core_color, alpha))
		_draw_pixel(axis * 4.0, 3.0, _with_alpha(facet_color, alpha * 0.76))
		_draw_pixel(-axis * 3.0, 2.0, _with_alpha(facet_color, alpha * 0.52))


	func _draw_facet_refraction() -> void:
		var progress := clampf((elapsed_sec - 0.035) / 0.31, 0.0, 1.0)
		if progress <= 0.0 or progress >= 1.0:
			return
		var eased := 1.0 - pow(1.0 - progress, 2.0)
		var fade := 1.0 - clampf((progress - 0.72) / 0.28, 0.0, 1.0)
		for trail_index: int in 5:
			var trail_progress := maxf(eased - float(trail_index) * 0.065, 0.0)
			var point := facet_start.lerp(facet_end, trail_progress)
			var trail_alpha := fade * (1.0 - float(trail_index) * 0.17)
			var size := 3.0 if trail_index == 0 else 2.0
			var color := core_color if trail_index == 0 else facet_color
			_draw_pixel(point, size, _with_alpha(color, trail_alpha))


	func _draw_short_shards() -> void:
		for shard_index: int in shard_directions.size():
			var start_time := 0.13 + float(shard_index) * 0.032
			var progress := clampf((elapsed_sec - start_time) / 0.43, 0.0, 1.0)
			if progress <= 0.0 or progress >= 1.0:
				continue
			var eased := 1.0 - pow(1.0 - progress, 3.0)
			var fade := 1.0 - clampf((progress - 0.5) / 0.5, 0.0, 1.0)
			var direction: Vector2 = shard_directions[shard_index]
			var distance: float = shard_lengths[shard_index] * eased
			var shard_tip := direction * distance
			var shard_tail := direction * maxf(distance - 5.0, 1.5)
			var color := accent_color if shard_index == 2 else facet_color
			_draw_pixel_segment(
					shard_tail, shard_tip, _with_alpha(color, fade * 0.88), 2.0)


	func _draw_pixel_segment(
			start: Vector2, end: Vector2, color: Color, pixel_size: float) -> void:
		var distance := start.distance_to(end)
		var steps := maxi(1, ceili(distance / maxf(pixel_size, 1.0)))
		for step: int in range(steps + 1):
			_draw_pixel(start.lerp(end, float(step) / float(steps)), pixel_size, color)


	func _draw_pixel(point: Vector2, size: float, color: Color) -> void:
		var top_left := Vector2(
				floorf(point.x - size * 0.5),
				floorf(point.y - size * 0.5))
		draw_rect(Rect2(top_left, Vector2(size, size)), color)


	func _with_alpha(color: Color, alpha: float) -> Color:
		return Color(color.r, color.g, color.b, color.a * clampf(alpha, 0.0, 1.0))


func _ready() -> void:
	_register_layer(get_node(LEFT_PATH) as TextureRect, LEFT_ELLIPSES)
	_register_layer(get_node(RIGHT_PATH) as TextureRect, RIGHT_ELLIPSES)
	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	for crystal: Dictionary in _crystals:
		crystal.cooldown = maxf(float(crystal.cooldown) - delta, 0.0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	trigger_spark_at_viewport_position(mouse_event.position)


func trigger_spark_at_viewport_position(viewport_position: Vector2) -> bool:
	var hit := _crystal_hit_at_viewport_position(viewport_position)
	if hit.is_empty():
		return false
	var crystal_id := int(hit.crystal_id)
	var crystal: Dictionary = _crystals[crystal_id]
	if float(crystal.cooldown) > 0.0:
		return false
	crystal.cooldown = response_lifetime_sec
	_spawn_facet_response(viewport_position, crystal_id, hit.source_position as Vector2)
	return true


func crystal_count() -> int:
	return _crystals.size()


func crystal_id_at_viewport_position_for_testing(position: Vector2) -> int:
	var hit := _crystal_hit_at_viewport_position(position)
	return -1 if hit.is_empty() else int(hit.crystal_id)


func configured_facet_direction_for_testing(crystal_id: int) -> Vector2:
	if crystal_id < 0 or crystal_id >= FACET_DIRECTIONS.size():
		return Vector2.ZERO
	return FACET_DIRECTIONS[crystal_id].normalized()


func facet_segment_metrics_for_testing(crystal_id: int) -> Dictionary:
	var hit_position := find_interactive_position_for_testing(crystal_id)
	var hit := _crystal_hit_at_viewport_position(hit_position)
	if hit.is_empty():
		return {}
	var segment := _build_facet_segment(
			crystal_id, hit.source_position as Vector2)
	return {
		"length_px": (segment.end_viewport as Vector2).distance_to(
				segment.start_viewport as Vector2),
		"direction": segment.direction as Vector2,
	}


func active_response_contract_for_testing(response: Node) -> Dictionary:
	if response == null:
		return {}
	var effect := response.get_node_or_null("FacetRefraction") as CrystalFacetResponse
	return {} if effect == null else effect.contract_for_testing()


func find_interactive_position_for_testing(crystal_id: int) -> Vector2:
	if crystal_id < 0 or crystal_id >= _crystals.size():
		return Vector2(-1.0, -1.0)
	var crystal: Dictionary = _crystals[crystal_id]
	var layer := crystal.layer as TextureRect
	var ellipse := crystal.ellipse as Vector4
	var image := crystal.image as Image
	var minimum := Vector2i(
			maxi(floori(ellipse.x - ellipse.z), 0),
			maxi(floori(ellipse.y - ellipse.w), 0))
	var maximum := Vector2i(
			mini(ceili(ellipse.x + ellipse.z), image.get_width() - 1),
			mini(ceili(ellipse.y + ellipse.w), image.get_height() - 1))
	var best_source := Vector2(-1.0, -1.0)
	var best_distance := INF
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var source_position := Vector2(x, y) + Vector2(0.5, 0.5)
			if not _inside_ellipse(source_position, ellipse):
				continue
			if not _crystal_mask_has_pixel(crystal, Vector2i(x, y)):
				continue
			var viewport_position := _source_to_viewport(layer, source_position)
			if not DESIGN_VIEWPORT_RECT.has_point(viewport_position):
				continue
			var distance := source_position.distance_squared_to(
					Vector2(ellipse.x, ellipse.y))
			if distance < best_distance:
				best_distance = distance
				best_source = source_position
	if best_source.x < 0.0:
		return best_source
	return _source_to_viewport(layer, best_source)


func find_visible_non_crystal_position_for_testing(crystal_id: int) -> Vector2:
	if crystal_id < 0 or crystal_id >= _crystals.size():
		return Vector2(-1.0, -1.0)
	var crystal: Dictionary = _crystals[crystal_id]
	var layer := crystal.layer as TextureRect
	var ellipse := crystal.ellipse as Vector4
	var image := crystal.image as Image
	var minimum := Vector2i(
			maxi(floori(ellipse.x - ellipse.z), 0),
			maxi(floori(ellipse.y - ellipse.w), 0))
	var maximum := Vector2i(
			mini(ceili(ellipse.x + ellipse.z), image.get_width() - 1),
			mini(ceili(ellipse.y + ellipse.w), image.get_height() - 1))
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var source_position := Vector2(x, y) + Vector2(0.5, 0.5)
			if not _inside_ellipse(source_position, ellipse):
				continue
			if image.get_pixel(x, y).a < 0.8 or _crystal_mask_has_pixel(
					crystal, Vector2i(x, y)):
				continue
			var viewport_position := _source_to_viewport(layer, source_position)
			if DESIGN_VIEWPORT_RECT.has_point(viewport_position) \
					and _crystal_hit_at_viewport_position(viewport_position).is_empty():
				return viewport_position
	return Vector2(-1.0, -1.0)


func source_pixel_is_interactive_for_testing(
		crystal_id: int, source_pixel: Vector2i) -> bool:
	if crystal_id < 0 or crystal_id >= _crystals.size():
		return false
	var crystal: Dictionary = _crystals[crystal_id]
	var ellipse := crystal.ellipse as Vector4
	return _inside_ellipse(Vector2(source_pixel) + Vector2(0.5, 0.5), ellipse) \
			and _crystal_mask_has_pixel(crystal, source_pixel)


func interactive_pixel_count_for_testing(crystal_id: int) -> int:
	if crystal_id < 0 or crystal_id >= _crystals.size():
		return 0
	var crystal: Dictionary = _crystals[crystal_id]
	return (crystal.mask as Dictionary).size()


func rejected_palette_pixel_count_for_testing(crystal_id: int) -> int:
	if crystal_id < 0 or crystal_id >= _crystals.size():
		return 0
	var crystal: Dictionary = _crystals[crystal_id]
	return int(crystal.palette_candidate_count) - (crystal.mask as Dictionary).size()


func annotation_excluded_pixel_count_for_testing(crystal_id: int) -> int:
	if crystal_id < 0 or crystal_id >= _crystals.size():
		return 0
	var crystal: Dictionary = _crystals[crystal_id]
	return (crystal.annotation_excluded_mask as Dictionary).size()


func find_annotation_excluded_position_for_testing(crystal_id: int) -> Vector2:
	if crystal_id < 0 or crystal_id >= _crystals.size():
		return Vector2(-1.0, -1.0)
	var crystal: Dictionary = _crystals[crystal_id]
	var layer := crystal.layer as TextureRect
	var image := crystal.image as Image
	for key: int in (crystal.annotation_excluded_mask as Dictionary):
		var pixel := Vector2i(
				key % image.get_width(),
				floori(float(key) / float(image.get_width())))
		var viewport_position := _source_to_viewport(
				layer, Vector2(pixel) + Vector2(0.5, 0.5))
		if DESIGN_VIEWPORT_RECT.has_point(viewport_position) \
				and _crystal_hit_at_viewport_position(viewport_position).is_empty():
			return viewport_position
	return Vector2(-1.0, -1.0)


func annotation_exclusions_are_noninteractive_for_testing(crystal_id: int) -> bool:
	if crystal_id < 0 or crystal_id >= _crystals.size():
		return false
	var crystal: Dictionary = _crystals[crystal_id]
	var layer := crystal.layer as TextureRect
	var image := crystal.image as Image
	for key: int in (crystal.annotation_excluded_mask as Dictionary):
		var pixel := Vector2i(
				key % image.get_width(),
				floori(float(key) / float(image.get_width())))
		var viewport_position := _source_to_viewport(
				layer, Vector2(pixel) + Vector2(0.5, 0.5))
		if DESIGN_VIEWPORT_RECT.has_point(viewport_position) \
				and not _crystal_hit_at_viewport_position(viewport_position).is_empty():
			return false
	return true


func right2_edge_excluded_pixel_count_for_testing(crystal_id: int) -> int:
	if crystal_id < 0 or crystal_id >= _crystals.size():
		return 0
	var crystal: Dictionary = _crystals[crystal_id]
	return (crystal.right2_edge_excluded_mask as Dictionary).size()


func right2_edge_exclusions_are_noninteractive_for_testing() -> bool:
	if _crystals.size() <= 4:
		return false
	var crystal: Dictionary = _crystals[4]
	var layer := crystal.layer as TextureRect
	var image := crystal.image as Image
	for key: int in (crystal.right2_edge_excluded_mask as Dictionary):
		var pixel := Vector2i(
				key % image.get_width(),
				floori(float(key) / float(image.get_width())))
		var viewport_position := _source_to_viewport(
				layer, Vector2(pixel) + Vector2(0.5, 0.5))
		if DESIGN_VIEWPORT_RECT.has_point(viewport_position) \
				and not _crystal_hit_at_viewport_position(viewport_position).is_empty():
			return false
	return true


func find_rejected_palette_position_for_testing(crystal_id: int) -> Vector2:
	if crystal_id < 0 or crystal_id >= _crystals.size():
		return Vector2(-1.0, -1.0)
	var crystal: Dictionary = _crystals[crystal_id]
	var layer := crystal.layer as TextureRect
	var ellipse := crystal.ellipse as Vector4
	var image := crystal.image as Image
	var minimum := Vector2i(
			maxi(floori(ellipse.x - ellipse.z), 0),
			maxi(floori(ellipse.y - ellipse.w), 0))
	var maximum := Vector2i(
			mini(ceili(ellipse.x + ellipse.z), image.get_width() - 1),
			mini(ceili(ellipse.y + ellipse.w), image.get_height() - 1))
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var pixel := Vector2i(x, y)
			var source_position := Vector2(pixel) + Vector2(0.5, 0.5)
			if _inside_ellipse(source_position, ellipse) \
					and _is_crystal_pixel(image, pixel) \
					and not _crystal_mask_has_pixel(crystal, pixel):
				var viewport_position := _source_to_viewport(layer, source_position)
				if DESIGN_VIEWPORT_RECT.has_point(viewport_position) \
						and _crystal_hit_at_viewport_position(viewport_position).is_empty():
					return viewport_position
	return Vector2(-1.0, -1.0)


func _register_layer(layer: TextureRect, ellipses: Array[Vector4]) -> void:
	assert(layer != null and layer.texture != null)
	var image := layer.texture.get_image()
	assert(image != null and not image.is_empty())
	for ellipse: Vector4 in ellipses:
		var crystal_id := _crystals.size()
		var exclusion_polygon := PackedVector2Array(
				CRYSTAL_ANNOTATION_EXCLUSION_POLYGONS[crystal_id])
		var right2_edge_polygon := PackedVector2Array()
		if crystal_id == 4:
			right2_edge_polygon = PackedVector2Array(
					RIGHT2_EDGE_ANNOTATION_EXCLUSION_POLYGON)
		var mask_data := _build_center_connected_crystal_mask(
				image, ellipse, exclusion_polygon, right2_edge_polygon)
		assert(not (mask_data.mask as Dictionary).is_empty())
		_crystals.append({
			"layer": layer,
			"ellipse": ellipse,
			"image": image,
			"mask": mask_data.mask,
			"annotation_excluded_mask": mask_data.annotation_excluded_mask,
			"right2_edge_excluded_mask": mask_data.right2_edge_excluded_mask,
			"palette_candidate_count": mask_data.palette_candidate_count,
			"cooldown": 0.0,
		})


func _crystal_hit_at_viewport_position(viewport_position: Vector2) -> Dictionary:
	var selected_id := -1
	var selected_distance := INF
	for crystal_id: int in _crystals.size():
		var crystal: Dictionary = _crystals[crystal_id]
		var layer := crystal.layer as TextureRect
		var source_position := _viewport_to_source(layer, viewport_position)
		if source_position.x < 0.0:
			continue
		var ellipse := crystal.ellipse as Vector4
		if not _inside_ellipse(source_position, ellipse):
			continue
		var pixel := Vector2i(floori(source_position.x), floori(source_position.y))
		if not _crystal_mask_has_pixel(crystal, pixel):
			continue
		var normalized := (source_position - Vector2(ellipse.x, ellipse.y)) \
				/ Vector2(maxf(ellipse.z, 1.0), maxf(ellipse.w, 1.0))
		var distance := normalized.length_squared()
		if distance < selected_distance:
			selected_distance = distance
			selected_id = crystal_id
	if selected_id < 0:
		return {}
	var selected_layer := _crystals[selected_id].layer as TextureRect
	return {
		"crystal_id": selected_id,
		"source_position": _viewport_to_source(selected_layer, viewport_position),
	}


func _viewport_to_source(layer: TextureRect, viewport_position: Vector2) -> Vector2:
	var local_position := layer.get_global_transform_with_canvas().affine_inverse() \
			* viewport_position
	if not Rect2(Vector2.ZERO, layer.size).has_point(local_position):
		return Vector2(-1.0, -1.0)
	return Vector2(
			local_position.x / layer.size.x * float(layer.texture.get_width()),
			local_position.y / layer.size.y * float(layer.texture.get_height()))


func _source_to_viewport(layer: TextureRect, source_position: Vector2) -> Vector2:
	var local_position := Vector2(
			source_position.x / float(layer.texture.get_width()) * layer.size.x,
			source_position.y / float(layer.texture.get_height()) * layer.size.y)
	return layer.get_global_transform_with_canvas() * local_position


func _inside_ellipse(source_position: Vector2, ellipse: Vector4) -> bool:
	var normalized := (source_position - Vector2(ellipse.x, ellipse.y)) \
			/ Vector2(maxf(ellipse.z, 1.0), maxf(ellipse.w, 1.0))
	return normalized.length_squared() < 1.0


func _is_crystal_pixel(image: Image, pixel: Vector2i) -> bool:
	if pixel.x < 0 or pixel.y < 0 \
			or pixel.x >= image.get_width() or pixel.y >= image.get_height():
		return false
	var color := image.get_pixelv(pixel)
	if color.a < 0.8:
		return false
	var maximum := maxf(color.r, maxf(color.g, color.b))
	var minimum := minf(color.r, minf(color.g, color.b))
	var saturation := (maximum - minimum) / maxf(maximum, 0.001)
	var luma := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return color.b >= 0.48 \
			and color.b - color.r >= 0.28 \
			and maxf(color.g, color.b) - color.r >= 0.24 \
			and saturation >= 0.5 \
			and luma >= 0.16 and luma <= 0.74


func _build_center_connected_crystal_mask(
		image: Image, ellipse: Vector4,
		exclusion_polygon: PackedVector2Array,
		right2_edge_polygon: PackedVector2Array) -> Dictionary:
	var candidates: Dictionary = {}
	var minimum := Vector2i(
			maxi(floori(ellipse.x - ellipse.z), 0),
			maxi(floori(ellipse.y - ellipse.w), 0))
	var maximum := Vector2i(
			mini(ceili(ellipse.x + ellipse.z), image.get_width() - 1),
			mini(ceili(ellipse.y + ellipse.w), image.get_height() - 1))
	var seed := Vector2i(-1, -1)
	var seed_distance := INF
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var pixel := Vector2i(x, y)
			var source_position := Vector2(pixel) + Vector2(0.5, 0.5)
			if not _inside_ellipse(source_position, ellipse) \
					or not _is_crystal_pixel(image, pixel):
				continue
			candidates[_pixel_key(pixel, image.get_width())] = pixel
			var distance := source_position.distance_squared_to(
					Vector2(ellipse.x, ellipse.y))
			if distance < seed_distance:
				seed_distance = distance
				seed = pixel
	if seed.x < 0:
		return {
			"mask": {},
			"annotation_excluded_mask": {},
			"right2_edge_excluded_mask": {},
			"palette_candidate_count": 0,
		}
	var mask: Dictionary = {}
	var queue: Array[Vector2i] = [seed]
	mask[_pixel_key(seed, image.get_width())] = true
	var cursor := 0
	while cursor < queue.size():
		var point: Vector2i = queue[cursor]
		cursor += 1
		for offset: Vector2i in [
			Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
		]:
			var neighbor := point + offset
			var neighbor_key := _pixel_key(neighbor, image.get_width())
			if candidates.has(neighbor_key) and not mask.has(neighbor_key):
				mask[neighbor_key] = true
				queue.append(neighbor)
	var annotation_excluded_mask := _exclude_mask_pixels_in_polygon(
			mask, candidates, exclusion_polygon)
	var right2_edge_excluded_mask := _exclude_mask_pixels_in_polygon(
			mask, candidates, right2_edge_polygon)
	annotation_excluded_mask.merge(right2_edge_excluded_mask, true)
	return {
		"mask": mask,
		"annotation_excluded_mask": annotation_excluded_mask,
		"right2_edge_excluded_mask": right2_edge_excluded_mask,
		"palette_candidate_count": candidates.size(),
	}


func _exclude_mask_pixels_in_polygon(
		mask: Dictionary, candidates: Dictionary,
		exclusion_polygon: PackedVector2Array) -> Dictionary:
	var excluded_mask: Dictionary = {}
	if exclusion_polygon.is_empty():
		return excluded_mask
	for key: int in mask.keys():
		var pixel := candidates.get(key) as Vector2i
		var center := Vector2(pixel) + Vector2(0.5, 0.5)
		if Geometry2D.is_point_in_polygon(center, exclusion_polygon):
			excluded_mask[key] = true
	for key: int in excluded_mask:
		mask.erase(key)
	return excluded_mask


func _crystal_mask_has_pixel(crystal: Dictionary, pixel: Vector2i) -> bool:
	var image := crystal.image as Image
	return (crystal.mask as Dictionary).has(_pixel_key(pixel, image.get_width()))


func _pixel_key(pixel: Vector2i, image_width: int) -> int:
	return pixel.y * image_width + pixel.x


func _spawn_facet_response(
		viewport_position: Vector2, crystal_id: int, source_position: Vector2) -> void:
	var stage := get_parent() as Control
	var response := Node2D.new()
	response.name = "Scene8CrystalFacetResponse"
	response.position = stage.get_global_transform_with_canvas().affine_inverse() \
			* viewport_position
	stage.add_child(response)

	var segment := _build_facet_segment(crystal_id, source_position)
	var stage_inverse := stage.get_global_transform_with_canvas().affine_inverse()
	var start_local := stage_inverse * (segment.start_viewport as Vector2) - response.position
	var end_local := stage_inverse * (segment.end_viewport as Vector2) - response.position
	var facet_axis := (end_local - start_local).normalized()
	var side := -1.0 if crystal_id % 2 == 0 else 1.0
	var shard_directions: Array[Vector2] = [
		facet_axis.rotated(-0.52 * side).normalized(),
		facet_axis.rotated(0.18 * side).normalized(),
		facet_axis.rotated(0.72 * side).normalized(),
	]
	var shard_lengths: Array[float] = [
		11.0 + float(crystal_id % 2) * 2.0,
		16.0 + float(crystal_id % 3),
		9.0 + float((crystal_id + 1) % 3),
	]
	if shard_count < shard_directions.size():
		shard_directions.resize(shard_count)
		shard_lengths.resize(shard_count)
	var accent_color := VIOLET_ACCENT if crystal_id in [2, 4] else GREEN_ACCENT
	var refraction := CrystalFacetResponse.new()
	refraction.name = "FacetRefraction"
	refraction.configure(
			response_lifetime_sec,
			start_local,
			end_local,
			shard_directions,
			shard_lengths,
			CORE_COLOR,
			CYAN_COLOR,
			accent_color)
	response.add_child(refraction)
	get_tree().create_timer(response_lifetime_sec + 0.08).timeout.connect(
			_free_response.bind(response))


func _free_response(response: Node2D) -> void:
	if is_instance_valid(response):
		response.queue_free()


func _build_facet_segment(crystal_id: int, source_position: Vector2) -> Dictionary:
	var crystal: Dictionary = _crystals[crystal_id]
	var layer := crystal.layer as TextureRect
	var ellipse := crystal.ellipse as Vector4
	var primary := FACET_DIRECTIONS[crystal_id].normalized()
	var alternate := FACET_ALTERNATE_DIRECTIONS[crystal_id].normalized()
	var primary_runs := _measure_facet_runs(crystal, source_position, primary)
	var alternate_runs := _measure_facet_runs(crystal, source_position, alternate)
	var direction := primary
	var runs := primary_runs
	if float(alternate_runs.negative) + float(alternate_runs.positive) \
			> float(primary_runs.negative) + float(primary_runs.positive) + 1.0:
		direction = alternate
		runs = alternate_runs
	var source_step_viewport := _source_to_viewport(layer, source_position + direction) \
			- _source_to_viewport(layer, source_position)
	var pixels_per_source := maxf(source_step_viewport.length(), 0.001)
	var negative_length := clampf(
			float(runs.negative) * pixels_per_source, 7.0, 22.0)
	var positive_length := clampf(
			float(runs.positive) * pixels_per_source, 9.0, 26.0)
	var total_length := negative_length + positive_length
	if total_length < minimum_facet_length_px:
		var shortage := minimum_facet_length_px - total_length
		if float(runs.positive) >= float(runs.negative):
			positive_length += shortage
		else:
			negative_length += shortage
		total_length = minimum_facet_length_px
	if total_length > maximum_facet_length_px:
		var scale_factor := maximum_facet_length_px / total_length
		negative_length *= scale_factor
		positive_length *= scale_factor
	var direction_viewport := source_step_viewport.normalized()
	var contact_viewport := _source_to_viewport(layer, source_position)
	return {
		"start_viewport": contact_viewport - direction_viewport * negative_length,
		"end_viewport": contact_viewport + direction_viewport * positive_length,
		"direction": direction_viewport,
	}


func _measure_facet_runs(
		crystal: Dictionary, source_position: Vector2,
		direction: Vector2) -> Dictionary:
	return {
		"negative": _measure_facet_run(
				crystal, source_position, -direction.normalized()),
		"positive": _measure_facet_run(
				crystal, source_position, direction.normalized()),
	}


func _measure_facet_run(
		crystal: Dictionary, source_position: Vector2,
		direction: Vector2) -> float:
	var ellipse := crystal.ellipse as Vector4
	var last_valid := 0.0
	var misses := 0
	for step: int in range(1, 13):
		var sample := source_position + direction * float(step)
		if not _inside_ellipse(sample, ellipse):
			break
		if _has_crystal_pixel_near(crystal, Vector2i(floor(sample.x), floor(sample.y))):
			last_valid = float(step)
			misses = 0
		else:
			misses += 1
			if misses >= 2:
				break
	return last_valid


func _has_crystal_pixel_near(crystal: Dictionary, center: Vector2i) -> bool:
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			if _crystal_mask_has_pixel(crystal, center + Vector2i(offset_x, offset_y)):
				return true
	return false

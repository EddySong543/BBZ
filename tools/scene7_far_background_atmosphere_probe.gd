extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_far_cleanup.gdshader"


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var stage := SCENE7.instantiate() as BattleStage
	root.add_child(stage)
	var background := stage.get_node("FarBackground") as TextureRect
	var material := background.material as ShaderMaterial
	var source := background.texture.get_image()
	var rendered := _simulate_atmosphere(source, material)

	var source_alpha := _alpha_used_rect(source)
	var rendered_alpha := _alpha_used_rect(rendered)
	var source_unique := _opaque_color_count(source)
	var rendered_unique := _opaque_color_count(rendered)
	var source_edges := _interior_edge_rate(source, 0.08)
	var rendered_edges := _interior_edge_rate(rendered, 0.08)
	var source_far_contrast := _luma_standard_deviation(source, 15, 102)
	var rendered_far_contrast := _luma_standard_deviation(rendered, 15, 102)
	var source_near_contrast := _luma_standard_deviation(source, 122, 175)
	var rendered_near_contrast := _luma_standard_deviation(rendered, 122, 175)
	var source_far_mean := _mean_color(source, 15, 102)
	var rendered_far_mean := _mean_color(rendered, 15, 102)
	var source_near_mean := _mean_color(source, 122, 175)
	var rendered_near_mean := _mean_color(rendered, 122, 175)
	var source_near_saturation := _mean_saturation(source, 102, 175)
	var rendered_near_saturation := _mean_saturation(rendered, 102, 175)
	var source_near_gold := _warm_gold_fraction(source, 102, 175)
	var rendered_near_gold := _warm_gold_fraction(rendered, 102, 175)
	var rendered_near_rust := _rust_fraction(rendered, 102, 175)
	var rendered_near_warm_clip := _warm_channel_clip_fraction(rendered, 102, 175)
	var air_color: Color = material.get_shader_parameter("air_color")
	var source_air_delta := _color_delta(source_far_mean, air_color)
	var rendered_air_delta := _color_delta(rendered_far_mean, air_color)
	var near_color_delta := _color_delta(source_near_mean, rendered_near_mean)
	var shader_source := FileAccess.get_file_as_string(SHADER_PATH)

	var structure_contract := (
		background.size.is_equal_approx(Vector2(332.0, 188.0))
		and background.scale.is_equal_approx(Vector2(6.0, 6.0))
		and background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and material.resource_local_to_scene
		and material.shader.resource_path == SHADER_PATH
		and shader_source.contains("warm_chroma_mask")
		and shader_source.contains("sand_palette_ramp")
		and shader_source.contains("sand_shadow_color")
		and shader_source.contains("sand_mid_color")
		and shader_source.contains("sand_highlight_color")
		and shader_source.contains("saturation_scaled_palette"))
	var pixel_contract := (
		rendered_alpha == source_alpha
		and rendered_unique >= int(float(source_unique) * 0.018)
		and rendered_unique <= int(float(source_unique) * 0.95)
		and rendered_edges >= source_edges * 0.30
		and rendered_edges <= source_edges * 0.98
		and rendered_far_contrast <= source_far_contrast * 0.95
		and rendered_near_contrast >= source_near_contrast * 0.45
		and rendered_air_delta < source_air_delta
		and near_color_delta <= 0.50
		and rendered_near_saturation >= 0.37
		and rendered_near_saturation <= 0.46
		and rendered_near_mean.h * 360.0 >= 8.0
		and rendered_near_mean.h * 360.0 <= 24.0
		and _luma(rendered_near_mean) >= 0.60
		and _luma(rendered_near_mean) <= 0.72
		and rendered_near_gold <= 0.30
		and rendered_near_rust <= 0.04
		and rendered_near_warm_clip <= 0.01)
	var passed := structure_contract and pixel_contract
	print(
		"SCENE7_FAR_BACKGROUND_CONTINUOUS_AIR: ",
		"PASS" if passed else "FAIL",
		" structure_contract=", structure_contract,
		" pixel_contract=", pixel_contract,
		" alpha_preserved=", rendered_alpha == source_alpha,
		" unique=", source_unique, "->", rendered_unique,
		" edge_rate=", snappedf(source_edges, 0.0001),
		"->", snappedf(rendered_edges, 0.0001),
		" far_contrast=", snappedf(source_far_contrast, 0.0001),
		"->", snappedf(rendered_far_contrast, 0.0001),
		" near_contrast=", snappedf(source_near_contrast, 0.0001),
		"->", snappedf(rendered_near_contrast, 0.0001),
		" far_air_delta=", snappedf(source_air_delta, 0.0001),
		"->", snappedf(rendered_air_delta, 0.0001),
		" near_color_delta=", snappedf(near_color_delta, 0.0001))
	print(
		"SCENE7_FAR_BACKGROUND_CORAL_DIAGNOSTIC:",
		" near_saturation=", snappedf(source_near_saturation, 0.0001),
		"->", snappedf(rendered_near_saturation, 0.0001),
		" high_chroma_gold=", snappedf(source_near_gold, 0.0001),
		"->", snappedf(rendered_near_gold, 0.0001),
		" rust=", snappedf(rendered_near_rust, 0.0001),
		" warm_channel_clip=", snappedf(rendered_near_warm_clip, 0.0001),
		" mean_hue=", snappedf(rendered_near_mean.h * 360.0, 0.1),
		" mean_luma=", snappedf(_luma(rendered_near_mean), 0.001))
	stage.queue_free()
	quit(0 if passed else 1)


func _simulate_atmosphere(source: Image, material: ShaderMaterial) -> Image:
	var result := Image.create_empty(
			source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	var cleanup_strength := float(material.get_shader_parameter("cleanup_strength"))
	var outlier_threshold := float(material.get_shader_parameter("outlier_threshold"))
	var neighbor_coherence := float(material.get_shader_parameter("neighbor_coherence"))
	var edge_protection := float(material.get_shader_parameter("edge_protection"))
	var radius := int(round(float(material.get_shader_parameter("local_radius_px"))))
	var far_detail := float(material.get_shader_parameter("far_detail_retention"))
	var near_detail := float(material.get_shader_parameter("near_detail_retention"))
	var far_saturation := float(material.get_shader_parameter(
			"far_saturation_retention"))
	var near_saturation := float(material.get_shader_parameter(
			"near_saturation_retention"))
	var distance_start := float(material.get_shader_parameter("distance_start"))
	var distance_end := float(material.get_shader_parameter("distance_end"))
	var air_color: Color = material.get_shader_parameter("air_color")
	var air_strength := float(material.get_shader_parameter("air_strength"))
	var edge_air_strength := float(material.get_shader_parameter("edge_air_strength"))
	var horizon_color: Color = material.get_shader_parameter("horizon_color")
	var horizon_warmth := float(material.get_shader_parameter("horizon_warmth"))
	var sand_shadow: Color = material.get_shader_parameter("sand_shadow_color")
	var sand_mid: Color = material.get_shader_parameter("sand_mid_color")
	var sand_highlight: Color = material.get_shader_parameter(
			"sand_highlight_color")
	var sand_palette_strength := float(material.get_shader_parameter(
			"sand_palette_strength"))
	var sand_saturation := float(material.get_shader_parameter("sand_saturation"))
	var source_value_detail := float(material.get_shader_parameter(
			"source_value_detail"))
	var opacity := float(material.get_shader_parameter("opacity"))
	for y: int in source.get_height():
		for x: int in source.get_width():
			var center := source.get_pixel(x, y)
			if center.a <= 0.0:
				result.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var left := _sample(source, x - 1, y)
			var right := _sample(source, x + 1, y)
			var up := _sample(source, x, y - 1)
			var down := _sample(source, x, y + 1)
			var neighbor_mean := (left + right + up + down) * 0.25
			var neighbor_spread := maxf(
					maxf(_color_delta(left, neighbor_mean),
						_color_delta(right, neighbor_mean)),
					maxf(_color_delta(up, neighbor_mean),
						_color_delta(down, neighbor_mean)))
			var outlier_gate := _smoothstep(
					outlier_threshold * 0.72,
					outlier_threshold,
					_color_delta(center, neighbor_mean))
			var coherence_gate := 1.0 - _smoothstep(
					neighbor_coherence,
					neighbor_coherence + 0.08,
					neighbor_spread)
			var edge_signal := maxf(
					_color_delta(left, right), _color_delta(up, down))
			var edge_gate := 1.0 - _smoothstep(
					edge_protection, edge_protection + 0.12, edge_signal)
			var opaque_neighbors := minf(
					minf(left.a, right.a), minf(up.a, down.a))
			var interior_gate := center.a * _smoothstep(0.92, 0.995, opaque_neighbors)
			var cleanup_mix := (
					cleanup_strength * outlier_gate
					* coherence_gate * edge_gate * interior_gate)
			var cleaned := center.lerp(neighbor_mean, cleanup_mix)
			var local_mean := _local_mean(source, x, y, radius)
			var uv_y := (float(y) + 0.5) / float(source.get_height())
			var distance_weight := 1.0 - _smoothstep(
					distance_start, distance_end, uv_y)
			var structural_edge := _smoothstep(0.09, 0.24, edge_signal)
			var detail_retention := lerpf(near_detail, far_detail, distance_weight)
			detail_retention = lerpf(detail_retention, 0.98, structural_edge)
			var color := local_mean.lerp(
					cleaned, lerpf(1.0, detail_retention, interior_gate))
			var luma := _luma(color)
			var saturation_retention := lerpf(
					near_saturation, far_saturation, distance_weight)
			color = Color(luma, luma, luma, color.a).lerp(
					color, saturation_retention)
			var warm_mask := _warm_chroma_mask(cleaned)
			var warm_luma := _luma(color)
			var sand_palette := _sand_palette_ramp(
					warm_luma, sand_shadow, sand_mid, sand_highlight)
			sand_palette = _saturation_scaled_palette(
					sand_palette, sand_saturation)
			var palette_luma := _luma(sand_palette)
			var palette_scale := warm_luma / maxf(palette_luma, 0.001)
			var value_detail_palette := Color(
					sand_palette.r * palette_scale,
					sand_palette.g * palette_scale,
					sand_palette.b * palette_scale,
					color.a)
			sand_palette = sand_palette.lerp(
					value_detail_palette, source_value_detail)
			var warm_graded := Color(
					warm_luma, warm_luma, warm_luma, color.a).lerp(
							sand_palette, sand_palette_strength)
			color = color.lerp(warm_graded, warm_mask)
			color = color.lerp(air_color, distance_weight * air_strength)
			var horizon_weight := _smoothstep(0.58, 0.96, uv_y)
			color = color.lerp(
					horizon_color, horizon_weight * horizon_warmth * interior_gate)
			var boundary := clampf(center.a - opaque_neighbors, 0.0, 1.0)
			var silhouette_air := (
					boundary * edge_air_strength
					* lerpf(0.70, 1.0, distance_weight))
			color = color.lerp(air_color, silhouette_air)
			color = Color(
					round(clampf(color.r, 0.0, 1.0) * 63.0) / 63.0,
					round(clampf(color.g, 0.0, 1.0) * 63.0) / 63.0,
					round(clampf(color.b, 0.0, 1.0) * 63.0) / 63.0,
					center.a * opacity)
			result.set_pixel(x, y, color)
	return result


func _sample(image: Image, x: int, y: int) -> Color:
	return image.get_pixel(
			clampi(x, 0, image.get_width() - 1),
			clampi(y, 0, image.get_height() - 1))


func _local_mean(image: Image, x: int, y: int, radius: int) -> Color:
	var samples: Array[Color] = [
		_sample(image, x, y),
		_sample(image, x - 1, y), _sample(image, x + 1, y),
		_sample(image, x, y - 1), _sample(image, x, y + 1),
		_sample(image, x - radius, y), _sample(image, x + radius, y),
		_sample(image, x, y - radius), _sample(image, x, y + radius),
	]
	var total := Color(0.0, 0.0, 0.0, 0.0)
	var weight_total := 0.0
	for index: int in samples.size():
		var sample := samples[index]
		var center_weight := 4.0 if index == 0 else 1.0
		var weight := sample.a * center_weight
		total += sample * weight
		weight_total += weight
	return total / maxf(weight_total, 0.001)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / maxf(edge1 - edge0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _warm_chroma_mask(color: Color) -> float:
	var maximum := maxf(color.r, maxf(color.g, color.b))
	var minimum := minf(color.r, minf(color.g, color.b))
	var saturation := (maximum - minimum) / maxf(maximum, 0.001)
	var warm_over_blue := color.r - color.b
	return _smoothstep(0.035, 0.16, warm_over_blue) \
			* _smoothstep(0.28, 0.62, saturation)


func _sand_palette_ramp(
		luma: float,
		shadow: Color,
		middle: Color,
		highlight: Color) -> Color:
	var middle_weight := _smoothstep(0.08, 0.42, luma)
	var highlight_weight := _smoothstep(0.38, 0.72, luma)
	return shadow.lerp(middle, middle_weight).lerp(
			highlight, highlight_weight)


func _saturation_scaled_palette(palette: Color, gain: float) -> Color:
	var palette_luma := _luma(palette)
	return Color(
			clampf(palette_luma + (palette.r - palette_luma) * gain, 0.0, 1.0),
			clampf(palette_luma + (palette.g - palette_luma) * gain, 0.0, 1.0),
			clampf(palette_luma + (palette.b - palette_luma) * gain, 0.0, 1.0),
			palette.a)


func _alpha_used_rect(image: Image) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < 0.01:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _opaque_color_count(image: Image) -> int:
	var colors := {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a >= 0.95:
				colors[color.to_rgba32() >> 8] = true
	return colors.size()


func _interior_edge_rate(image: Image, threshold: float) -> float:
	var edges := 0
	var comparisons := 0
	for y: int in range(1, image.get_height() - 1):
		for x: int in range(1, image.get_width() - 1):
			var center := image.get_pixel(x, y)
			if center.a < 0.95:
				continue
			for neighbor: Color in [image.get_pixel(x + 1, y), image.get_pixel(x, y + 1)]:
				if neighbor.a < 0.95:
					continue
				comparisons += 1
				if _color_delta(center, neighbor) >= threshold:
					edges += 1
	return float(edges) / float(comparisons) if comparisons > 0 else 0.0


func _luma_standard_deviation(image: Image, top: int, bottom: int) -> float:
	var values: Array[float] = []
	for y: int in range(top, mini(bottom, image.get_height())):
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a >= 0.95:
				values.append(_luma(color))
	if values.is_empty():
		return 0.0
	var mean := 0.0
	for value: float in values:
		mean += value
	mean /= float(values.size())
	var variance := 0.0
	for value: float in values:
		variance += (value - mean) * (value - mean)
	return sqrt(variance / float(values.size()))


func _mean_color(image: Image, top: int, bottom: int) -> Color:
	var total := Color(0.0, 0.0, 0.0, 0.0)
	var count := 0
	for y: int in range(top, mini(bottom, image.get_height())):
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.95:
				continue
			total += color
			count += 1
	return total / float(count) if count > 0 else Color.TRANSPARENT


func _mean_saturation(image: Image, top: int, bottom: int) -> float:
	var total := 0.0
	var count := 0
	for y: int in range(top, mini(bottom, image.get_height())):
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.95:
				continue
			total += color.s
			count += 1
	return total / float(count) if count > 0 else 0.0


func _warm_gold_fraction(image: Image, top: int, bottom: int) -> float:
	var warm_count := 0
	var count := 0
	for y: int in range(top, mini(bottom, image.get_height())):
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.95:
				continue
			count += 1
			if color.s >= 0.62 and color.h * 360.0 <= 62.0:
				warm_count += 1
	return float(warm_count) / float(count) if count > 0 else 0.0


func _rust_fraction(image: Image, top: int, bottom: int) -> float:
	var rust_count := 0
	var count := 0
	for y: int in range(top, mini(bottom, image.get_height())):
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.95:
				continue
			count += 1
			var hue_degrees := color.h * 360.0
			if hue_degrees <= 28.0 and color.s >= 0.36 and _luma(color) <= 0.45:
				rust_count += 1
	return float(rust_count) / float(count) if count > 0 else 0.0


func _warm_channel_clip_fraction(image: Image, top: int, bottom: int) -> float:
	var clipped_count := 0
	var count := 0
	for y: int in range(top, mini(bottom, image.get_height())):
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.95:
				continue
			count += 1
			if color.r > color.b and color.g > color.b and color.b <= 0.015:
				clipped_count += 1
	return float(clipped_count) / float(count) if count > 0 else 0.0


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _color_delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))

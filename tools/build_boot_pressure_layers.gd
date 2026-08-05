extends SceneTree

const SOURCE_PATH := (
	"res://assets/ui/boot/boot_pressure_background_v2.png")
const RING_CENTER := Vector2(843.0, 295.0)
const GOLD_FLOW_DIRECTION := Vector2(0.52, -1.0)
const BLUE_EDGE_SEARCH_RADIUS := 4
const GOLD_EDGE_SEARCH_RADIUS := 12
const GOLD_HOLE_PATCH_RECTS: Array[Rect2i] = [
	Rect2i(694, 269, 18, 16),
	Rect2i(735, 297, 16, 16),
	Rect2i(710, 335, 17, 18),
	Rect2i(768, 359, 17, 19),
]

const OUTPUT_PATHS: Dictionary[String, String] = {
	"blue_base":
		"res://assets/ui/boot/boot_pressure_blue_base.png",
	"blue_mid":
		"res://assets/ui/boot/boot_pressure_blue_mid.png",
	"blue_light":
		"res://assets/ui/boot/boot_pressure_blue_light.png",
	"blue_foreground":
		"res://assets/ui/boot/boot_pressure_blue_foreground.png",
	"gold_combined":
		"res://assets/ui/boot/boot_pressure_gold_combined.png",
	"gold_flow":
		"res://assets/ui/boot/boot_pressure_gold_flow.png",
}


func _init() -> void:
	var source := Image.load_from_file(
			ProjectSettings.globalize_path(SOURCE_PATH))
	if source == null or source.is_empty():
		push_error("Boot pressure source image could not be loaded.")
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)

	var layers: Dictionary[String, Image] = {}
	var blue_mask := _build_soft_mask(source, true)
	blue_mask = _recover_dense_highlights(
			blue_mask,
			3,
			0.55,
			14,
			11)
	blue_mask = _clean_blue_mask(blue_mask)
	var gold_mask := _build_soft_mask(source, false)
	gold_mask = _recover_dense_highlights(
			gold_mask,
			2,
			0.60,
			15,
			12)
	gold_mask = _fill_confirmed_gold_holes(gold_mask)

	layers["blue_base"] = _recover_clean_layer(
			source,
			blue_mask,
			BLUE_EDGE_SEARCH_RADIUS,
			true)
	layers["gold_combined"] = _recover_clean_layer(
			source,
			gold_mask,
			GOLD_EDGE_SEARCH_RADIUS,
			false)
	_build_blue_derivative_layers(layers)

	layers["gold_flow"] = _create_transparent_image(
			source.get_width(),
			source.get_height())
	layers["gold_flow"].fill(Color(0.5, 0.5, 0.0, 0.0))

	_paint_gold_flow_map(
			layers["gold_flow"],
			source.get_width(),
			source.get_height())

	var counts: Dictionary[String, int] = {}
	for layer_name: String in OUTPUT_PATHS:
		counts[layer_name] = _count_visible_pixels(layers[layer_name])

	if not _validate_clean_layers(layers, counts):
		quit(1)
		return

	for layer_name: String in OUTPUT_PATHS:
		var output_path: String = OUTPUT_PATHS[layer_name]
		var error := layers[layer_name].save_png(
				ProjectSettings.globalize_path(output_path))
		if error != OK:
			push_error(
				"Could not save %s: %s"
				% [output_path, error_string(error)])
			quit(1)
			return

	print(
		"BOOT_PRESSURE_LAYERS_OK: size=%dx%d counts=%s"
		% [
			source.get_width(),
			source.get_height(),
			str(counts),
		])
	quit()


func _create_transparent_image(width: int, height: int) -> Image:
	var image := Image.create_empty(
			width,
			height,
			false,
			Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return image


func _build_soft_mask(source: Image, blue_layer: bool) -> Image:
	var mask := _create_transparent_image(
			source.get_width(),
			source.get_height())
	for y: int in source.get_height():
		for x: int in source.get_width():
			var color := source.get_pixel(x, y)
			var alpha := (
					_blue_mask_alpha(color)
					if blue_layer
					else _gold_mask_alpha(color))
			if (
					not blue_layer
					and Vector2(float(x), float(y)).distance_to(
							RING_CENTER) > 430.0
			):
				alpha = 0.0
			mask.set_pixel(x, y, Color(alpha, 0.0, 0.0, 1.0))
	return mask


func _blue_mask_alpha(color: Color) -> float:
	# Paper pixels are warm (blue is below red and green). The minimum
	# cool-channel gap therefore recovers pale blue antialiasing without
	# accepting the beige matte.
	var cool_gap := minf(color.b - color.r, color.b - color.g)
	var dominance := smoothstep(0.001, 0.040, cool_gap)
	var hue_support := (
			smoothstep(0.48, 0.53, color.h)
			* (1.0 - smoothstep(0.69, 0.74, color.h)))
	var chroma_support := smoothstep(0.02, 0.18, color.s)
	return clampf(
			dominance * maxf(hue_support, chroma_support * 0.72),
			0.0,
			1.0)


func _gold_mask_alpha(color: Color) -> float:
	# Gold shares the paper hue, so saturation and warm-channel separation
	# must both be present. This rejects the paper texture while retaining a
	# soft alpha ramp at the authored gold edge.
	var hue_support := (
			smoothstep(0.030, 0.055, color.h)
			* (1.0 - smoothstep(0.175, 0.205, color.h)))
	var saturation_support := smoothstep(0.30, 0.54, color.s)
	var warm_gap := minf(color.r - color.b, color.g - color.b)
	var warm_support := smoothstep(0.18, 0.34, warm_gap)
	return clampf(
			hue_support * saturation_support * warm_support,
			0.0,
			1.0)


func _clean_blue_mask(mask: Image) -> Image:
	var cleaned := _create_transparent_image(
			mask.get_width(),
			mask.get_height())
	for y: int in mask.get_height():
		for x: int in mask.get_width():
			var alpha := mask.get_pixel(x, y).r
			var visible_neighbors := _count_mask_neighbors(
					mask,
					x,
					y,
					0.05)
			var solid_neighbors := _count_mask_neighbors(
					mask,
					x,
					y,
					0.65)

			if alpha <= 0.001:
				if solid_neighbors >= 6:
					alpha = 0.72
				elif solid_neighbors >= 3:
					alpha = 0.18
			elif visible_neighbors == 0:
				alpha = 0.0
			elif alpha < 0.30 and visible_neighbors < 2:
				alpha = 0.0

			cleaned.set_pixel(
					x,
					y,
					Color(clampf(alpha, 0.0, 1.0), 0.0, 0.0, 1.0))
	return _remove_isolated_mask_pixels(cleaned)


func _fill_confirmed_gold_holes(mask: Image) -> Image:
	# The flattened source contains four pale circular highlights inside the
	# thick hand-left arc. Hue extraction mistakes them for paper. Their
	# bounds are fixed art details, so patch only those confirmed components
	# instead of closing the ring's intentional brush gaps globally.
	var patched := mask.duplicate()
	for patch_rect: Rect2i in GOLD_HOLE_PATCH_RECTS:
		for y: int in range(
				patch_rect.position.y,
				patch_rect.end.y):
			for x: int in range(
					patch_rect.position.x,
					patch_rect.end.x):
				if not _is_inside_confirmed_gold_hole(x, y):
					continue
				patched.set_pixel(
						x,
						y,
						Color(1.0, 0.0, 0.0, 1.0))
	return patched


func _is_inside_confirmed_gold_hole(x: int, y: int) -> bool:
	for patch_rect: Rect2i in GOLD_HOLE_PATCH_RECTS:
		if not patch_rect.has_point(Vector2i(x, y)):
			continue
		var center := Vector2(patch_rect.position) + (
				Vector2(patch_rect.size) - Vector2.ONE) * 0.5
		var radius := Vector2(patch_rect.size) * 0.5
		var normalized := (
				(Vector2(float(x), float(y)) - center)
				/ radius)
		return normalized.length_squared() <= 1.0
	return false


func _recover_dense_highlights(
		mask: Image,
		iterations: int,
		solid_threshold: float,
		opaque_neighbor_count: int,
		soft_neighbor_count: int,
) -> Image:
	# Neutral highlights authored inside the flattened blue/gold artwork have
	# the same hue family as the paper. Recover only pixels enclosed by dense
	# foreground on opposing sides, so the inner highlight stays intact
	# without growing the outer silhouette into the former paper matte.
	var current := mask
	for iteration: int in iterations:
		var recovered := _create_transparent_image(
				current.get_width(),
				current.get_height())
		for y: int in current.get_height():
			for x: int in current.get_width():
				var alpha := current.get_pixel(x, y).r
				if alpha <= 0.05 and _is_enclosed_mask_gap(
						current,
						x,
						y,
						solid_threshold):
					var strong_neighbors := _count_mask_neighbors_radius(
							current,
							x,
							y,
							2,
							solid_threshold)
					if strong_neighbors >= opaque_neighbor_count:
						alpha = 1.0
					elif strong_neighbors >= soft_neighbor_count:
						alpha = 0.42
				recovered.set_pixel(
						x,
						y,
						Color(alpha, 0.0, 0.0, 1.0))
		current = recovered
	return current


func _is_enclosed_mask_gap(
		mask: Image,
		x: int,
		y: int,
		threshold: float,
) -> bool:
	for distance: int in range(1, 4):
		if (
				_mask_is_solid(mask, x - distance, y, threshold)
				and _mask_is_solid(mask, x + distance, y, threshold)
		):
			return true
		if (
				_mask_is_solid(mask, x, y - distance, threshold)
				and _mask_is_solid(mask, x, y + distance, threshold)
		):
			return true
		if (
				_mask_is_solid(
						mask,
						x - distance,
						y - distance,
						threshold)
				and _mask_is_solid(
						mask,
						x + distance,
						y + distance,
						threshold)
		):
			return true
		if (
				_mask_is_solid(
						mask,
						x + distance,
						y - distance,
						threshold)
				and _mask_is_solid(
						mask,
						x - distance,
						y + distance,
						threshold)
		):
			return true
	return false


func _mask_is_solid(
		mask: Image,
		x: int,
		y: int,
		threshold: float,
) -> bool:
	if (
			x < 0
			or y < 0
			or x >= mask.get_width()
			or y >= mask.get_height()
	):
		return false
	return mask.get_pixel(x, y).r > threshold


func _count_mask_neighbors_radius(
		mask: Image,
		x: int,
		y: int,
		radius: int,
		threshold: float,
) -> int:
	var count := 0
	for offset_y: int in range(-radius, radius + 1):
		for offset_x: int in range(-radius, radius + 1):
			if offset_x == 0 and offset_y == 0:
				continue
			if _mask_is_solid(
					mask,
					x + offset_x,
					y + offset_y,
					threshold):
				count += 1
	return count


func _remove_isolated_mask_pixels(mask: Image) -> Image:
	var cleaned := _create_transparent_image(
			mask.get_width(),
			mask.get_height())
	for y: int in mask.get_height():
		for x: int in mask.get_width():
			var alpha := mask.get_pixel(x, y).r
			if (
					alpha > 0.05
					and _count_mask_neighbors(mask, x, y, 0.05) == 0
			):
				alpha = 0.0
			cleaned.set_pixel(
					x,
					y,
					Color(alpha, 0.0, 0.0, 1.0))
	return cleaned


func _count_mask_neighbors(
		mask: Image,
		x: int,
		y: int,
		threshold: float,
) -> int:
	var count := 0
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var sample_x := x + offset_x
			var sample_y := y + offset_y
			if (
					sample_x < 0
					or sample_y < 0
					or sample_x >= mask.get_width()
					or sample_y >= mask.get_height()
			):
				continue
			if mask.get_pixel(sample_x, sample_y).r > threshold:
				count += 1
	return count


func _recover_clean_layer(
		source: Image,
		mask: Image,
		search_radius: int,
		blue_layer: bool,
) -> Image:
	var layer := _create_transparent_image(
			source.get_width(),
			source.get_height())
	for y: int in source.get_height():
		for x: int in source.get_width():
			var alpha := mask.get_pixel(x, y).r
			if alpha <= 0.001:
				continue

			var source_color := source.get_pixel(x, y)
			var clean_color := source_color
			var source_strength := (
					_blue_mask_alpha(source_color)
					if blue_layer
					else _gold_mask_alpha(source_color))
			var confirmed_gold_hole := (
					not blue_layer
					and _is_inside_confirmed_gold_hole(x, y))
			if (
					alpha < 0.98
					or source_strength < 0.55
					or confirmed_gold_hole
			):
				var interior_color := _nearest_interior_color(
						source,
						mask,
						x,
						y,
						search_radius,
						source_color,
						blue_layer)
				if confirmed_gold_hole:
					clean_color = interior_color
				elif source_strength < 0.55:
					var source_luminance := _color_luminance(
							source_color)
					var interior_luminance := _color_luminance(
							interior_color)
					var highlight_amount := clampf(
							(
								source_luminance
								- interior_luminance
							) * 0.42,
							0.0,
							0.20 if blue_layer else 0.12)
					clean_color = interior_color.lightened(
							highlight_amount)
				else:
					var source_mix := smoothstep(0.86, 0.99, alpha)
					clean_color = interior_color.lerp(
							source_color,
							source_mix)

			clean_color.a = alpha
			layer.set_pixel(x, y, clean_color)
	return layer


func _nearest_interior_color(
		source: Image,
		mask: Image,
		x: int,
		y: int,
		radius: int,
		fallback: Color,
		blue_layer: bool,
) -> Color:
	var best_color := fallback
	var best_score := -1.0
	for offset_y: int in range(-radius, radius + 1):
		for offset_x: int in range(-radius, radius + 1):
			var sample_x := x + offset_x
			var sample_y := y + offset_y
			if (
					sample_x < 0
					or sample_y < 0
					or sample_x >= mask.get_width()
					or sample_y >= mask.get_height()
			):
				continue
			var candidate_alpha := mask.get_pixel(
					sample_x,
					sample_y).r
			if candidate_alpha < 0.72:
				continue
			var candidate_color := source.get_pixel(
					sample_x,
					sample_y)
			if (
					not blue_layer
					and _is_inside_confirmed_gold_hole(
							sample_x,
							sample_y)
			):
				continue
			var candidate_strength := (
					_blue_mask_alpha(candidate_color)
					if blue_layer
					else _gold_mask_alpha(candidate_color))
			if candidate_strength < 0.55:
				continue
			var distance_penalty := Vector2(
					float(offset_x),
					float(offset_y)).length() * 0.025
			var score := candidate_alpha - distance_penalty
			if score > best_score:
				best_score = score
				best_color = candidate_color
	return best_color


func _color_luminance(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114


func _build_blue_derivative_layers(
		layers: Dictionary[String, Image],
) -> void:
	var blue_base: Image = layers["blue_base"]
	var blue_mid := _create_transparent_image(
			blue_base.get_width(),
			blue_base.get_height())
	var blue_light := _create_transparent_image(
			blue_base.get_width(),
			blue_base.get_height())
	var blue_foreground := _create_transparent_image(
			blue_base.get_width(),
			blue_base.get_height())

	for y: int in blue_base.get_height():
		for x: int in blue_base.get_width():
			var color := blue_base.get_pixel(x, y)
			if color.a <= 0.001:
				continue
			var luminance := _color_luminance(color)

			var mid_color := color
			mid_color.a *= (
					smoothstep(0.16, 0.34, luminance) * 0.56)
			blue_mid.set_pixel(x, y, mid_color)

			var light_color := color.lightened(0.08)
			light_color.a = (
					color.a
					* smoothstep(0.42, 0.60, luminance)
					* 0.68)
			blue_light.set_pixel(x, y, light_color)

			var spatial_mask := _foreground_spatial_mask(
					x,
					y,
					blue_base.get_width(),
					blue_base.get_height())
			var foreground_color := color
			foreground_color.a *= (
					spatial_mask
					* smoothstep(0.10, 0.65, color.a))
			blue_foreground.set_pixel(
					x,
					y,
					foreground_color)

	layers["blue_mid"] = blue_mid
	layers["blue_light"] = blue_light
	layers["blue_foreground"] = blue_foreground


func _foreground_spatial_mask(
		x: int,
		y: int,
		width: int,
		height: int,
) -> float:
	var uv := Vector2(
			float(x) / maxf(float(width - 1), 1.0),
			float(y) / maxf(float(height - 1), 1.0))
	var lower_left := (
			(1.0 - smoothstep(0.30, 0.56, uv.x))
			* smoothstep(0.62, 0.91, uv.y))
	var upper_right := (
			smoothstep(0.72, 0.94, uv.x)
			* (1.0 - smoothstep(0.12, 0.38, uv.y)))
	return maxf(lower_left, upper_right)


func _count_visible_pixels(image: Image) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				count += 1
	return count


func _validate_clean_layers(
		layers: Dictionary[String, Image],
		counts: Dictionary[String, int],
) -> bool:
	var blue_contamination := _count_edge_contamination(
			layers["blue_base"],
			true)
	var gold_contamination := _count_edge_contamination(
			layers["gold_combined"],
			false)
	var isolated_blue := _count_isolated_pixels(
			layers["blue_base"])
	var foreground_count: int = counts["blue_foreground"]
	var base_count: int = counts["blue_base"]

	if blue_contamination > 0:
		push_error(
			"Blue mask retained %d paper-contaminated edge pixels."
			% blue_contamination)
	if gold_contamination > 0:
		push_error(
			"Gold mask retained %d paper-contaminated edge pixels."
			% gold_contamination)
	if isolated_blue > 0:
		push_error(
			"Blue mask retained %d isolated pixels."
			% isolated_blue)
	if foreground_count <= 0 or foreground_count >= base_count:
		push_error(
			"Dedicated foreground brush mask is invalid: %d/%d."
			% [foreground_count, base_count])
	return (
			blue_contamination == 0
			and gold_contamination == 0
			and isolated_blue == 0
			and foreground_count > 0
			and foreground_count < base_count)


func _count_edge_contamination(
		image: Image,
		blue_layer: bool,
) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.02 or color.a >= 0.92:
				continue
			if blue_layer:
				if minf(color.b - color.r, color.b - color.g) <= 0.001:
					count += 1
			elif (
					color.s < 0.30
					or color.h <= 0.03
					or color.h >= 0.205
			):
				count += 1
	return count


func _count_isolated_pixels(image: Image) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a <= 0.05:
				continue
			var has_neighbor := false
			for offset_y: int in range(-1, 2):
				for offset_x: int in range(-1, 2):
					if offset_x == 0 and offset_y == 0:
						continue
					var sample_x := x + offset_x
					var sample_y := y + offset_y
					if (
							sample_x < 0
							or sample_y < 0
							or sample_x >= image.get_width()
							or sample_y >= image.get_height()
					):
						continue
					if image.get_pixel(sample_x, sample_y).a > 0.05:
						has_neighbor = true
			if not has_neighbor:
				count += 1
	return count


func _paint_gold_flow_map(
		flow_image: Image,
		width: int,
		height: int,
) -> void:
	for y: int in height:
		for x: int in width:
			var position := Vector2(float(x), float(y))
			var delta := position - RING_CENTER
			var radius := delta.length()
			var direction := Vector2.ZERO
			var flow_region := 0.0
			var phase := 0.0

			if radius <= 226.0:
				direction = GOLD_FLOW_DIRECTION.normalized()
				flow_region = 0.35
				phase = fposmod(
						delta.dot(direction) / 452.0 + 1.0,
						1.0)
			elif (
					radius <= 470.0
					and delta.y < -44.0
					and delta.x < 96.0
			):
				direction = GOLD_FLOW_DIRECTION.normalized()
				flow_region = 1.0
				phase = clampf(
						(delta.dot(direction) + 44.0) / 426.0,
						0.0,
						1.0)
			else:
				continue

			var encoded_direction := direction * 0.5 + Vector2(0.5, 0.5)
			flow_image.set_pixel(
					x,
					y,
					Color(
						encoded_direction.x,
						encoded_direction.y,
						flow_region,
						phase))

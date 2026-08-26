extends SceneTree

const OUTPUT_ROOT := "res://assets/scenes/scene7/"
var CONFIGS := {
	"midground_center": {
		"source": "scene7_midground_center.png",
		"groups": [
			PackedVector2Array([
				Vector2(0.08, 0.02), Vector2(0.32, 0.02),
				Vector2(0.37, 0.25), Vector2(0.35, 0.43),
				Vector2(0.18, 0.40), Vector2(0.07, 0.22),
			]),
			PackedVector2Array([
				Vector2(0.32, 0.00), Vector2(0.43, 0.00),
				Vector2(0.48, 0.25), Vector2(0.41, 0.43),
				Vector2(0.35, 0.43), Vector2(0.37, 0.25),
			]),
			PackedVector2Array([
				Vector2(0.43, 0.02), Vector2(0.58, 0.04),
				Vector2(0.64, 0.20), Vector2(0.57, 0.42),
				Vector2(0.41, 0.46), Vector2(0.48, 0.25),
			]),
		],
	},
	"midground_left": {
		"source": "scene7_midground_left.png",
		"groups": [
			PackedVector2Array([
				# The old group sat mostly left of the visible viewport.  This
				# polygon isolates the first clear terminal tuft inside the frame.
				Vector2(0.33, 0.57), Vector2(0.44, 0.56),
				Vector2(0.60, 0.68), Vector2(0.62, 0.86),
				Vector2(0.48, 0.90), Vector2(0.35, 0.76),
			]),
		],
	},
	"midground_right": {
		"source": "scene7_midground_right.png",
		"groups": [
			PackedVector2Array([
				# The former x=0.72..0.98 crown was beyond the right screen
				# edge.  Use the prominent inner tuft instead.
				Vector2(0.38, 0.49), Vector2(0.46, 0.43),
				Vector2(0.61, 0.47), Vector2(0.70, 0.62),
				Vector2(0.68, 0.82), Vector2(0.54, 0.89),
				Vector2(0.39, 0.73),
			]),
		],
	},
	"foreground_left": {
		"source": "scene7_foreground_left.png",
		# The target grass grows out of an otherwise opaque bank. Keep only
		# its exposed silhouette pixels so the bank itself never becomes a
		# moving rectangular patch.
		"boundary_depth": 6,
		"groups": [
			PackedVector2Array([
				# Two ordinary grass crowns immediately right of the luminous
				# tuft.  Their roots remain outside the masks and stay static.
				Vector2(0.46, 0.74), Vector2(0.54, 0.72),
				Vector2(0.62, 0.80), Vector2(0.63, 0.88),
				Vector2(0.57, 0.92), Vector2(0.49, 0.84),
			]),
			PackedVector2Array([
				Vector2(0.59, 0.76), Vector2(0.66, 0.74),
				Vector2(0.75, 0.82), Vector2(0.75, 0.89),
				Vector2(0.69, 0.93), Vector2(0.62, 0.87),
			]),
		],
	},
}


func _initialize() -> void:
	var failed := false
	for output_name: String in CONFIGS:
		var config: Dictionary = CONFIGS[output_name]
		var source_path := OUTPUT_ROOT + String(config["source"])
		var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		if source == null or source.is_empty():
			push_error("Could not load Scene7 branch source: %s" % source_path)
			failed = true
			continue
		var mask := _build_mask(
				source,
				config["groups"],
				int(config.get("boundary_depth", 0)))
		var output_path := OUTPUT_ROOT + "scene7_branch_mask_%s.png" % output_name
		var error := mask.save_png(ProjectSettings.globalize_path(output_path))
		if error != OK:
			push_error("Could not save Scene7 branch mask: %s" % output_path)
			failed = true
			continue
		print("SCENE7_BRANCH_MASK: ", output_name,
				" size=", mask.get_size(),
				" channel_pixels=", _channel_counts(mask))
		var underpaint := _build_underpaint(source, mask)
		var underpaint_path := OUTPUT_ROOT \
				+ "scene7_branch_underpaint_%s.png" % output_name
		error = underpaint.save_png(
				ProjectSettings.globalize_path(underpaint_path))
		if error != OK:
			push_error("Could not save Scene7 branch underpaint: %s" \
					% underpaint_path)
			failed = true
		else:
			print("SCENE7_BRANCH_UNDERPAINT: ", output_name,
					" pixels=", _count_opaque(underpaint))
	quit(1 if failed else 0)


func _build_mask(source: Image, groups: Array, boundary_depth: int) -> Image:
	var mask := Image.create(
			source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	mask.fill(Color(0.0, 0.0, 0.0, 0.0))
	var image_size := Vector2(source.get_size())
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			if source.get_pixel(x, y).a <= 0.08:
				continue
			if boundary_depth > 0 \
					and not _near_transparency(source, x, y, boundary_depth):
				continue
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / image_size
			for group_index: int in range(groups.size()):
				if Geometry2D.is_point_in_polygon(uv, groups[group_index]):
					var channel := Color(0.0, 0.0, 0.0, 1.0)
					if group_index == 0:
						channel.r = 1.0
					elif group_index == 1:
						channel.g = 1.0
					else:
						channel.b = 1.0
					mask.set_pixel(x, y, channel)
					break
	return mask


func _near_transparency(
		source: Image, center_x: int, center_y: int, radius: int) -> bool:
	for sample_y: int in range(
			maxi(0, center_y - radius),
			mini(source.get_height(), center_y + radius + 1)):
		for sample_x: int in range(
				maxi(0, center_x - radius),
				mini(source.get_width(), center_x + radius + 1)):
			var delta := Vector2i(sample_x - center_x, sample_y - center_y)
			if delta.length_squared() > radius * radius:
				continue
			if source.get_pixel(sample_x, sample_y).a <= 0.08:
				return true
	return false


func _channel_counts(mask: Image) -> Vector3i:
	var counts := Vector3i.ZERO
	for y: int in range(mask.get_height()):
		for x: int in range(mask.get_width()):
			var color := mask.get_pixel(x, y)
			if color.r >= 0.5:
				counts.x += 1
			elif color.g >= 0.5:
				counts.y += 1
			elif color.b >= 0.5:
				counts.z += 1
	return counts


func _build_underpaint(source: Image, mask: Image) -> Image:
	var underpaint := Image.create_empty(
			source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	underpaint.fill(Color.TRANSPARENT)
	for y: int in source.get_height():
		for x: int in source.get_width():
			var source_color := source.get_pixel(x, y)
			if source_color.a <= 0.08 or mask.get_pixel(x, y).a <= 0.5:
				continue
			var fill := _nearest_static_foliage(source, mask, x, y)
			if fill.a <= 0.0:
				# Outer terminal pixels can be farther from the stationary trunk
				# than the search radius. Keep a darkened authored pixel there;
				# otherwise rotation would expose the background again.
				fill = source_color
			# Hidden canopy should support the moving leaves, not compete with
			# them.  Preserve the authored palette while keeping it one value
			# step darker than the exposed crown.
			fill.r *= 0.86
			fill.g *= 0.86
			fill.b *= 0.86
			fill.a = source_color.a
			underpaint.set_pixel(x, y, fill)
	return underpaint


func _nearest_static_foliage(
		source: Image, mask: Image, center_x: int, center_y: int) -> Color:
	const SAMPLE_RADIUS := 18
	var nearest_score := INF
	var nearest := Color.TRANSPARENT
	for sample_y: int in range(
			maxi(0, center_y - SAMPLE_RADIUS),
			mini(source.get_height(), center_y + SAMPLE_RADIUS + 1)):
		for sample_x: int in range(
				maxi(0, center_x - SAMPLE_RADIUS),
				mini(source.get_width(), center_x + SAMPLE_RADIUS + 1)):
			if mask.get_pixel(sample_x, sample_y).a > 0.5:
				continue
			var candidate := source.get_pixel(sample_x, sample_y)
			if candidate.a <= 0.5:
				continue
			var delta := Vector2i(sample_x - center_x, sample_y - center_y)
			var distance_squared := float(delta.length_squared())
			if distance_squared > SAMPLE_RADIUS * SAMPLE_RADIUS:
				continue
			var value := maxf(candidate.r, maxf(candidate.g, candidate.b))
			var score := distance_squared + maxf(0.0, value - 0.48) * 36.0
			if score >= nearest_score:
				continue
			nearest_score = score
			nearest = candidate
	return nearest


func _count_opaque(image: Image) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			count += int(image.get_pixel(x, y).a > 0.08)
	return count

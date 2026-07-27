extends SceneTree
## Extract a foreground contact slice from the approved single ridge asset.
## The slice uses the exact Scene2 transforms and only keeps authored rock
## pixels that touch the waterfall banks or its two terrain ledges.

const SOURCE_PATH := "res://assets/scenes/scene2/scene2_waterfall_ridge.png"
const OUTPUT_PATH := "res://assets/scenes/scene2/scene2_waterfall_ridge_contact.png"

const RIDGE_RECT := Rect2(88.0, -70.0, 896.0, 976.0)
const WATERFALL_RECT := Rect2(334.0, -152.0, 720.0, 1216.0)
const TOP_Y := 0.12
const BOTTOM_Y := 0.86
const STEP_ONE := 0.28
const STEP_TWO := 0.71
const LEFT_EDGES := Vector3(55.862, 108.276, 210.0)
const RIGHT_EDGES := Vector3(465.0, 559.828, 600.0)


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if source == null:
		push_error("Could not load Scene2 waterfall ridge: %s" % SOURCE_PATH)
		quit(1)
		return

	source.convert(Image.FORMAT_RGBA8)
	var width := source.get_width()
	var height := source.get_height()
	var output := Image.create(
			width,
			height,
			false,
			Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var contact_mask := PackedByteArray()
	contact_mask.resize(width * height)
	contact_mask.fill(0)

	for y: int in height:
		for x: int in width:
			var color := source.get_pixel(x, y)
			if color.a < 0.08:
				continue

			var scene_position := RIDGE_RECT.position + Vector2(
					(float(x) + 0.5) / float(width)
							* RIDGE_RECT.size.x,
					(float(y) + 0.5) / float(height)
							* RIDGE_RECT.size.y)
			var waterfall_position := scene_position - WATERFALL_RECT.position
			var normalized_y := waterfall_position.y / WATERFALL_RECT.size.y
			if normalized_y < TOP_Y or normalized_y > BOTTOM_Y:
				continue

			var fall_y := (normalized_y - TOP_Y) / (BOTTOM_Y - TOP_Y)
			var tier := 0
			if fall_y >= STEP_TWO:
				tier = 2
			elif fall_y >= STEP_ONE:
				tier = 1
			var left_edge := LEFT_EDGES[tier]
			var right_edge := RIGHT_EDGES[tier]
			if waterfall_position.x < left_edge or waterfall_position.x > right_edge:
				continue

			var bank_distance := minf(
					waterfall_position.x - left_edge,
					right_edge - waterfall_position.x)
			var near_bank := bank_distance <= 34.0

			var first_ledge_y := (
					TOP_Y + STEP_ONE * (BOTTOM_Y - TOP_Y)
			) * WATERFALL_RECT.size.y
			var second_ledge_y := (
					TOP_Y + STEP_TWO * (BOTTOM_Y - TOP_Y)
			) * WATERFALL_RECT.size.y
			var near_first_ledge := absf(
					waterfall_position.y - first_ledge_y) <= 22.0
			var near_second_ledge := absf(
					waterfall_position.y - second_ledge_y) <= 26.0

			var first_shoulder := (
					waterfall_position.x <= LEFT_EDGES.y + 34.0
					or waterfall_position.x >= RIGHT_EDGES.x - 26.0)
			var second_shoulder := (
					waterfall_position.x <= LEFT_EDGES.z + 38.0
					or waterfall_position.x >= RIGHT_EDGES.y - 28.0)
			var source_throat := (
					fall_y < 0.13
					and bank_distance <= 54.0)

			if not (
					near_bank
					or source_throat
					or (near_first_ledge and first_shoulder)
					or (near_second_ledge and second_shoulder)):
				continue
			contact_mask[y * width + x] = 1

	# Remove only tiny detached cut fragments. The long authored bank contacts
	# remain intact; two- or three-pixel interior components are the black
	# rectangular specks that read as source-art errors at 8x display scale.
	var connected_mask := _remove_small_components(
			contact_mask,
			width,
			height,
			8)

	# One source-pixel dilation gives every enlarged contact block a minimum
	# two-cell attachment whenever authored ridge pixels are available.
	var expanded_mask := connected_mask.duplicate()
	for y: int in height:
		for x: int in width:
			if connected_mask[y * width + x] == 0:
				continue
			for offset: Vector2i in [
				Vector2i(-1, 0),
				Vector2i(1, 0),
				Vector2i(0, -1),
				Vector2i(0, 1),
			]:
				var neighbor := Vector2i(x, y) + offset
				if (
						neighbor.x < 0
						or neighbor.y < 0
						or neighbor.x >= width
						or neighbor.y >= height):
					continue
				if source.get_pixelv(neighbor).a >= 0.08:
					expanded_mask[neighbor.y * width + neighbor.x] = 1

	# Close one-cell holes caused by the cut itself. Value 2 marks underpaint:
	# it receives a neighboring rock color even when the source pixel was
	# transparent, preventing the same background flash seen in branch cuts.
	var closed_mask := expanded_mask.duplicate()
	for y: int in range(1, height - 1):
		for x: int in range(1, width - 1):
			var index := y * width + x
			if expanded_mask[index] != 0:
				continue
			var horizontal_bridge := (
					expanded_mask[index - 1] != 0
					and expanded_mask[index + 1] != 0)
			var vertical_bridge := (
					expanded_mask[index - width] != 0
					and expanded_mask[index + width] != 0)
			var cardinal_neighbors := (
					int(expanded_mask[index - 1] != 0)
					+ int(expanded_mask[index + 1] != 0)
					+ int(expanded_mask[index - width] != 0)
					+ int(expanded_mask[index + width] != 0))
			if horizontal_bridge or vertical_bridge or cardinal_neighbors >= 3:
				closed_mask[index] = 2

	var kept_pixels := 0
	var underpaint_pixels := 0
	for y: int in height:
		for x: int in width:
			var mask_value := closed_mask[y * width + x]
			if mask_value == 0:
				continue
			var color := source.get_pixel(x, y)
			if mask_value == 2 or color.a < 0.08:
				color = _nearest_contact_color(
						source,
						closed_mask,
						x,
						y,
						width,
						height)
				underpaint_pixels += 1
			output.set_pixel(x, y, _grade_contact_color(color))
			kept_pixels += 1

	var error := output.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save waterfall contact slice: %s" % error)
		quit(1)
		return

	print(
			"prepared waterfall contact slice | kept=%d | underpaint=%d"
			% [kept_pixels, underpaint_pixels])
	quit()


func _remove_small_components(
		mask: PackedByteArray,
		width: int,
		height: int,
		minimum_pixels: int) -> PackedByteArray:
	var result := mask.duplicate()
	var visited := PackedByteArray()
	visited.resize(width * height)
	visited.fill(0)
	var neighbors: Array[Vector2i] = [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
		Vector2i(1, 1),
	]

	for y: int in height:
		for x: int in width:
			var start_index := y * width + x
			if mask[start_index] == 0 or visited[start_index] != 0:
				continue
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			var component: Array[int] = []
			visited[start_index] = 1
			var queue_index := 0
			while queue_index < queue.size():
				var point := queue[queue_index]
				queue_index += 1
				var point_index := point.y * width + point.x
				component.append(point_index)
				for offset: Vector2i in neighbors:
					var neighbor := point + offset
					if (
							neighbor.x < 0
							or neighbor.y < 0
							or neighbor.x >= width
							or neighbor.y >= height):
						continue
					var neighbor_index := neighbor.y * width + neighbor.x
					if (
							mask[neighbor_index] == 0
							or visited[neighbor_index] != 0):
						continue
					visited[neighbor_index] = 1
					queue.append(neighbor)
			if component.size() < minimum_pixels:
				for point_index: int in component:
					result[point_index] = 0
	return result


func _neighbor_count(
		mask: PackedByteArray,
		x: int,
		y: int,
		width: int,
		height: int) -> int:
	var count := 0
	for offset: Vector2i in [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
		Vector2i(1, 1),
	]:
		var neighbor := Vector2i(x, y) + offset
		if (
				neighbor.x >= 0
				and neighbor.y >= 0
				and neighbor.x < width
				and neighbor.y < height
				and mask[neighbor.y * width + neighbor.x] != 0):
			count += 1
	return count


func _nearest_contact_color(
		source: Image,
		mask: PackedByteArray,
		x: int,
		y: int,
		width: int,
		height: int) -> Color:
	for radius: int in range(1, 3):
		for sample_y: int in range(y - radius, y + radius + 1):
			for sample_x: int in range(x - radius, x + radius + 1):
				if (
						sample_x < 0
						or sample_y < 0
						or sample_x >= width
						or sample_y >= height
						or mask[sample_y * width + sample_x] == 0):
					continue
				var sample := source.get_pixel(sample_x, sample_y)
				if sample.a >= 0.08:
					return sample
	return Color(0.08, 0.2, 0.24, 1.0)


func _grade_contact_color(color: Color) -> Color:
	var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var contact_color := color
	# Preserve the approved cut geometry, but lift only the near-black source
	# pixels that read as stray rectangular errors when displayed at 8x.
	if luminance < 0.20:
		var dark_lift := clampf((0.20 - luminance) / 0.20, 0.0, 1.0)
		contact_color = color.lerp(
				Color(0.18, 0.30, 0.36, color.a),
				dark_lift * 0.78)
	if luminance > 0.58:
		contact_color = color.lerp(
				Color(0.16, 0.29, 0.31, color.a),
				clampf((luminance - 0.58) / 0.30, 0.45, 0.78))
	var contact_luminance := (
			contact_color.r * 0.299
			+ contact_color.g * 0.587
			+ contact_color.b * 0.114)
	if contact_luminance > 0.48:
		var scale := 0.48 / contact_luminance
		contact_color = Color(
				contact_color.r * scale,
				contact_color.g * scale,
				contact_color.b * scale,
				maxf(contact_color.a, 0.92))
	return contact_color

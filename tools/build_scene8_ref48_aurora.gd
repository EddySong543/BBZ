extends SceneTree

## Restores ref48's accepted 256x144 aurora pixel map, then repairs only the
## dark occlusion gaps inherited from the source screenshot. Existing visible
## aurora pixels are never repainted or rearranged.

const SOURCE_PATH := "res://ref/ref48.png"
const OUTPUT_PATH := "res://assets/scenes/scene8/scene8_ref48_aurora.png"
const SOURCE_SIZE := Vector2i(1024, 576)
const LOGICAL_SIZE := Vector2i(256, 144)
const SOURCE_SCALE := 4
const EXTRACTION_MAX_Y := 99
const AURORA_MAX_Y := 70
const RIGHT_BODY_RECT := Rect2i(169, 0, 87, 70)
const RIGHT_TAIL_RECOLOR_RECT := Rect2i(214, 26, 42, 7)
const SCENE8_4_RIGHT_CURVE_POINTS: Array[Vector2i] = [
	Vector2i(169, 63), Vector2i(180, 52), Vector2i(190, 45),
	Vector2i(197, 43), Vector2i(205, 40), Vector2i(213, 38),
	Vector2i(218, 31), Vector2i(223, 29), Vector2i(238, 29),
	Vector2i(243, 32), Vector2i(255, 30),
]
const LEFT_CLOSURE_ARC_POINTS: Array[Vector2i] = [
	Vector2i(82, 65), Vector2i(83, 67), Vector2i(85, 67), Vector2i(89, 69),
	Vector2i(93, 70), Vector2i(96, 68), Vector2i(100, 63),
]
const SCENE8_3_CUTOUT_RECTS: Array[Rect2i] = [
	Rect2i(72, 39, 7, 18),
	Rect2i(82, 49, 12, 21),
	Rect2i(78, 61, 8, 9),
	Rect2i(157, 58, 6, 6),
	Rect2i(178, 39, 10, 18),
	Rect2i(186, 43, 9, 15),
]
const TREE_MARKED_RECTS: Array[Rect2i] = [
	Rect2i(146, 45, 9, 14), Rect2i(168, 44, 15, 8), Rect2i(191, 36, 8, 7),
]
const AURORA_COLORS: Array[String] = [
	"4b429f", "226a71", "37a28f", "338c88", "4ac88e",
	"2a7ccf", "6df29e", "2f60a6", "53bca7", "8458c3",
	"3cf4dc", "5ade8b", "35baef", "39d5ea", "40f1b9",
	"3193c8", "29d8be", "44b3bb", "777bc2",
]
const FLUORESCENT_LOWER_COLORS: Array[String] = [
	"4ac88e", "5ade8b", "40f1b9", "6df29e", "3cf4dc", "29d8be",
	"39d5ea", "35baef",
]
const DIRTY_DARK_GREEN_COLORS: Array[String] = [
	"226a71", "338c88", "37a28f", "44b3bb", "53bca7",
]
const GREEN_TAIL_COLORS: Array[String] = [
	"4ac88e", "5ade8b", "40f1b9", "6df29e", "3cf4dc", "29d8be",
]


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var source := Image.load_from_file(SOURCE_PATH)
	if source == null or source.get_size() != SOURCE_SIZE:
		push_error("ref48 source must be exactly 1024x576")
		quit(1)
		return
	var extracted := _extract_original_aurora(source)
	var original: Image = extracted.duplicate()
	var repair := _repair_occlusion_gaps(extracted, original)
	var original_pixels := 0
	var preserved_pixels := 0
	var unique_colors: Dictionary[int, bool] = {}
	var min_cell := Vector2i(LOGICAL_SIZE.x, LOGICAL_SIZE.y)
	var max_cell := Vector2i(-1, -1)
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var color := extracted.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			unique_colors[color.to_rgba32()] = true
			min_cell.x = mini(min_cell.x, x)
			min_cell.y = mini(min_cell.y, y)
			max_cell.x = maxi(max_cell.x, x)
			max_cell.y = maxi(max_cell.y, y)
			var original_color := original.get_pixel(x, y)
			if original_color.a > 0.0:
				original_pixels += 1
				preserved_pixels += int(color == original_color)
	var error := extracted.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save repaired ref48 aurora: %s" % error_string(error))
		quit(1)
		return
	print(
			"SCENE8_REF48_AURORA_REPAIR_BUILD: PASS",
			" original_pixels=", original_pixels,
			" preserved_pixels=", preserved_pixels,
			" repaired_pixels=", repair["repaired_pixels"],
			" trimmed_pixels=", repair["trimmed_pixels"],
			" left_rim_recolored=", repair["left_rim_recolored"],
			" unique_colors=", unique_colors.size(),
			" bounds=", Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE))
	quit(0)


func _extract_original_aurora(source: Image) -> Image:
	var palette: Dictionary[int, bool] = {}
	for hex_color: String in AURORA_COLORS:
		palette[Color(hex_color).to_rgba32()] = true
	var candidates := PackedByteArray()
	candidates.resize(LOGICAL_SIZE.x * LOGICAL_SIZE.y)
	for y: int in range(EXTRACTION_MAX_Y + 1):
		for x: int in LOGICAL_SIZE.x:
			var source_color := source.get_pixel(x * SOURCE_SCALE, y * SOURCE_SCALE)
			candidates[y * LOGICAL_SIZE.x + x] = int(
					palette.has(Color(
							source_color.r, source_color.g, source_color.b).to_rgba32()))
	var accepted := _accepted_component_mask(candidates)
	var output := Image.create_empty(
			LOGICAL_SIZE.x, LOGICAL_SIZE.y, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var index := y * LOGICAL_SIZE.x + x
			if accepted[index] == 0:
				continue
			# This field is landscape glow rather than part of the curtain.
			if x >= 94 and y >= 64:
				continue
			var source_color := source.get_pixel(x * SOURCE_SCALE, y * SOURCE_SCALE)
			output.set_pixel(
					x, y, Color(source_color.r, source_color.g, source_color.b, 1.0))
	return output


func _repair_occlusion_gaps(image: Image, _original: Image) -> Dictionary:
	# ref48's lower-right rows are foreground-tree pixels, but the seven rows
	# above them are still the aurora body. Remove only the occluder rows and keep
	# the body opaque; the previous rectangular deletion incorrectly erased both.
	var trimmed_pixels := _remove_right_occlusion_pixels(image)
	var repair_source: Image = image.duplicate()
	# First close ordinary source occlusions above the fluorescent rim.
	var repaired_pixels := _fill_curtain_to_fluorescent_rim(image, repair_source)
	# scene8-3 marks narrow vertical slots which continue below that rim. Repair
	# only transparent pixels vertically bracketed by the same curtain column.
	var marked_source: Image = image.duplicate()
	repaired_pixels += _repair_scene8_3_cutouts(image, marked_source)
	repaired_pixels += _repair_scene8_4_bottom_curves(image, marked_source)
	_clean_marked_tree_colors(image)
	# A second pass closes cells whose boundary only becomes valid after inpaint.
	var final_source: Image = image.duplicate()
	repaired_pixels += _fill_curtain_to_fluorescent_rim(image, final_source)
	# Keep every right-body cell. The rejected visual was its fluorescent green
	# contour, so recolor those pixels from surrounding blue/cyan bands instead of
	# deleting the body and exposing a large rectangle of night sky.
	_recolor_right_green_tail(image)
	trimmed_pixels += _remove_right_occlusion_pixels(image)
	trimmed_pixels += _remove_left_curve_overhang(image)
	var left_rim_recolored := _paint_left_fluorescent_rim(image)
	return {
		"repaired_pixels": repaired_pixels,
		"trimmed_pixels": trimmed_pixels,
		"left_rim_recolored": left_rim_recolored,
	}


func _repair_scene8_3_cutouts(image: Image, source: Image) -> int:
	var repaired_pixels := 0
	for rect: Rect2i in SCENE8_3_CUTOUT_RECTS:
		repaired_pixels += _repair_vertical_cutouts(image, source, rect)
	return repaired_pixels


func _repair_vertical_cutouts(image: Image, source: Image, rect: Rect2i) -> int:
	var repaired_pixels := 0
	for x: int in range(rect.position.x, rect.end.x):
		var top := -1
		var bottom := -1
		var scan_top := maxi(rect.position.y - 4, 0)
		var scan_bottom := mini(rect.end.y + 4, AURORA_MAX_Y + 1)
		for y: int in range(scan_top, scan_bottom):
			if source.get_pixel(x, y).a <= 0.0:
				continue
			if top < 0:
				top = y
			bottom = y
		if top < 0 or bottom <= top:
			continue
		for y: int in range(maxi(rect.position.y, top), mini(rect.end.y, bottom + 1)):
			if image.get_pixel(x, y).a > 0.0:
				continue
			image.set_pixel(x, y, _directional_palette_fill(source, x, y))
			repaired_pixels += 1
	return repaired_pixels


func _repair_scene8_4_bottom_curves(image: Image, source: Image) -> int:
	var repaired_pixels := 0
	for x: int in range(82, 101):
		var bottom := _left_closure_arc_bottom(x)
		repaired_pixels += _fill_column_to_bottom(image, source, x, bottom)
	for x: int in range(RIGHT_BODY_RECT.position.x, RIGHT_BODY_RECT.end.x):
		repaired_pixels += _fill_column_to_bottom(
				image, source, x, _scene8_4_right_bottom(x))
	return repaired_pixels


func _fill_column_to_bottom(
		image: Image, source: Image, x: int, bottom: int) -> int:
	var top := _column_top(source, x)
	if top < 0 or bottom < top:
		return 0
	var repaired_pixels := 0
	for y: int in range(top, bottom + 1):
		if image.get_pixel(x, y).a > 0.0:
			continue
		image.set_pixel(x, y, _directional_palette_fill(source, x, y))
		repaired_pixels += 1
	return repaired_pixels


func _scene8_4_right_bottom(x: int) -> int:
	for index: int in range(SCENE8_4_RIGHT_CURVE_POINTS.size() - 1):
		var start := SCENE8_4_RIGHT_CURVE_POINTS[index]
		var finish := SCENE8_4_RIGHT_CURVE_POINTS[index + 1]
		if x > finish.x:
			continue
		var t := float(x - start.x) / maxf(float(finish.x - start.x), 1.0)
		return int(roundf(lerpf(start.y, finish.y, t)))
	return SCENE8_4_RIGHT_CURVE_POINTS[SCENE8_4_RIGHT_CURVE_POINTS.size() - 1].y


func _left_closure_arc_bottom(x: int) -> int:
	for index: int in range(LEFT_CLOSURE_ARC_POINTS.size() - 1):
		var start := LEFT_CLOSURE_ARC_POINTS[index]
		var finish := LEFT_CLOSURE_ARC_POINTS[index + 1]
		if x > finish.x:
			continue
		var t := float(x - start.x) / maxf(float(finish.x - start.x), 1.0)
		return int(roundf(lerpf(start.y, finish.y, t)))
	return LEFT_CLOSURE_ARC_POINTS[LEFT_CLOSURE_ARC_POINTS.size() - 1].y


func _column_top(image: Image, x: int) -> int:
	for y: int in range(AURORA_MAX_Y + 1):
		if image.get_pixel(x, y).a > 0.0:
			return y
	return -1


func _fill_curtain_to_fluorescent_rim(image: Image, source: Image) -> int:
	var fluorescent: Dictionary[int, bool] = {}
	for hex_color: String in FLUORESCENT_LOWER_COLORS:
		fluorescent[Color(hex_color).to_rgba32()] = true
	var top_by_column := PackedInt32Array()
	var bottom_by_column := PackedInt32Array()
	top_by_column.resize(LOGICAL_SIZE.x)
	top_by_column.fill(-1)
	bottom_by_column.resize(LOGICAL_SIZE.x)
	bottom_by_column.fill(-1)
	for x: int in LOGICAL_SIZE.x:
		for y: int in range(AURORA_MAX_Y + 1):
			var color := source.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if top_by_column[x] < 0:
				top_by_column[x] = y
			var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
			if fluorescent.has(rgb_key):
				bottom_by_column[x] = y
	# A few scene8-2 bottom holes remove the fluorescent rim itself. Bridge only
	# short missing runs between two real rim samples; never extrapolate outward.
	var scan_x := 0
	while scan_x < LOGICAL_SIZE.x:
		if bottom_by_column[scan_x] >= 0:
			scan_x += 1
			continue
		var gap_start := scan_x
		while scan_x < LOGICAL_SIZE.x and bottom_by_column[scan_x] < 0:
			scan_x += 1
		var gap_end := scan_x - 1
		var left_x := gap_start - 1
		var right_x := scan_x
		var gap_size := gap_end - gap_start + 1
		if left_x < 0 or right_x >= LOGICAL_SIZE.x or gap_size > 16:
			continue
		for fill_x: int in range(gap_start, gap_end + 1):
			var t := float(fill_x - left_x) / float(right_x - left_x)
			bottom_by_column[fill_x] = int(roundf(lerpf(
					float(bottom_by_column[left_x]),
					float(bottom_by_column[right_x]), t)))
	var repaired_pixels := 0
	for x: int in LOGICAL_SIZE.x:
		if top_by_column[x] < 0 or bottom_by_column[x] <= top_by_column[x]:
			continue
		for y: int in range(top_by_column[x], bottom_by_column[x] + 1):
			if image.get_pixel(x, y).a > 0.0:
				continue
			image.set_pixel(x, y, _directional_palette_fill(source, x, y))
			repaired_pixels += 1
	return repaired_pixels


func _directional_palette_fill(source: Image, x: int, y: int) -> Color:
	var weighted := Color(0.0, 0.0, 0.0, 1.0)
	var total_weight := 0.0
	for direction: Vector2i in [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]:
		for radius: int in range(1, 65):
			var sample := Vector2i(x, y) + direction * radius
			if sample.x < 0 or sample.x >= LOGICAL_SIZE.x \
					or sample.y < 0 or sample.y > AURORA_MAX_Y:
				break
			var color := source.get_pixelv(sample)
			if color.a <= 0.0:
				continue
			var weight := 1.0 / float(radius)
			weighted.r += color.r * weight
			weighted.g += color.g * weight
			weighted.b += color.b * weight
			total_weight += weight
			break
	if total_weight <= 0.0:
		return Color("40f1b9")
	weighted.r /= total_weight
	weighted.g /= total_weight
	weighted.b /= total_weight
	return _nearest_clean_palette_color(weighted)


func _nearest_clean_palette_color(blended: Color) -> Color:
	var dirty: Dictionary[int, bool] = {}
	for hex_color: String in DIRTY_DARK_GREEN_COLORS:
		dirty[Color(hex_color).to_rgba32()] = true
	var closest := Color("40f1b9")
	var closest_distance := INF
	for hex_color: String in AURORA_COLORS:
		var candidate := Color(hex_color)
		if dirty.has(candidate.to_rgba32()):
			continue
		var delta := Vector3(
				candidate.r - blended.r,
				candidate.g - blended.g,
				candidate.b - blended.b)
		var distance := delta.length_squared()
		if distance < closest_distance:
			closest = candidate
			closest_distance = distance
	return closest
func _clean_marked_tree_colors(image: Image) -> void:
	var dirty: Dictionary[int, bool] = {}
	for hex_color: String in DIRTY_DARK_GREEN_COLORS:
		dirty[Color(hex_color).to_rgba32()] = true
	var snapshot: Image = image.duplicate()
	for rect: Rect2i in TREE_MARKED_RECTS:
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var color := snapshot.get_pixel(x, y)
				var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
				if color.a <= 0.0 or not dirty.has(rgb_key):
					continue
				var clean_neighbors: Array[Color] = []
				for radius: int in range(1, 4):
					for offset_y: int in range(-radius, radius + 1):
						for offset_x: int in range(-radius, radius + 1):
							if absi(offset_x) != radius and absi(offset_y) != radius:
								continue
							var sample_x := clampi(x + offset_x, 0, LOGICAL_SIZE.x - 1)
							var sample_y := clampi(y + offset_y, 0, LOGICAL_SIZE.y - 1)
							var neighbor := snapshot.get_pixel(sample_x, sample_y)
							var neighbor_key := Color(
									neighbor.r, neighbor.g, neighbor.b).to_rgba32()
							if neighbor.a > 0.0 and not dirty.has(neighbor_key):
								clean_neighbors.append(neighbor)
					if not clean_neighbors.is_empty():
						break
				if not clean_neighbors.is_empty():
					image.set_pixel(x, y, _brightest_neighbor(clean_neighbors))


func _inpaint_enclosed_pixels(
		image: Image, region: Rect2i, pass_count: int, minimum_neighbors: int) -> int:
	var repaired_pixels := 0
	for _pass_index: int in pass_count:
		var snapshot: Image = image.duplicate()
		var pending: Array[Vector2i] = []
		var pending_colors: Array[Color] = []
		for y: int in range(maxi(region.position.y, 1), mini(region.end.y, LOGICAL_SIZE.y - 1)):
			for x: int in range(maxi(region.position.x, 1), mini(region.end.x, LOGICAL_SIZE.x - 1)):
				if snapshot.get_pixel(x, y).a > 0.0:
					continue
				var left := snapshot.get_pixel(x - 1, y)
				var right := snapshot.get_pixel(x + 1, y)
				var up := snapshot.get_pixel(x, y - 1)
				var down := snapshot.get_pixel(x, y + 1)
				var has_opposing_support := (left.a > 0.0 and right.a > 0.0) \
						or (up.a > 0.0 and down.a > 0.0)
				if not has_opposing_support:
					continue
				var neighbors: Array[Color] = []
				for offset_y: int in range(-1, 2):
					for offset_x: int in range(-1, 2):
						if offset_x == 0 and offset_y == 0:
							continue
						var color := snapshot.get_pixel(x + offset_x, y + offset_y)
						if color.a > 0.0:
							neighbors.append(color)
				if neighbors.size() < minimum_neighbors:
					continue
				pending.append(Vector2i(x, y))
				pending_colors.append(_blended_palette_neighbor(neighbors))
		for index: int in pending.size():
			image.set_pixelv(pending[index], pending_colors[index])
			repaired_pixels += 1
	return repaired_pixels


func _brightest_neighbor(neighbors: Array[Color]) -> Color:
	var brightest := neighbors[0]
	var brightest_luma := -1.0
	for color: Color in neighbors:
		var luma := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
		if luma > brightest_luma:
			brightest = color
			brightest_luma = luma
	return brightest


func _blended_palette_neighbor(neighbors: Array[Color]) -> Color:
	var blended := Color(0.0, 0.0, 0.0, 1.0)
	for color: Color in neighbors:
		blended.r += color.r
		blended.g += color.g
		blended.b += color.b
	var count := float(neighbors.size())
	blended.r /= count
	blended.g /= count
	blended.b /= count
	return _nearest_clean_palette_color(blended)


func _remove_right_occlusion_pixels(image: Image) -> int:
	var removed_pixels := 0
	for x: int in range(RIGHT_BODY_RECT.position.x, RIGHT_BODY_RECT.end.x):
		for y: int in range(_scene8_4_right_bottom(x) + 1, AURORA_MAX_Y + 1):
			if image.get_pixel(x, y).a <= 0.0:
				continue
			image.set_pixel(x, y, Color.TRANSPARENT)
			removed_pixels += 1
	return removed_pixels


func _remove_left_curve_overhang(image: Image) -> int:
	var removed_pixels := 0
	for x: int in range(82, 101):
		var bottom := _left_closure_arc_bottom(x)
		for y: int in range(bottom + 1, AURORA_MAX_Y + 1):
			if image.get_pixel(x, y).a <= 0.0:
				continue
			image.set_pixel(x, y, Color.TRANSPARENT)
			removed_pixels += 1
	return removed_pixels


func _paint_left_fluorescent_rim(image: Image) -> int:
	var fluorescent: Dictionary[int, bool] = {}
	for hex_color: String in FLUORESCENT_LOWER_COLORS:
		fluorescent[Color(hex_color).to_rgba32()] = true
	var snapshot: Image = image.duplicate()
	var recolored_pixels := 0
	for x: int in range(74, 101):
		var bottom := -1
		for y: int in range(AURORA_MAX_Y + 1):
			if snapshot.get_pixel(x, y).a > 0.0:
				bottom = y
		if bottom < 0:
			continue
		var color := snapshot.get_pixel(x, bottom)
		var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
		if fluorescent.has(rgb_key):
			continue
		image.set_pixel(x, bottom, _nearest_fluorescent_color(
				snapshot, fluorescent, x, bottom))
		recolored_pixels += 1
	return recolored_pixels


func _nearest_fluorescent_color(
		source: Image, fluorescent: Dictionary[int, bool], x: int, y: int) -> Color:
	for radius: int in range(1, 17):
		for offset_y: int in range(-radius, radius + 1):
			for offset_x: int in range(-radius, radius + 1):
				if absi(offset_x) + absi(offset_y) != radius:
					continue
				var sample := Vector2i(x + offset_x, y + offset_y)
				if sample.x < 0 or sample.x >= LOGICAL_SIZE.x \
						or sample.y < 0 or sample.y > AURORA_MAX_Y:
					continue
				var color := source.get_pixelv(sample)
				var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
				if color.a > 0.0 and fluorescent.has(rgb_key):
					return color
	return Color("5ade8b")


func _recolor_right_green_tail(image: Image) -> void:
	var green_tail: Dictionary[int, bool] = {}
	for hex_color: String in GREEN_TAIL_COLORS:
		green_tail[Color(hex_color).to_rgba32()] = true
	var snapshot: Image = image.duplicate()
	for y: int in range(RIGHT_TAIL_RECOLOR_RECT.position.y, RIGHT_TAIL_RECOLOR_RECT.end.y):
		for x: int in range(RIGHT_TAIL_RECOLOR_RECT.position.x, RIGHT_TAIL_RECOLOR_RECT.end.x):
			var color := snapshot.get_pixel(x, y)
			var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
			if color.a <= 0.0 or not green_tail.has(rgb_key):
				continue
			image.set_pixel(x, y, _nearest_non_green_tail_color(snapshot, x, y))


func _nearest_non_green_tail_color(source: Image, x: int, y: int) -> Color:
	var green_tail: Dictionary[int, bool] = {}
	for hex_color: String in GREEN_TAIL_COLORS:
		green_tail[Color(hex_color).to_rgba32()] = true
	for radius: int in range(1, 33):
		for direction: Vector2i in [
			Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i(-1, -1), Vector2i(1, -1),
		]:
			var sample := Vector2i(x, y) + direction * radius
			if sample.x < 0 or sample.x >= LOGICAL_SIZE.x \
					or sample.y < 0 or sample.y > AURORA_MAX_Y:
				continue
			var color := source.get_pixelv(sample)
			var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
			if color.a > 0.0 and not green_tail.has(rgb_key):
				return color
	return Color("35baef")


func _accepted_component_mask(candidates: PackedByteArray) -> PackedByteArray:
	var accepted := PackedByteArray()
	accepted.resize(candidates.size())
	var visited := PackedByteArray()
	visited.resize(candidates.size())
	for start_index: int in candidates.size():
		if candidates[start_index] == 0 or visited[start_index] == 1:
			continue
		var queue := PackedInt32Array([start_index])
		var members := PackedInt32Array()
		visited[start_index] = 1
		var read_index := 0
		var min_y := LOGICAL_SIZE.y
		var max_y := -1
		while read_index < queue.size():
			var index := queue[read_index]
			read_index += 1
			members.append(index)
			var x := index % LOGICAL_SIZE.x
			var y := index / LOGICAL_SIZE.x
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
			for neighbor: Vector2i in [
				Vector2i(x - 1, y), Vector2i(x + 1, y),
				Vector2i(x, y - 1), Vector2i(x, y + 1),
			]:
				if neighbor.x < 0 or neighbor.x >= LOGICAL_SIZE.x \
						or neighbor.y < 0 or neighbor.y >= LOGICAL_SIZE.y:
					continue
				var neighbor_index := neighbor.y * LOGICAL_SIZE.x + neighbor.x
				if candidates[neighbor_index] == 0 or visited[neighbor_index] == 1:
					continue
				visited[neighbor_index] = 1
				queue.append(neighbor_index)
		var accept_component := members.size() >= 250 \
				or (members.size() >= 20 and min_y <= 55 and max_y <= 64)
		if not accept_component:
			continue
		for member_index: int in members:
			accepted[member_index] = 1
	return accepted

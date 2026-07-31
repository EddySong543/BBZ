extends SceneTree
## Generate two-channel leaf masks and minimal hinge underpaint for the two
## Scene1 foreground bamboos. Polygons cover leaf blades only.

const LEFT_SOURCE := "res://assets/scenes/scene1/scene1_bamboo_left.png"
const LEFT_MASK := "res://assets/scenes/scene1/scene1_bamboo_left_leaf_mask.png"
const LEFT_UNDERPAINT := \
		"res://assets/scenes/scene1/scene1_bamboo_left_underpaint.png"
const RIGHT_SOURCE := "res://assets/scenes/scene1/scene1_bamboo_right.png"
const RIGHT_MASK := "res://assets/scenes/scene1/scene1_bamboo_right_leaf_mask.png"
const RIGHT_UNDERPAINT := \
		"res://assets/scenes/scene1/scene1_bamboo_right_underpaint.png"

const GROUP_RED := Color(1.0, 0.0, 0.0, 1.0)
const GROUP_GREEN := Color(0.0, 1.0, 0.0, 1.0)
const HINGE_RADIUS := 4.5
const SAMPLE_RADIUS := 7
const RIGHT_LOWER_EDGE_REPAIR_OLD := Color8(29, 58, 27, 255)
const RIGHT_LOWER_EDGE_REPAIR := Color8(54, 97, 55, 255)

var left_red_regions: Array[PackedVector2Array] = [
	PackedVector2Array([
		Vector2(56, 4), Vector2(64, 6), Vector2(70, 24),
		Vector2(68, 30), Vector2(63, 26), Vector2(57, 15),
	]),
	PackedVector2Array([
		Vector2(78, 6), Vector2(84, 7), Vector2(81, 18),
		Vector2(73, 31), Vector2(69, 30), Vector2(72, 18),
	]),
]
var left_green_regions: Array[PackedVector2Array] = [
	PackedVector2Array([
		Vector2(94, 35), Vector2(111, 35), Vector2(122, 41),
		Vector2(121, 45), Vector2(106, 46), Vector2(94, 43),
		Vector2(90, 40),
	]),
	PackedVector2Array([
		Vector2(98, 50), Vector2(105, 52), Vector2(118, 63),
		Vector2(117, 69), Vector2(112, 70), Vector2(102, 59),
		Vector2(96, 54),
	]),
]
var right_red_regions: Array[PackedVector2Array] = [
	PackedVector2Array([
		Vector2(7, 84), Vector2(13, 83), Vector2(27, 94),
		Vector2(31, 99), Vector2(27, 102), Vector2(17, 97),
		Vector2(9, 91),
	]),
	PackedVector2Array([
		Vector2(0, 97), Vector2(13, 95), Vector2(29, 98),
		Vector2(31, 101), Vector2(28, 102), Vector2(10, 102),
		Vector2(1, 101),
	]),
	PackedVector2Array([
		Vector2(0, 100), Vector2(10, 100), Vector2(10, 103),
		Vector2(0, 103),
	]),
]
var right_green_regions: Array[PackedVector2Array] = [
	PackedVector2Array([
		Vector2(10, 126), Vector2(16, 126), Vector2(28, 139),
		Vector2(31, 144), Vector2(28, 147), Vector2(20, 142),
		Vector2(13, 135),
	]),
	PackedVector2Array([
		Vector2(8, 145), Vector2(14, 140), Vector2(27, 144),
		Vector2(31, 146), Vector2(26, 151), Vector2(14, 154),
		Vector2(8, 151),
	]),
]
var right_lower_leaf_outline_pixels: Array[Vector2i] = [
	Vector2i(16, 102), Vector2i(17, 102), Vector2i(23, 102),
	Vector2i(14, 103), Vector2i(15, 103), Vector2i(22, 103),
	Vector2i(14, 104), Vector2i(21, 104),
	Vector2i(12, 105), Vector2i(13, 105),
	Vector2i(20, 105), Vector2i(21, 105),
	Vector2i(11, 106), Vector2i(12, 106),
	Vector2i(18, 106), Vector2i(19, 106),
	Vector2i(10, 107), Vector2i(11, 107),
	Vector2i(16, 107), Vector2i(17, 107),
	Vector2i(9, 108), Vector2i(10, 108),
	Vector2i(14, 108), Vector2i(15, 108),
	Vector2i(9, 109), Vector2i(12, 109), Vector2i(13, 109),
	Vector2i(8, 110), Vector2i(10, 110), Vector2i(11, 110),
	Vector2i(7, 111), Vector2i(9, 111),
	Vector2i(7, 112), Vector2i(8, 112),
]


func _init() -> void:
	var left_ok := _prepare(
			LEFT_SOURCE,
			LEFT_MASK,
			LEFT_UNDERPAINT,
			left_red_regions,
			left_green_regions,
			[Vector2(70, 31), Vector2(94, 49)],
			false)
	var right_ok := _prepare(
			RIGHT_SOURCE,
			RIGHT_MASK,
			RIGHT_UNDERPAINT,
			right_red_regions,
			right_green_regions,
			[Vector2(31, 100), Vector2(31, 145)],
			true)
	quit(0 if left_ok and right_ok else 1)


func _prepare(
		source_path: String,
		mask_path: String,
		underpaint_path: String,
		red_regions: Array[PackedVector2Array],
		green_regions: Array[PackedVector2Array],
		pivots: Array[Vector2],
		repair_right_lower_edge: bool) -> bool:
	var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	if source == null:
		push_error("Could not load bamboo source: %s" % source_path)
		return false
	source.convert(Image.FORMAT_RGBA8)

	var mask := Image.create_empty(
			source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	var red_count := _paint_regions(source, mask, red_regions, GROUP_RED)
	var green_count := _paint_regions(source, mask, green_regions, GROUP_GREEN)
	var repaired_count := 0
	if repair_right_lower_edge:
		repaired_count = _repair_right_lower_leaf_edge(source, mask)
	var underpaint := _build_underpaint(source, mask, pivots)

	var mask_error := mask.save_png(ProjectSettings.globalize_path(mask_path))
	var underpaint_error := underpaint.save_png(
			ProjectSettings.globalize_path(underpaint_path))
	var source_error := OK
	if repaired_count > 0:
		source_error = source.save_png(
				ProjectSettings.globalize_path(source_path))
	if mask_error != OK or underpaint_error != OK or source_error != OK:
		push_error(
				"Could not save bamboo motion assets: source=%s mask=%s underpaint=%s"
				% [source_error, mask_error, underpaint_error])
		return false
	print(
			"prepared %s | red=%d green=%d underpaint=%d repaired=%d"
			% [
				source_path,
				red_count,
				green_count,
				_count_opaque(underpaint),
				repaired_count,
			])
	return true


func _paint_regions(
		source: Image,
		mask: Image,
		regions: Array[PackedVector2Array],
		group_color: Color) -> int:
	var count := 0
	for y: int in source.get_height():
		for x: int in source.get_width():
			if source.get_pixel(x, y).a <= 0.05:
				continue
			var point := Vector2(x + 0.5, y + 0.5)
			for region: PackedVector2Array in regions:
				if not Geometry2D.is_point_in_polygon(point, region):
					continue
				mask.set_pixel(x, y, group_color)
				count += 1
				break
	return count


func _build_underpaint(
		source: Image,
		mask: Image,
		pivots: Array[Vector2]) -> Image:
	var underpaint := Image.create_empty(
			source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	underpaint.fill(Color.TRANSPARENT)
	for y: int in source.get_height():
		for x: int in source.get_width():
			if mask.get_pixel(x, y).a <= 0.5:
				continue
			var point := Vector2(x + 0.5, y + 0.5)
			if not _near_any_pivot(point, pivots):
				continue
			var fill := _nearest_static_pixel(source, mask, x, y)
			if fill.a <= 0.05:
				continue
			fill.a = source.get_pixel(x, y).a
			underpaint.set_pixel(x, y, fill)
	return underpaint


func _repair_right_lower_leaf_edge(source: Image, mask: Image) -> int:
	var repaired := 0
	for y: int in range(101, 103):
		for x: int in range(0, 28):
			var mask_color := mask.get_pixel(x, y)
			if mask_color.a <= 0.5 or mask_color.r <= 0.5:
				continue
			var source_color := source.get_pixel(x, y)
			if source_color.a <= 0.5:
				continue
			var is_black := maxf(
					source_color.r,
					maxf(source_color.g, source_color.b)) <= 0.01
			var is_previous_repair := source_color.is_equal_approx(
					RIGHT_LOWER_EDGE_REPAIR_OLD)
			if not is_black and not is_previous_repair:
				continue
			var replacement := RIGHT_LOWER_EDGE_REPAIR
			replacement.a = source_color.a
			source.set_pixel(x, y, replacement)
			repaired += 1
	for point: Vector2i in right_lower_leaf_outline_pixels:
		var source_color := source.get_pixelv(point)
		if source_color.a <= 0.5:
			continue
		if maxf(source_color.r, maxf(
				source_color.g, source_color.b)) > 0.01:
			continue
		var replacement := RIGHT_LOWER_EDGE_REPAIR
		replacement.a = source_color.a
		source.set_pixelv(point, replacement)
		repaired += 1
	return repaired


func _near_any_pivot(point: Vector2, pivots: Array[Vector2]) -> bool:
	for pivot: Vector2 in pivots:
		if point.distance_to(pivot) <= HINGE_RADIUS:
			return true
	return false


func _nearest_static_pixel(
		source: Image,
		mask: Image,
		center_x: int,
		center_y: int) -> Color:
	var best := Color.TRANSPARENT
	var best_distance := INF
	for y: int in range(
			maxi(0, center_y - SAMPLE_RADIUS),
			mini(source.get_height(), center_y + SAMPLE_RADIUS + 1)):
		for x: int in range(
				maxi(0, center_x - SAMPLE_RADIUS),
				mini(source.get_width(), center_x + SAMPLE_RADIUS + 1)):
			if mask.get_pixel(x, y).a > 0.5:
				continue
			var candidate := source.get_pixel(x, y)
			if candidate.a <= 0.5:
				continue
			var distance := Vector2(x - center_x, y - center_y).length_squared()
			if distance >= best_distance:
				continue
			best_distance = distance
			best = candidate
	return best


func _count_opaque(image: Image) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.05:
				count += 1
	return count

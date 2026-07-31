extends SceneTree
## Generate two-channel masks and minimal root underpaint for Scene3 cliff grass.
## The sword, ribbons, chain, and rock body are explicitly excluded.

const LEFT_SOURCE := "res://assets/scenes/scene3/scene3_left_mountain.png"
const LEFT_MASK := "res://assets/scenes/scene3/scene3_left_cliff_grass_mask.png"
const LEFT_UNDERPAINT := \
		"res://assets/scenes/scene3/scene3_left_cliff_grass_underpaint.png"
const RIGHT_SOURCE := "res://assets/scenes/scene3/scene3_right_mountain.png"
const RIGHT_MASK := "res://assets/scenes/scene3/scene3_right_cliff_grass_mask.png"
const RIGHT_UNDERPAINT := \
		"res://assets/scenes/scene3/scene3_right_cliff_grass_underpaint.png"

const GROUP_RED := Color(1.0, 0.0, 0.0, 1.0)
const GROUP_GREEN := Color(0.0, 1.0, 0.0, 1.0)
const DILATION_RADIUS := 1
const HINGE_RADIUS := 3.25
const SAMPLE_RADIUS := 6

var left_red_regions: Array[PackedVector2Array] = [
	PackedVector2Array([
		Vector2(72, 73), Vector2(87, 73), Vector2(94, 98),
		Vector2(91, 102), Vector2(76, 99),
	]),
]
var left_green_regions: Array[PackedVector2Array] = [
	PackedVector2Array([
		Vector2(96, 74), Vector2(117, 76), Vector2(116, 99),
		Vector2(99, 103), Vector2(94, 99),
	]),
]
var right_red_regions: Array[PackedVector2Array] = [
	PackedVector2Array([
		Vector2(17, 37), Vector2(36, 37), Vector2(39, 53),
		Vector2(17, 55),
	]),
	PackedVector2Array([
		Vector2(47, 33), Vector2(65, 34), Vector2(67, 53),
		Vector2(46, 54),
	]),
]
var right_green_regions: Array[PackedVector2Array] = [
	PackedVector2Array([
		Vector2(138, 122), Vector2(161, 122), Vector2(163, 144),
		Vector2(139, 146),
	]),
]


func _init() -> void:
	var left_ok := _prepare(
			LEFT_SOURCE,
			LEFT_MASK,
			LEFT_UNDERPAINT,
			left_red_regions,
			left_green_regions,
			[Vector2(91, 99), Vector2(99, 100)],
			true)
	var right_ok := _prepare(
			RIGHT_SOURCE,
			RIGHT_MASK,
			RIGHT_UNDERPAINT,
			right_red_regions,
			right_green_regions,
			[Vector2(41, 52), Vector2(149, 142)],
			false)
	quit(0 if left_ok and right_ok else 1)


func _prepare(
		source_path: String,
		mask_path: String,
		underpaint_path: String,
		red_regions: Array[PackedVector2Array],
		green_regions: Array[PackedVector2Array],
		pivots: Array[Vector2],
		left_palette: bool) -> bool:
	var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	if source == null:
		push_error("Could not load Scene3 cliff source: %s" % source_path)
		return false
	source.convert(Image.FORMAT_RGBA8)

	var mask := Image.create_empty(
			source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	var red_count := _paint_group(
			source, mask, red_regions, GROUP_RED, left_palette)
	var green_count := _paint_group(
			source, mask, green_regions, GROUP_GREEN, left_palette)
	if left_palette:
		# Grass crosses behind the sword and touches a bright rock cap in the
		# source. Hard exclusions guarantee neither can enter the motion mask.
		_clear_rect(mask, Rect2i(90, 45, 13, 52))
		_clear_rect(mask, Rect2i(103, 92, 14, 11))
		_clear_rect(mask, Rect2i(70, 100, 50, 5))
		red_count = _count_channel(mask, 0)
		green_count = _count_channel(mask, 1)
	var underpaint := _build_underpaint(source, mask, pivots)

	var mask_error := mask.save_png(ProjectSettings.globalize_path(mask_path))
	var underpaint_error := underpaint.save_png(
			ProjectSettings.globalize_path(underpaint_path))
	if mask_error != OK or underpaint_error != OK:
		push_error(
				"Could not save Scene3 cliff grass assets: mask=%s underpaint=%s"
				% [mask_error, underpaint_error])
		return false
	if red_count < 8 or green_count < 8:
		push_error(
				"Scene3 cliff grass selection is unexpectedly small: red=%d green=%d"
				% [red_count, green_count])
		return false
	print(
			"prepared %s | red=%d green=%d underpaint=%d"
			% [
				source_path,
				red_count,
				green_count,
				_count_opaque(underpaint),
			])
	return true


func _paint_group(
		source: Image,
		mask: Image,
		regions: Array[PackedVector2Array],
		group_color: Color,
		left_palette: bool) -> int:
	var seed := Image.create_empty(
			source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	seed.fill(Color.TRANSPARENT)
	for y: int in source.get_height():
		for x: int in source.get_width():
			var point := Vector2(x + 0.5, y + 0.5)
			if not _inside_any(point, regions):
				continue
			var color := source.get_pixel(x, y)
			if color.a <= 0.05 or not _is_grass_seed(color, left_palette):
				continue
			seed.set_pixel(x, y, Color.WHITE)

	var count := 0
	for y: int in source.get_height():
		for x: int in source.get_width():
			var point := Vector2(x + 0.5, y + 0.5)
			if not _inside_any(point, regions):
				continue
			if source.get_pixel(x, y).a <= 0.05:
				continue
			if not _near_seed(seed, x, y):
				continue
			mask.set_pixel(x, y, group_color)
			count += 1
	return count


func _is_grass_seed(color: Color, left_palette: bool) -> bool:
	if left_palette:
		return color.g > color.r + 0.012 \
				and color.g >= color.b - 0.008 \
				and color.get_luminance() < 0.34
	return color.r > color.b + 0.035 \
			and color.g > color.b + 0.035 \
			and color.get_luminance() < 0.48


func _near_seed(seed: Image, center_x: int, center_y: int) -> bool:
	for y: int in range(
			maxi(0, center_y - DILATION_RADIUS),
			mini(seed.get_height(), center_y + DILATION_RADIUS + 1)):
		for x: int in range(
				maxi(0, center_x - DILATION_RADIUS),
				mini(seed.get_width(), center_x + DILATION_RADIUS + 1)):
			if seed.get_pixel(x, y).a > 0.5:
				return true
	return false


func _inside_any(point: Vector2, regions: Array[PackedVector2Array]) -> bool:
	for region: PackedVector2Array in regions:
		if Geometry2D.is_point_in_polygon(point, region):
			return true
	return false


func _clear_rect(mask: Image, rect: Rect2i) -> void:
	for y: int in range(maxi(0, rect.position.y), mini(mask.get_height(), rect.end.y)):
		for x: int in range(maxi(0, rect.position.x), mini(mask.get_width(), rect.end.x)):
			mask.set_pixel(x, y, Color.TRANSPARENT)


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


func _count_channel(image: Image, channel: int) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			var value := color.r if channel == 0 else color.g
			if color.a > 0.05 and value > 0.5:
				count += 1
	return count

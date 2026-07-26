extends SceneTree
## Build a source-resolution motion mask for the Scene2 blossom tree.
##
## RGB channels identify three independently swaying terminal branch groups.
## Yellow (R+G) identifies the small hanging blossom below the left-bearing
## trunk so it can move on a shorter, lighter rhythm.
## The roots, main trunk, and thick left-bearing limb are deliberately excluded,
## so their source pixels remain untouched by the animation shader.

const SOURCE_PATH := "res://assets/scenes/scene2/scene2_blossom_tree.png"
const OUTPUT_PATH := "res://assets/scenes/scene2/scene2_blossom_branch_mask.png"
const UNDERPAINT_PATH := "res://assets/scenes/scene2/scene2_blossom_underpaint.png"
const UNDERPAINT_RADIUS := 8
const HIDDEN_TRUNK_HALF_WIDTH := 4.0
const BLOSSOM_SAMPLE_RADIUS := 10
const BLOSSOM_SEAM_RADIUS := 4
const BLOSSOM_SEAM_RECT := Rect2i(34, 24, 94, 52)

const LEFT_BRANCH := Color(1.0, 0.0, 0.0, 1.0)
const UPPER_BRANCH := Color(0.0, 1.0, 0.0, 1.0)
const RIGHT_BRANCH := Color(0.0, 0.0, 1.0, 1.0)
const HANGING_BOUQUET := Color(1.0, 1.0, 0.0, 1.0)

var left_region := PackedVector2Array([
	Vector2(-2, 42),
	Vector2(45, 28),
	Vector2(104, 34),
	Vector2(122, 58),
	Vector2(104, 82),
	Vector2(55, 105),
	Vector2(-2, 107),
])
var upper_region := PackedVector2Array([
	Vector2(34, -2),
	Vector2(164, -2),
	Vector2(181, 37),
	Vector2(155, 62),
	Vector2(98, 64),
	Vector2(47, 50),
])
var right_region := PackedVector2Array([
	Vector2(118, 8),
	Vector2(210, 13),
	Vector2(210, 91),
	Vector2(171, 91),
	Vector2(142, 111),
	Vector2(107, 97),
	Vector2(115, 58),
])
var hanging_bouquet_region := PackedVector2Array([
	Vector2(108, 75),
	Vector2(126, 72),
	Vector2(137, 92),
	Vector2(133, 113),
	Vector2(111, 113),
	Vector2(104, 94),
])
# P2 stands below this separate drooping blossom cluster. It belongs to the
# larger red branch motion group, but its exposed underpaint must remain blossom
# pink instead of inheriting the nearby dark wood palette.
var p2_head_blossom_region := PackedVector2Array([
	Vector2(76, 66),
	Vector2(93, 66),
	Vector2(97, 74),
	Vector2(95, 91),
	Vector2(88, 97),
	Vector2(76, 93),
	Vector2(72, 83),
	Vector2(74, 73),
])

# The radius on each segment is intentionally generous: an occasional static
# blossom beside the wood is preferable to making the load-bearing trunk swim.
var static_skeleton: Array[Dictionary] = [
	{"from": Vector2(184, 127), "to": Vector2(172, 103), "radius": 14.0},
	{"from": Vector2(172, 103), "to": Vector2(157, 79), "radius": 11.0},
	{"from": Vector2(157, 79), "to": Vector2(132, 68), "radius": 9.0},
	{"from": Vector2(132, 68), "to": Vector2(106, 61), "radius": 8.0},
	{"from": Vector2(106, 61), "to": Vector2(82, 66), "radius": 8.0},
	{"from": Vector2(82, 66), "to": Vector2(60, 82), "radius": 7.0},
	{"from": Vector2(158, 79), "to": Vector2(176, 58), "radius": 7.0},
]


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if source == null:
		push_error("Could not load Scene2 blossom tree: %s" % SOURCE_PATH)
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)

	var mask := Image.create_empty(
			source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)

	var counts := PackedInt32Array([0, 0, 0, 0])
	for y: int in source.get_height():
		for x: int in source.get_width():
			if source.get_pixel(x, y).a <= 0.05:
				continue
			var point := Vector2(x + 0.5, y + 0.5)
			if _is_static_skeleton(point):
				continue
			if Geometry2D.is_point_in_polygon(point, hanging_bouquet_region):
				mask.set_pixel(x, y, HANGING_BOUQUET)
				counts[3] += 1
			elif Geometry2D.is_point_in_polygon(point, left_region):
				mask.set_pixel(x, y, LEFT_BRANCH)
				counts[0] += 1
			elif Geometry2D.is_point_in_polygon(point, upper_region):
				mask.set_pixel(x, y, UPPER_BRANCH)
				counts[1] += 1
			elif Geometry2D.is_point_in_polygon(point, right_region):
				mask.set_pixel(x, y, RIGHT_BRANCH)
				counts[2] += 1

	var error := mask.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save blossom branch mask: %s" % error)
		quit(1)
		return

	var underpaint := _build_underpaint(source, mask)
	error = underpaint.save_png(ProjectSettings.globalize_path(UNDERPAINT_PATH))
	if error != OK:
		push_error("Could not save blossom underpaint: %s" % error)
		quit(1)
		return

	print(
			"prepared %s + %s | left=%d upper=%d right=%d bouquet=%d static=%d underpaint=%d"
			% [
				OUTPUT_PATH,
				UNDERPAINT_PATH,
				counts[0],
				counts[1],
				counts[2],
				counts[3],
				source.get_width() * source.get_height()
						- counts[0] - counts[1] - counts[2] - counts[3],
				_count_opaque_pixels(underpaint),
			])
	quit(0)


func _build_underpaint(source: Image, mask: Image) -> Image:
	var underpaint := Image.create_empty(
			source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	underpaint.fill(Color.TRANSPARENT)

	for y: int in source.get_height():
		for x: int in source.get_width():
			var source_color := source.get_pixel(x, y)
			if source_color.a <= 0.05 or mask.get_pixel(x, y).a <= 0.5:
				continue

			var nearest_wood := _find_nearest_wood(source, mask, x, y, true)
			if nearest_wood.a > 0.0:
				nearest_wood.a = source_color.a
				underpaint.set_pixel(x, y, nearest_wood)

	# Paint the hidden centerline itself as well. The imported illustration has
	# a few transparent pixels inside branch junctions; a real cutout rig would
	# continue the trunk behind the detached art, rather than preserving those
	# extraction holes. This narrow pass never follows the outer canopy edge.
	for y: int in source.get_height():
		for x: int in source.get_width():
			if y >= 105:
				continue
			if source.get_pixel(x, y).a > 0.05 \
					or underpaint.get_pixel(x, y).a > 0.05:
				continue
			if _distance_to_static_centerline(Vector2(x + 0.5, y + 0.5)) \
					> HIDDEN_TRUNK_HALF_WIDTH:
				continue
			var nearest_wood := _find_nearest_wood(source, mask, x, y, false)
			if nearest_wood.a > 0.0:
				nearest_wood.a = 1.0
				underpaint.set_pixel(x, y, nearest_wood)

	_paint_blossom_repairs(source, mask, underpaint)
	return underpaint


func _paint_blossom_repairs(source: Image, mask: Image, underpaint: Image) -> void:
	# Recolor the hidden pixels behind the drooping blossoms above P2. This is
	# deliberately independent from the yellow bouquet mask: the marked cluster
	# is part of the red left-branch group and was the remaining black repair.
	for y: int in source.get_height():
		for x: int in source.get_width():
			if underpaint.get_pixel(x, y).a <= 0.05 \
					or not Geometry2D.is_point_in_polygon(
							Vector2(x + 0.5, y + 0.5),
							p2_head_blossom_region):
				continue
			var blossom := _find_nearest_blossom(source, x, y)
			if blossom.a > 0.0:
				blossom.a = underpaint.get_pixel(x, y).a
				underpaint.set_pixel(x, y, blossom)

	# The hanging bouquet is blossom artwork, not exposed wood. Recolor only
	# the pixels already selected for underpainting, keeping the repair hidden
	# beneath the independently moving bouquet.
	for y: int in source.get_height():
		for x: int in source.get_width():
			var mask_color := mask.get_pixel(x, y)
			if underpaint.get_pixel(x, y).a <= 0.05 \
					or not _is_hanging_bouquet(mask_color):
				continue
			var blossom := _find_nearest_blossom(source, x, y)
			if blossom.a > 0.0:
				blossom.a = underpaint.get_pixel(x, y).a
				underpaint.set_pixel(x, y, blossom)

	# Left and upper crown groups move on different phases. Paint a narrow
	# shared blossom band below their touching mask edges so their one-pixel
	# separation reveals pink foliage rather than the scene background.
	for y: int in range(BLOSSOM_SEAM_RECT.position.y, BLOSSOM_SEAM_RECT.end.y):
		for x: int in range(BLOSSOM_SEAM_RECT.position.x, BLOSSOM_SEAM_RECT.end.x):
			if source.get_pixel(x, y).a <= 0.05:
				continue
			if not _near_mask_group(mask, x, y, true) \
					or not _near_mask_group(mask, x, y, false):
				continue
			var blossom := _find_nearest_blossom(source, x, y)
			if blossom.a > 0.0:
				blossom.a = source.get_pixel(x, y).a
				underpaint.set_pixel(x, y, blossom)


func _near_mask_group(
		mask: Image,
		center_x: int,
		center_y: int,
		left_group: bool) -> bool:
	for sample_y: int in range(
			maxi(0, center_y - BLOSSOM_SEAM_RADIUS),
			mini(mask.get_height(), center_y + BLOSSOM_SEAM_RADIUS + 1)):
		for sample_x: int in range(
				maxi(0, center_x - BLOSSOM_SEAM_RADIUS),
				mini(mask.get_width(), center_x + BLOSSOM_SEAM_RADIUS + 1)):
			var color := mask.get_pixel(sample_x, sample_y)
			if color.a <= 0.5:
				continue
			var is_left := color.r > 0.9 and color.g < 0.1
			var is_upper := color.g > 0.9 and color.r < 0.1
			if (left_group and is_left) or (not left_group and is_upper):
				return true
	return false


func _is_hanging_bouquet(color: Color) -> bool:
	return color.a > 0.5 and color.r > 0.9 and color.g > 0.9 and color.b < 0.1


func _find_nearest_blossom(
		source: Image,
		center_x: int,
		center_y: int) -> Color:
	var nearest_distance_squared := INF
	var nearest_blossom := Color.TRANSPARENT
	for sample_y: int in range(
			maxi(0, center_y - BLOSSOM_SAMPLE_RADIUS),
			mini(source.get_height(), center_y + BLOSSOM_SAMPLE_RADIUS + 1)):
		for sample_x: int in range(
				maxi(0, center_x - BLOSSOM_SAMPLE_RADIUS),
				mini(source.get_width(), center_x + BLOSSOM_SAMPLE_RADIUS + 1)):
			var delta := Vector2i(sample_x - center_x, sample_y - center_y)
			var distance_squared := delta.length_squared()
			if distance_squared > BLOSSOM_SAMPLE_RADIUS * BLOSSOM_SAMPLE_RADIUS \
					or distance_squared >= nearest_distance_squared:
				continue
			var candidate := source.get_pixel(sample_x, sample_y)
			if not _is_blossom_color(candidate):
				continue
			nearest_distance_squared = distance_squared
			nearest_blossom = candidate
	return nearest_blossom


func _is_blossom_color(color: Color) -> bool:
	if color.a <= 0.5 or color.r <= 0.34:
		return false
	return color.r >= color.g * 1.16 and color.r >= color.b * 1.06


func _find_nearest_wood(
		source: Image,
		mask: Image,
		center_x: int,
		center_y: int,
		require_static: bool) -> Color:
	var nearest_distance_squared := INF
	var nearest_wood := Color.TRANSPARENT
	for sample_y: int in range(
			maxi(0, center_y - UNDERPAINT_RADIUS),
			mini(source.get_height(), center_y + UNDERPAINT_RADIUS + 1)):
		for sample_x: int in range(
				maxi(0, center_x - UNDERPAINT_RADIUS),
				mini(source.get_width(), center_x + UNDERPAINT_RADIUS + 1)):
			var delta := Vector2i(sample_x - center_x, sample_y - center_y)
			var distance_squared := delta.length_squared()
			if distance_squared > UNDERPAINT_RADIUS * UNDERPAINT_RADIUS \
					or distance_squared >= nearest_distance_squared:
				continue
			if require_static and mask.get_pixel(sample_x, sample_y).a > 0.5:
				continue
			var candidate := source.get_pixel(sample_x, sample_y)
			if not _is_wood_color(candidate):
				continue
			nearest_distance_squared = distance_squared
			nearest_wood = candidate
	return nearest_wood


func _distance_to_static_centerline(point: Vector2) -> float:
	var nearest := INF
	for segment: Dictionary in static_skeleton:
		nearest = minf(
				nearest,
				_distance_to_segment(
						point,
						segment["from"] as Vector2,
						segment["to"] as Vector2))
	return nearest


func _is_wood_color(color: Color) -> bool:
	if color.a <= 0.5 or color.r >= 0.52:
		return false
	# Blossom ramps are red-dominant. The trunk palette stays blue/green-grey,
	# so this ratio preserves its authored pixels without inventing new colors.
	return color.g >= color.r * 0.72 and color.b >= color.r * 0.72


func _count_opaque_pixels(image: Image) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			count += int(image.get_pixel(x, y).a > 0.05)
	return count


func _is_static_skeleton(point: Vector2) -> bool:
	for segment: Dictionary in static_skeleton:
		if _distance_to_segment(
				point,
				segment["from"] as Vector2,
				segment["to"] as Vector2) <= float(segment["radius"]):
			return true
	return false


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if is_zero_approx(length_squared):
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * amount)

extends SceneTree
## Build a source-resolution three-channel motion mask for the small blossom
## branches protruding from Scene2's left mountain.
##
## The polygons begin beyond each branch attachment, so the mountain face,
## trunks, and branch roots remain static. No underpaint is required because
## every moving group sits against the transparent exterior silhouette.

const SOURCE_PATH := "res://assets/scenes/scene2/scene2_mountain_left.png"
const OUTPUT_PATH := \
		"res://assets/scenes/scene2/scene2_mountain_left_branch_mask.png"

const UPPER_BRANCH := Color(1.0, 0.0, 0.0, 1.0)
const MIDDLE_BRANCH := Color(0.0, 1.0, 0.0, 1.0)
const LOWER_BRANCH := Color(0.0, 0.0, 1.0, 1.0)

var upper_region := PackedVector2Array([
	Vector2(48, 71),
	Vector2(62, 70),
	Vector2(67, 78),
	Vector2(64, 84),
	Vector2(54, 86),
	Vector2(48, 82),
])
var middle_region := PackedVector2Array([
	Vector2(51, 84),
	Vector2(66, 84),
	Vector2(70, 91),
	Vector2(68, 99),
	Vector2(59, 103),
	Vector2(52, 97),
])
var lower_region := PackedVector2Array([
	Vector2(55, 100),
	Vector2(69, 103),
	Vector2(77, 110),
	Vector2(76, 117),
	Vector2(68, 121),
	Vector2(58, 118),
	Vector2(54, 109),
])


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if source == null:
		push_error("Could not load Scene2 left mountain: %s" % SOURCE_PATH)
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)

	var mask := Image.create_empty(
			source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	var counts := PackedInt32Array([0, 0, 0])
	for y: int in source.get_height():
		for x: int in source.get_width():
			if source.get_pixel(x, y).a <= 0.05:
				continue
			var point := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(point, upper_region):
				mask.set_pixel(x, y, UPPER_BRANCH)
				counts[0] += 1
			elif Geometry2D.is_point_in_polygon(point, middle_region):
				mask.set_pixel(x, y, MIDDLE_BRANCH)
				counts[1] += 1
			elif Geometry2D.is_point_in_polygon(point, lower_region):
				mask.set_pixel(x, y, LOWER_BRANCH)
				counts[2] += 1

	var error := mask.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save left-mountain branch mask: %s" % error)
		quit(1)
		return
	print(
			"prepared %s | upper=%d middle=%d lower=%d"
			% [OUTPUT_PATH, counts[0], counts[1], counts[2]])
	quit(0)

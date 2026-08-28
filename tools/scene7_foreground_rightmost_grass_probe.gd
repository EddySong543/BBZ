extends SceneTree

const SOURCE_PATH := "res://assets/scenes/scene7/scene7_foreground_left.png"
const MASK_PATH := "res://assets/scenes/scene7/scene7_branch_mask_foreground_left.png"


func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if source == null or source.is_empty():
		push_error("Could not load Scene7 foreground-left source")
		quit(1)
		return
	var mask := Image.load_from_file(ProjectSettings.globalize_path(MASK_PATH))
	var channel_reports: Array[String] = []
	var passed := mask != null and not mask.is_empty()
	if passed:
		for channel: int in range(3):
			var metrics := _channel_metrics(mask, channel)
			channel_reports.append("%d:%s" % [channel, metrics])
		var target: Dictionary = _channel_metrics(mask, 2)
		var centroid: Vector2 = target["centroid_uv"]
		passed = int(target["count"]) >= 180 \
				and centroid.x >= 0.78 and centroid.x <= 0.94 \
				and centroid.y >= 0.84 and centroid.y <= 0.94
	print("SCENE7_RIGHTMOST_FORKED_GRASS_MASK: ",
			"PASS" if passed else "FAIL", " channels=", channel_reports)
	quit(0 if passed else 1)


func _channel_metrics(mask: Image, channel: int) -> Dictionary:
	var count := 0
	var total := Vector2.ZERO
	var minimum := Vector2i(mask.get_width(), mask.get_height())
	var maximum := Vector2i.ZERO
	for y: int in range(mask.get_height()):
		for x: int in range(mask.get_width()):
			var color := mask.get_pixel(x, y)
			var selected := color.r >= 0.5 if channel == 0 \
					else color.g >= 0.5 if channel == 1 else color.b >= 0.5
			if not selected:
				continue
			count += 1
			total += Vector2(x, y) + Vector2(0.5, 0.5)
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	var centroid_uv := Vector2.ZERO
	var bounds := Rect2i()
	if count > 0:
		centroid_uv = total / float(count) / Vector2(mask.get_size())
		bounds = Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	return {
		"count": count,
		"centroid_uv": centroid_uv,
		"bounds": bounds,
	}

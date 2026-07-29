extends SceneTree
## Convert the accepted Scene2 import images from baked light/checkerboard or
## dark backgrounds to cropped true-alpha runtime textures. Dark-background
## assets remove dark exterior pixels while closing and retaining dark shadows
## inside the authored colored structure.

const JOBS: Array[Dictionary] = [
	{
		"source": "res://assets/art_src/scenes/scene2/scene2_blossom_tree.png",
		"output": "res://assets/scenes/scene2/scene2_blossom_tree.png",
		"luminance_threshold": 0.90,
		"chroma_threshold": 0.06,
		"expected_size": Vector2i(208, 125),
	},
	{
		"source": "res://assets/art_src/scenes/scene2/scene2_stone_bridge.png",
		"output": "res://assets/scenes/scene2/scene2_stone_bridge.png",
		"key_mode": "interior_shadow",
		"foreground_luminance_min": 0.04,
		"interior_gap_radius": 3,
		"external_shadow_strip_radius": 1,
		"crop_padding": 0,
		"expected_size": Vector2i(237, 55),
	},
	{
		"source": "res://assets/art_src/scenes/scene2/scene2_cloud_bank.png",
		"output": "res://assets/scenes/scene2/scene2_cloud_bank.png",
		"key_mode": "alpha_crop",
		"expected_size": Vector2i(1521, 1019),
	},
	{
		"source": "res://assets/art_src/scenes/scene2/scene2_cloud_tower.png",
		"output": "res://assets/scenes/scene2/scene2_cloud_tower.png",
		"key_mode": "alpha_crop",
		"expected_size": Vector2i(1513, 486),
	},
	{
		"source": "res://assets/art_src/scenes/scene2/scene2_mid_mountain.png",
		"output": "res://assets/scenes/scene2/scene2_mid_mountain.png",
		"luminance_threshold": 0.70,
		"chroma_threshold": 0.08,
		"expected_size": Vector2i(1672, 752),
	},
	{
		"source": "res://assets/art_src/scenes/scene2/scene2_far_mountain.png",
		"output": "res://assets/scenes/scene2/scene2_far_mountain.png",
		"luminance_threshold": 0.70,
		"chroma_threshold": 0.08,
		"expected_size": Vector2i(1608, 508),
	},
	{
		"source": "res://assets/art_src/scenes/scene2/scene2_mountain_left.png",
		"output": "res://assets/scenes/scene2/scene2_mountain_left.png",
		"luminance_threshold": 0.86,
		"chroma_threshold": 0.08,
		"expected_size": Vector2i(122, 194),
	},
	{
		"source": "res://assets/art_src/scenes/scene2/scene2_mountain_right.png",
		"output": "res://assets/scenes/scene2/scene2_mountain_right.png",
		"key_mode": "interior_shadow",
		"foreground_luminance_min": 0.04,
		"interior_gap_radius": 2,
		"external_shadow_strip_radius": 1,
		"crop_padding": 0,
		"expected_size": Vector2i(140, 235),
	},
]


func _init() -> void:
	var failed := false
	for job: Dictionary in JOBS:
		if not _prepare_asset(job):
			failed = true
	quit(1 if failed else 0)


func _prepare_asset(job: Dictionary) -> bool:
	var source_path := String(job["source"])
	var output_path := String(job["output"])
	var image := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	if image == null:
		push_error("Scene2 environment source could not be loaded: %s" % source_path)
		return false

	image.convert(Image.FORMAT_RGBA8)
	var key_mode := String(job.get("key_mode", "light"))
	var keyed_pixels := 0
	var crop_rect := Rect2i()
	match key_mode:
		"alpha_crop":
			pass
		"light":
			keyed_pixels = _key_light_background(
					image,
					float(job["luminance_threshold"]),
					float(job["chroma_threshold"]))
		"interior_shadow":
			var foreground_rect := _get_luminance_foreground_rect(
					image,
					float(job["foreground_luminance_min"]))
			if not foreground_rect.has_area():
				push_error("%s has no foreground pixels" % source_path)
				return false
			crop_rect = Rect2i(Vector2i.ZERO, image.get_size()).intersection(
					foreground_rect.grow(int(job["crop_padding"])))
			keyed_pixels = _key_dark_background_preserve_internal_shadow(
					image,
					float(job["foreground_luminance_min"]),
					int(job["interior_gap_radius"]),
					int(job["external_shadow_strip_radius"]))
		_:
			push_error("%s has unsupported key mode: %s" % [source_path, key_mode])
			return false

	var used_rect := crop_rect if crop_rect.has_area() else image.get_used_rect()
	var expected_size: Vector2i = job["expected_size"]
	if used_rect.size != expected_size:
		push_error(
				"%s produced %s, expected %s; source or key thresholds changed"
				% [source_path, used_rect.size, expected_size])
		return false

	var output := image.get_region(used_rect)
	if output_path.ends_with("scene2_stone_bridge.png"):
		_cleanup_stone_bridge(output)
	var error := output.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Scene2 environment asset could not be saved: %s (%s)" % [output_path, error])
		return false

	print(
			"prepared %s -> %s | crop=%s | keyed=%d"
			% [source_path, output_path, used_rect, keyed_pixels])
	return true


func _cleanup_stone_bridge(image: Image) -> void:
	# Remove only very dark pixels that still touch the transparent sky above
	# the walkable top. Two shallow passes clear the old exterior outline
	# without reaching the authored stone shadows inside the bridge.
	for _pass: int in 4:
		var snapshot := image.duplicate() as Image
		for y: int in mini(13, image.get_height()):
			for x: int in image.get_width():
				var color: Color = snapshot.get_pixel(x, y)
				if color.a <= 0.0 or _luminance(color) >= 0.10:
					continue
				if _touches_transparent_exterior(snapshot, x, y):
					image.set_pixel(x, y, Color.TRANSPARENT)

	# The central opening is intentionally organic, but isolated one-column or
	# one-row alpha spikes read as extraction damage at 7x nearest scaling.
	# Regularize only singleton deviations of at most two source pixels.
	for _pass: int in 2:
		_regularize_opening_top(image)
		_regularize_opening_sides(image)


func _touches_transparent_exterior(image: Image, x: int, y: int) -> bool:
	for offset_y: int in range(-1, 1):
		for offset_x: int in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var pixel := Vector2i(x + offset_x, y + offset_y)
			if pixel.y < 0:
				return true
			if pixel.x < 0 or pixel.x >= image.get_width():
				continue
			if image.get_pixelv(pixel).a <= 0.0:
				return true
	return false


func _regularize_opening_top(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var min_x := int(width * 0.28)
	var max_x := int(width * 0.77)
	var min_y := int(height * 0.16)
	var tops := PackedInt32Array()
	tops.resize(width)
	tops.fill(-1)
	for x: int in range(min_x, max_x + 1):
		for y: int in range(maxi(min_y, 1), height):
			if image.get_pixel(x, y).a <= 0.0 \
					and image.get_pixel(x, y - 1).a > 0.0:
				tops[x] = y
				break

	for x: int in range(min_x + 1, max_x):
		var previous := tops[x - 1]
		var current := tops[x]
		var following := tops[x + 1]
		if previous < 0 or current < 0 or previous != following:
			continue
		if current == previous or absi(current - previous) > 2:
			continue
		_set_opening_top(image, x, current, previous)


func _set_opening_top(image: Image, x: int, current: int, target: int) -> void:
	if target > current:
		var source := image.get_pixel(x, maxi(current - 1, 0))
		for y: int in range(current, target):
			image.set_pixel(x, y, source)
	else:
		for y: int in range(target, current):
			image.set_pixel(x, y, Color.TRANSPARENT)


func _regularize_opening_sides(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var center_x := width / 2
	var min_y := int(height * 0.25)
	var lefts := PackedInt32Array()
	var rights := PackedInt32Array()
	lefts.resize(height)
	rights.resize(height)
	lefts.fill(-1)
	rights.fill(-1)
	for y: int in range(min_y, height):
		if image.get_pixel(center_x, y).a > 0.0:
			continue
		var left := center_x
		var right := center_x
		while left > 0 and image.get_pixel(left - 1, y).a <= 0.0:
			left -= 1
		while right < width - 1 and image.get_pixel(right + 1, y).a <= 0.0:
			right += 1
		lefts[y] = left
		rights[y] = right

	for y: int in range(min_y + 1, height - 1):
		if lefts[y - 1] >= 0 and lefts[y - 1] == lefts[y + 1] \
				and lefts[y] >= 0 and lefts[y] != lefts[y - 1] \
				and absi(lefts[y] - lefts[y - 1]) <= 2:
			_set_opening_left(image, y, lefts[y], lefts[y - 1])
		if rights[y - 1] >= 0 and rights[y - 1] == rights[y + 1] \
				and rights[y] >= 0 and rights[y] != rights[y - 1] \
				and absi(rights[y] - rights[y - 1]) <= 2:
			_set_opening_right(image, y, rights[y], rights[y - 1])


func _set_opening_left(image: Image, y: int, current: int, target: int) -> void:
	if target > current:
		var source := image.get_pixel(maxi(current - 1, 0), y)
		for x: int in range(current, target):
			image.set_pixel(x, y, source)
	else:
		for x: int in range(target, current):
			image.set_pixel(x, y, Color.TRANSPARENT)


func _set_opening_right(image: Image, y: int, current: int, target: int) -> void:
	if target < current:
		var source := image.get_pixel(mini(current + 1, image.get_width() - 1), y)
		for x: int in range(target + 1, current + 1):
			image.set_pixel(x, y, source)
	else:
		for x: int in range(current + 1, target + 1):
			image.set_pixel(x, y, Color.TRANSPARENT)


func _key_light_background(
		image: Image,
		luminance_threshold: float,
		chroma_threshold: float) -> int:
	var keyed_pixels := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			var high := maxf(color.r, maxf(color.g, color.b))
			var low := minf(color.r, minf(color.g, color.b))
			if _luminance(color) > luminance_threshold and high - low < chroma_threshold:
				image.set_pixel(x, y, Color.TRANSPARENT)
				keyed_pixels += 1
	return keyed_pixels


func _key_dark_background_preserve_internal_shadow(
		image: Image,
		foreground_luminance_min: float,
		interior_gap_radius: int,
		external_shadow_strip_radius: int) -> int:
	var width := image.get_width()
	var height := image.get_height()
	var seeds := PackedByteArray()
	seeds.resize(width * height)

	for y: int in height:
		for x: int in width:
			if _luminance(image.get_pixel(x, y)) <= foreground_luminance_min:
				continue
			seeds[y * width + x] = 1

	var closed_interior := _erode_mask(
			_dilate_mask(seeds, width, height, interior_gap_radius),
			width,
			height,
			interior_gap_radius)
	var protected_shadow := _erode_mask(
			closed_interior,
			width,
			height,
			external_shadow_strip_radius)
	var keep := seeds.duplicate()
	for index: int in keep.size():
		if protected_shadow[index] != 0:
			keep[index] = 1

	var keyed_pixels := 0
	for y: int in height:
		for x: int in width:
			if keep[y * width + x] != 0:
				continue
			image.set_pixel(x, y, Color.TRANSPARENT)
			keyed_pixels += 1
	return keyed_pixels


func _get_luminance_foreground_rect(
		image: Image,
		foreground_luminance_min: float) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y: int in image.get_height():
		for x: int in image.get_width():
			if _luminance(image.get_pixel(x, y)) <= foreground_luminance_min:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _dilate_mask(
		mask: PackedByteArray,
		width: int,
		height: int,
		radius: int) -> PackedByteArray:
	var dilated := PackedByteArray()
	dilated.resize(width * height)
	for y: int in height:
		for x: int in width:
			if mask[y * width + x] == 0:
				continue
			for offset_y: int in range(-radius, radius + 1):
				for offset_x: int in range(-radius, radius + 1):
					var pixel := Vector2i(x + offset_x, y + offset_y)
					if Rect2i(Vector2i.ZERO, Vector2i(width, height)).has_point(pixel):
						dilated[pixel.y * width + pixel.x] = 1
	return dilated


func _erode_mask(
		mask: PackedByteArray,
		width: int,
		height: int,
		radius: int) -> PackedByteArray:
	var eroded := PackedByteArray()
	eroded.resize(width * height)
	var image_rect := Rect2i(Vector2i.ZERO, Vector2i(width, height))
	for y: int in height:
		for x: int in width:
			var survives := true
			for offset_y: int in range(-radius, radius + 1):
				for offset_x: int in range(-radius, radius + 1):
					var pixel := Vector2i(x + offset_x, y + offset_y)
					if not image_rect.has_point(pixel) \
							or mask[pixel.y * width + pixel.x] == 0:
						survives = false
						break
				if not survives:
					break
			if survives:
				eroded[y * width + x] = 1
	return eroded


func _luminance(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114

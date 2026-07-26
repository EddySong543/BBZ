extends SceneTree
## Convert the two accepted waterfall-ridge imports in place from baked light
## backgrounds to cropped true-alpha runtime textures.

const JOBS: Array[Dictionary] = [
	{
		"path": "res://assets/scenes/scene2/scene2_waterfall_ridge_left.png",
		"expected_size": Vector2i(102, 131),
	},
	{
		"path": "res://assets/scenes/scene2/scene2_waterfall_ridge_right.png",
		"expected_size": Vector2i(110, 164),
	},
]
const LUMINANCE_THRESHOLD := 0.86
const CHROMA_THRESHOLD := 0.08


func _init() -> void:
	var failed := false
	for job: Dictionary in JOBS:
		if not _prepare_asset(job):
			failed = true
	quit(1 if failed else 0)


func _prepare_asset(job: Dictionary) -> bool:
	var path := String(job["path"])
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		push_error("Waterfall ridge source could not be loaded: %s" % path)
		return false

	image.convert(Image.FORMAT_RGBA8)
	var keyed_pixels := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			var high := maxf(color.r, maxf(color.g, color.b))
			var low := minf(color.r, minf(color.g, color.b))
			var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			if luminance > LUMINANCE_THRESHOLD \
					and high - low < CHROMA_THRESHOLD:
				image.set_pixel(x, y, Color.TRANSPARENT)
				keyed_pixels += 1

	var used_rect := image.get_used_rect()
	var expected_size: Vector2i = job["expected_size"]
	if used_rect.size != expected_size:
		push_error(
				"%s produced %s, expected %s; source or key thresholds changed"
				% [path, used_rect.size, expected_size])
		return false

	var output := image.get_region(used_rect)
	var error := output.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Waterfall ridge could not be saved: %s (%s)" % [path, error])
		return false

	print(
			"prepared %s | crop=%s | keyed=%d"
			% [path, used_rect, keyed_pixels])
	return true

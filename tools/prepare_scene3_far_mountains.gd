extends SceneTree

const JOBS := [
	{
		"source": "res://assets/import/leftfarmountain.png",
		"output": "res://assets/scenes/scene3/scene3_left_far_mountain.png",
	},
	{
		"source": "res://assets/import/rightfarmountain.png",
		"output": "res://assets/scenes/scene3/scene3_right_far_mountain.png",
	},
]
const CLEAR_LUMINANCE := 0.90
const CLEAR_CHROMA := 0.12
const FEATHER_LUMINANCE := 0.78
const FEATHER_CHROMA := 0.10


func _init() -> void:
	for job: Dictionary in JOBS:
		if not _prepare(String(job["source"]), String(job["output"])):
			quit(1)
			return
	quit()


func _prepare(source_path: String, output_path: String) -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	if image == null:
		push_error("Scene3 far mountain source could not be loaded: %s" % source_path)
		return false

	image.convert(Image.FORMAT_RGBA8)
	var keyed_pixels := 0
	var feathered_pixels := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			var high := maxf(color.r, maxf(color.g, color.b))
			var low := minf(color.r, minf(color.g, color.b))
			var chroma := high - low
			var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			if luminance >= CLEAR_LUMINANCE and chroma <= CLEAR_CHROMA:
				image.set_pixel(x, y, Color.TRANSPARENT)
				keyed_pixels += 1
			elif luminance > FEATHER_LUMINANCE and chroma <= FEATHER_CHROMA:
				var alpha := 1.0 - smoothstep(
						FEATHER_LUMINANCE,
						CLEAR_LUMINANCE,
						luminance)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
				feathered_pixels += 1

	var used_rect := image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		push_error("Scene3 far mountain became empty after keying: %s" % source_path)
		return false

	var output := image.get_region(used_rect)
	var error := output.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Scene3 far mountain could not be saved: %s (%s)" % [output_path, error])
		return false

	print(
			"prepared %s -> %s | crop=%s | keyed=%d | feathered=%d"
			% [source_path, output_path, used_rect, keyed_pixels, feathered_pixels])
	return true

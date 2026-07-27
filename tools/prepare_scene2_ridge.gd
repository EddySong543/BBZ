extends SceneTree
## Convert the newly supplied Scene2 ridge from its baked pale background into
## one cropped true-alpha texture. Both waterfall-side nodes reuse this asset
## with independent materials and transforms.

const SOURCE_PATH := "res://assets/import/ridge.png"
const OUTPUT_PATH := "res://assets/scenes/scene2/scene2_waterfall_ridge.png"
const EXPECTED_SIZE := Vector2i(112, 122)
const LUMINANCE_THRESHOLD := 0.90
const CHROMA_THRESHOLD := 0.06


func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if image == null:
		push_error("Scene2 ridge source could not be loaded: %s" % SOURCE_PATH)
		quit(1)
		return

	image.convert(Image.FORMAT_RGBA8)
	var keyed_pixels := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			var high := maxf(color.r, maxf(color.g, color.b))
			var low := minf(color.r, minf(color.g, color.b))
			var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			if luminance > LUMINANCE_THRESHOLD and high - low < CHROMA_THRESHOLD:
				image.set_pixel(x, y, Color.TRANSPARENT)
				keyed_pixels += 1

	var used_rect := image.get_used_rect()
	if used_rect.size != EXPECTED_SIZE:
		push_error(
				"Scene2 ridge produced %s, expected %s; key thresholds changed"
				% [used_rect.size, EXPECTED_SIZE])
		quit(1)
		return

	var output := image.get_region(used_rect)
	var error := output.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Scene2 ridge could not be saved: %s (%s)" % [OUTPUT_PATH, error])
		quit(1)
		return

	print(
			"prepared %s -> %s | crop=%s | keyed=%d"
			% [SOURCE_PATH, OUTPUT_PATH, used_rect, keyed_pixels])
	quit()

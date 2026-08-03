extends SceneTree

const SOURCE := "res://assets/scenes/scene3/scene3_source_sun.png"
const OUTPUT := "res://assets/scenes/scene3/scene3_sun.png"
const CLEAR_LUMINANCE := 0.92
const CLEAR_CHROMA := 0.08
const FEATHER_LUMINANCE := 0.80
const FEATHER_CHROMA := 0.12


func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if image == null:
		push_error("Scene3 sun source could not be loaded: %s" % SOURCE)
		quit(1)
		return

	image.convert(Image.FORMAT_RGBA8)
	var keyed_pixels := 0
	var feathered_pixels := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.001:
				continue
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
		push_error("Scene3 sun became empty after background keying")
		quit(1)
		return

	var output := image.get_region(used_rect)
	var error := output.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Scene3 sun could not be saved: %s" % error)
		quit(1)
		return

	print(
			"prepared %s -> %s | crop=%s | keyed=%d | feathered=%d"
			% [SOURCE, OUTPUT, used_rect, keyed_pixels, feathered_pixels])
	quit()

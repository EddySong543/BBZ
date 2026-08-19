extends SceneTree

const SOURCE_GRASS_PATH := "res://assets/tilesets/qingfeng_ricefield/grass_ref37_ref39_plain_v1.png"
const OUTPUT_DIRT_PATH := "res://assets/tilesets/qingfeng_ricefield/dirt_ref37_ref39_plain_v1.png"
const SOURCE_MIN_LUMA: float = 0.215
const SOURCE_MAX_LUMA: float = 0.535
const DIRT_RAMP: Array[Color] = [
	Color8(80, 58, 34),
	Color8(105, 70, 34),
	Color8(125, 81, 35),
	Color8(153, 96, 37),
	Color8(178, 111, 42),
	Color8(194, 124, 49),
	Color8(203, 131, 52),
]


func _init() -> void:
	var source_path: String = ProjectSettings.globalize_path(SOURCE_GRASS_PATH)
	var output_path: String = ProjectSettings.globalize_path(OUTPUT_DIRT_PATH)
	var source: Image = Image.load_from_file(source_path)
	if source == null or source.get_size() != Vector2i(60, 60):
		push_error("Pure-ground source must be a 60x60 texture: %s" % SOURCE_GRASS_PATH)
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	var output: Image = Image.create(60, 60, false, Image.FORMAT_RGBA8)
	for y: int in source.get_height():
		for x: int in source.get_width():
			var pixel: Color = source.get_pixel(x, y)
			if pixel.a < 0.5:
				output.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var luma: float = pixel.get_luminance()
			var normalized: float = clampf(
					(luma - SOURCE_MIN_LUMA) / (SOURCE_MAX_LUMA - SOURCE_MIN_LUMA),
					0.0, 1.0)
			var ramp_index: int = clampi(
					int(round(normalized * float(DIRT_RAMP.size() - 1))),
					0, DIRT_RAMP.size() - 1)
			output.set_pixel(x, y, DIRT_RAMP[ramp_index])
	var error: Error = output.save_png(output_path)
	if error != OK:
		push_error("Could not save pure dirt: %s" % error_string(error))
		quit(1)
		return
	print("Saved pure dirt tile: ", OUTPUT_DIRT_PATH)
	quit()

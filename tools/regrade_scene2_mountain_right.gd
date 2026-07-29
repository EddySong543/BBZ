extends SceneTree
## Bake MountainRight into a deterministic neutral-gray pixel palette.
## The accepted transparent cutout is the input; alpha and source pixel
## geometry are preserved exactly, so this tool cannot introduce soft edges.

const SOURCE := "res://assets/scenes/scene2/scene2_mountain_right.png"
const OUTPUT := "res://assets/scenes/scene2/scene2_mountain_right.png"
const PALETTE: Array[Color] = [
	Color("#20292f"),
	Color("#2d373d"),
	Color("#3b464c"),
	Color("#4a555a"),
	Color("#5a6569"),
	Color("#6b7578"),
	Color("#7d8789"),
	Color("#90999a"),
	Color("#a3aaa9"),
	Color("#b5bab6"),
	Color("#c5c8c1"),
	Color("#d2d2c8"),
]


func _init() -> void:
	var path := ProjectSettings.globalize_path(SOURCE)
	var image := Image.load_from_file(path)
	if image == null:
		push_error("Could not load Scene2 right mountain: %s" % SOURCE)
		quit(1)
		return

	image.convert(Image.FORMAT_RGBA8)
	var recolored_pixels := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var source := image.get_pixel(x, y)
			if source.a <= 0.0:
				continue
			var luma := source.r * 0.299 + source.g * 0.587 + source.b * 0.114
			var contrasted_luma := clampf((luma - 0.5) * 1.08 + 0.5, 0.0, 1.0)
			var palette_index := clampi(
					int(round(contrasted_luma * float(PALETTE.size() - 1))),
					0,
					PALETTE.size() - 1)
			var target := PALETTE[palette_index]
			image.set_pixel(x, y, Color(target.r, target.g, target.b, source.a))
			recolored_pixels += 1

	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Could not save Scene2 right mountain: %s (%s)" % [OUTPUT, error])
		quit(1)
		return

	print(
			"regraded Scene2 MountainRight | size=%s | recolored=%d | palette=%d"
			% [image.get_size(), recolored_pixels, PALETTE.size()])
	quit()

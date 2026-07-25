extends SceneTree

const OUTPUT_PATH := "res://assets/scenes/scene2/scene2_petal_atlas.png"
const FRAME_SIZE := 16
const FRAMES := [
	[
		"................",
		"................",
		"................",
		"..........oo....",
		".........omo....",
		"........ommmo...",
		".......ommmo....",
		"......ommmo.....",
		".....ommmo......",
		"....ommmo.......",
		"...ommo.........",
		"...oo...........",
		"................",
		"................",
		"................",
		"................",
	],
	[
		"................",
		"................",
		"................",
		"................",
		"................",
		"......oooo......",
		"....oommmmoo....",
		"...ommmhhmmmo...",
		"....oommmmoo....",
		"......oooo......",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	[
		"................",
		"................",
		"................",
		"................",
		".......oo.......",
		"......ommo......",
		"......ommo......",
		"......ohmo......",
		".......omo......",
		".......oo.......",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	[
		"................",
		"................",
		"................",
		"....oo..........",
		"....omo.........",
		"...ommmo........",
		"....ommmo.......",
		".....ommmo......",
		"......ommmo.....",
		".......ommmo....",
		".........ommo...",
		"...........oo...",
		"................",
		"................",
		"................",
		"................",
	],
]

const PALETTE := {
	"o": Color8(105, 64, 82, 220),
	"m": Color8(205, 128, 151, 242),
	"h": Color8(241, 191, 199, 255),
}


func _initialize() -> void:
	var image := Image.create(FRAME_SIZE * FRAMES.size(), FRAME_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for frame_index: int in FRAMES.size():
		var rows: Array = FRAMES[frame_index]
		for y: int in FRAME_SIZE:
			var row: String = rows[y]
			for x: int in FRAME_SIZE:
				var key := row.substr(x, 1)
				if PALETTE.has(key):
					image.set_pixel(frame_index * FRAME_SIZE + x, y, PALETTE[key])

	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Failed to save Scene2 petal atlas: %s" % error_string(error))
		quit(1)
		return
	print("Generated %s (%dx%d)" % [OUTPUT_PATH, image.get_width(), image.get_height()])
	quit(0)

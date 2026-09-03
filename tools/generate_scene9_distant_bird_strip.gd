extends SceneTree

const OUTPUT_PATH := "res://assets/scenes/scene9/scene9_distant_bird_strip.png"
const FRAME_SIZE := Vector2i(5, 3)
const BODY_COLOR := Color("344960")
const WING_LIGHT_COLOR := Color("7289a2")
const FRAME_ROWS := [
	["d...d", ".dld.", "..d.."],
	[".....", "ddldd", "..d.."],
	["..d..", ".dld.", "d...d"],
]


func _init() -> void:
	var image := Image.create(
			FRAME_SIZE.x * FRAME_ROWS.size(), FRAME_SIZE.y,
			false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for frame_index: int in FRAME_ROWS.size():
		var rows: Array = FRAME_ROWS[frame_index] as Array
		for y: int in FRAME_SIZE.y:
			var row: String = rows[y] as String
			for x: int in FRAME_SIZE.x:
				var token: String = row.substr(x, 1)
				if token == "d":
					image.set_pixel(frame_index * FRAME_SIZE.x + x, y, BODY_COLOR)
				elif token == "l":
					image.set_pixel(
							frame_index * FRAME_SIZE.x + x, y,
							WING_LIGHT_COLOR)
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save Scene9 bird strip: %s" % error_string(error))
		quit(1)
		return
	print("SCENE9_BIRD_STRIP_OK path=%s size=%dx%d frames=%d" % [
		OUTPUT_PATH, image.get_width(), image.get_height(), FRAME_ROWS.size()])
	quit()

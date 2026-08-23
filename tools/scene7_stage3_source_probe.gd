extends SceneTree

const INPUTS: Array[String] = [
	"res://assets/scenes/scene7/scene7_battle_platform.png",
	"res://assets/scenes/scene7/scene7_midground_left.png",
	"res://assets/scenes/scene7/scene7_midground_center.png",
	"res://assets/scenes/scene7/scene7_midground_right.png",
	"res://assets/scenes/scene7/scene7_foreground_left.png",
	"res://assets/scenes/scene7/scene7_foreground_right.png",
]


func _initialize() -> void:
	var passed := true
	for path: String in INPUTS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			print("SCENE7_STAGE3_SOURCE: FAIL path=", path)
			passed = false
			continue
		_print_shape(path, image)
	quit(0 if passed else 1)


func _print_shape(path: String, image: Image) -> void:
	var used := _alpha_used_rect(image, 0.5)
	var occupancy := 0
	for y: int in range(used.position.y, used.end.y):
		for x: int in range(used.position.x, used.end.x):
			occupancy += 1 if image.get_pixel(x, y).a >= 0.5 else 0
	var top_envelope: Array[int] = []
	var bottom_envelope: Array[int] = []
	for sample_index: int in 9:
		var x := clampi(
				roundi(lerpf(float(used.position.x), float(used.end.x - 1),
						float(sample_index) / 8.0)),
				0, image.get_width() - 1)
		var top := -1
		var bottom := -1
		for y: int in range(used.position.y, used.end.y):
			if image.get_pixel(x, y).a >= 0.5:
				top = y
				break
		for y: int in range(used.end.y - 1, used.position.y - 1, -1):
			if image.get_pixel(x, y).a >= 0.5:
				bottom = y
				break
		top_envelope.append(top)
		bottom_envelope.append(bottom)
	print(
		"SCENE7_STAGE3_SOURCE: PASS asset=", path.get_file(),
		" size=", image.get_size(),
		" used=", used,
		" occupancy=", snappedf(
				float(occupancy) / maxf(float(used.get_area()), 1.0), 0.001),
		" top9=", top_envelope,
		" bottom9=", bottom_envelope)


func _alpha_used_rect(image: Image, threshold: float) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < threshold:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
